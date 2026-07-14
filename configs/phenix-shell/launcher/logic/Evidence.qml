pragma Singleton
import QtQml
import Quickshell
import qs.services
import "Tokenize.qml"

Singleton {
    readonly property var prof: Profiler.scope("launcher.evidence", { category: "launcher" })
    readonly property var tracer: Logger.scope("launcher.evidence", { category: "launcher" })
    function evidence(strategy, field, kind, score, weight, ranges, reason, meta) {
        var s = Tokenize.clamp(score);
        meta = meta || {};
        return { strategy: strategy, field: field.field, fieldText: field.text, nodeId: field.nodeId, originNodeId: meta.originNodeId || field.nodeId, originKind: meta.originKind || field.originKind || "self", depth: meta.depth === undefined ? field.depth || 0 : meta.depth, tokenIndex: meta.tokenIndex, tokenIndexes: meta.tokenIndex === undefined ? meta.tokenIndexes || [] : [meta.tokenIndex], coverageCount: meta.tokenIndex === undefined ? (meta.tokenIndexes || []).length : 1, exactness: meta.exactness || strategy, actionId: meta.actionId || null, actionRole: meta.actionRole || null, isExecutable: !!meta.isExecutable, kind: kind, score: s, weight: weight, effective: s * weight, ranges: ranges || [], reason: reason || "" };
    }

    function _matchField(field, query, strategyIds) {
        tracer.trace("matchField", function() { return { field: field.field, tokenCount: query.tokens.length, fieldTextLen: (field.text || "").length }; });
        if (query.isEmpty) return [];
        var out = [];
        var ids = strategyIds || ["exact", "prefix", "compact", "substring", "acronym", "fuzzy"];
        var fieldPrimary = field.primary;
        for (var ti = 0; ti < query.tokens.length; ti += 1) {
            var token = query.tokens[ti];
            var tokenNorm = token.normalized;
            if (ids.indexOf("exact") >= 0) {
                if (field.normText === tokenNorm)
                    out.push(evidence("exact", field, "exact-field", 0.96, field.weight, [{ start: 0, end: field.text.length, kind: "exact" }], "field equals token", { tokenIndex: ti, exactness: "exact" }));
                var words = field.words;
                for (var wi = 0; wi < words.length; wi += 1) {
                    if (words[wi].norm === tokenNorm)
                        out.push(evidence("exact", field, "exact-word", 0.96, field.weight, [{ start: words[wi].start, end: words[wi].end, kind: "exact" }], "word equals token", { tokenIndex: ti, exactness: "exact" }));
                }
            }
            if (ids.indexOf("prefix") >= 0) {
                if (tokenNorm.length >= 2 || fieldPrimary) {
                    for (var pwi = 0; pwi < field.words.length; pwi += 1) {
                        var pword = field.words[pwi];
                        if (pword.norm.indexOf(tokenNorm) === 0 && pword.norm !== tokenNorm) {
                            var coverage = tokenNorm.length / Math.max(1, pword.norm.length);
                            out.push(evidence("prefix", field, "prefix", 0.75 + coverage * 0.18, field.weight, [{ start: pword.start, end: pword.start + token.raw.length, kind: "prefix" }], "token prefixes word", { tokenIndex: ti, exactness: "prefix" }));
                        }
                    }
                }
            }
            var tokenLen = tokenNorm.length;
            if (ids.indexOf("substring") >= 0 && tokenLen >= 3) {
                var start = 0;
                var normText = field.normText;
                while (true) {
                    var idx = normText.indexOf(tokenNorm, start);
                    if (idx < 0) break;
                    out.push(evidence("substring", field, "substring", 0.66, field.weight * 0.75, [{ start: idx, end: idx + token.raw.length, kind: "substring" }], "token occurs inside field", { tokenIndex: ti, exactness: "substring" }));
                    start = idx + Math.max(1, tokenLen);
                }
            }
            if (ids.indexOf("compact") >= 0 && tokenLen >= 3) {
                var compactToken = Tokenize.compactWithMap(token.raw).compact || tokenNorm;
                var cidx = field.compact.compact.indexOf(compactToken);
                if (cidx >= 0) {
                    if (cidx > 0) continue;
                    var cstart = field.compact.map[cidx];
                    var cend = field.compact.map[cidx + compactToken.length - 1] + 1;
                    var full = field.compact.compact === compactToken;
                    var compactCoverage = compactToken.length / Math.max(1, field.compact.compact.length);
                    var compactScore = full ? 0.93 : 0.75 + compactCoverage * 0.18;
                    var compactWeight = field.weight * (full ? 0.95 : 1.0);
                    out.push(evidence("compact", field, full ? "compact-exact" : "compact-prefix", compactScore, compactWeight, [{ start: cstart, end: cend, kind: "compact" }], "token matches compacted field", { tokenIndex: ti, exactness: full ? "exact" : "prefix" }));
                }
            }
            if (ids.indexOf("acronym") >= 0 && tokenLen >= 2) {
                var acronym = field._acronymStr || (function(f) {
                    var al = f.acronymLetters;
                    var s = "";
                    for (var ai = 0; ai < al.length; ai += 1) s += al[ai].char;
                    f._acronymStr = s;
                    return s;
                })(field);
                if (acronym.length >= 2 && (acronym === tokenNorm || acronym.indexOf(tokenNorm) === 0)) {
                    var acroRanges = field.acronymLetters;
                    var acroLen = Math.min(tokenLen, acronym.length);
                    var ranges = [];
                    for (var ar = 0; ar < acroLen; ar += 1)
                        ranges.push({ start: acroRanges[ar].start, end: acroRanges[ar].end, kind: "acronym" });
                    out.push(evidence("acronym", field, acronym === tokenNorm ? "acronym-exact" : "acronym-prefix", acronym === tokenNorm ? 0.91 : 0.82, field.weight * 0.92, ranges, "token matches acronym", { tokenIndex: ti, exactness: acronym === tokenNorm ? "exact" : "prefix" }));
                }
            }
            if (ids.indexOf("fuzzy") >= 0 && tokenLen >= 3) {
                for (var fwi = 0; fwi < field.words.length; fwi += 1) {
                    var fword = field.words[fwi];
                    var maxDistance = Tokenize.fuzzyDistanceLimit(tokenNorm, fword.norm);
                    if (maxDistance <= 0 || Math.abs(fword.norm.length - tokenLen) > maxDistance || fword.norm === tokenNorm) continue;
                    var distance = Tokenize.boundedDamerauLevenshtein(tokenNorm, fword.norm, maxDistance);
                    if (distance > maxDistance) continue;
                    var similarity = 1 - distance / Math.max(tokenLen, fword.norm.length, 1);
                    out.push(evidence("fuzzy", field, "fuzzy-word", 0.44 + similarity * 0.16, field.weight * 0.55, [{ start: fword.start, end: fword.end, kind: "fuzzy" }], "token is within bounded edit distance of word", { tokenIndex: ti, exactness: "fuzzy" }));
                }
            }
        }
        return out;
    }

    readonly property var matchField: prof.fn("matchField", _matchField)

    function recencyScore(daysAgo) {
        return 1 / (1 + Math.max(0, daysAgo) / 30);
    }

    function frequencyScore(count) {
        return Tokenize.clamp(Math.log(1 + Math.max(0, count)) / Math.log(81));
    }

    function matchSemantic(node, query) {
        if (query.isEmpty || !node.semanticTerms || !node.semanticTerms.length) return [];
        var required = node.semanticBoostRequiresAny || [];
        if (required.length && !query.tokens.some(function(t) { return required.indexOf(t.normalized) >= 0; })) return [];
        var haystack = Tokenize.normalizeText([node.label, node.subtitle].concat(node.keywords || []).concat(node.aliases || []).join(" "));
        var out = [];
        for (var i = 0; i < node.semanticTerms.length; i += 1) {
            var term = node.semanticTerms[i];
            var triggers = term.triggers || term.tokens || [];
            var matches = term.matches || term.tokens || triggers;
            var queryHit = query.tokens.some(function(t) { return triggers.indexOf(t.normalized) >= 0; });
            if (!queryHit) continue;
            var nodeHasTerm = matches.some(function(m) { return haystack.indexOf(Tokenize.normalizeText(m)) >= 0; });
            if (!nodeHasTerm) continue;
            out.push({ strategy: "semantic", field: term.field || "semantic", fieldText: node.label, nodeId: node.id, originNodeId: node.id, originKind: "self", depth: 0, tokenIndexes: [], coverageCount: 0, exactness: "semantic", actionId: null, actionRole: null, isExecutable: false, kind: term.kind || "semantic-node-term", score: term.score || 0.74, weight: term.weight || 0.38, effective: (term.score || 0.74) * (term.weight || 0.38), ranges: [], reason: term.reason || "semantic node term" });
        }
        return out;
    }

    function claimMatchingTokens(query, tokens, options) {
        var norm = tokens.map(Tokenize.normalizeText);
        var claims = [];
        for (var i = 0; i < query.tokens.length; i += 1) {
            if (norm.indexOf(query.tokens[i].normalized) < 0) continue;
            claims.push({ tokenIndex: i, strength: options && options.strength || 1, weight: options && options.weight || 0.62, field: options && options.field || "token-claim", reason: options && options.reason || "node token claim" });
        }
        return claims;
    }

    function tokenClaimToEvidence(node, query, claim) {
        return { strategy: "node-token-policy", field: claim.field || "token-claim", fieldText: query.tokens[claim.tokenIndex] ? query.tokens[claim.tokenIndex].raw : "", nodeId: node.id, originNodeId: node.id, originKind: "self", depth: 0, kind: "token-claim", tokenIndex: claim.tokenIndex, tokenIndexes: [claim.tokenIndex], coverageCount: 1, exactness: "exact", actionId: null, actionRole: null, isExecutable: false, score: Tokenize.clamp(claim.strength || 1), weight: claim.weight || 0.62, effective: Tokenize.clamp(claim.strength || 1) * (claim.weight || 0.62), ranges: [], reason: claim.reason || "node token claim" };
    }

    function filterFields(fields, filterType) {
        if (!fields || !fields.length) return [];
        if (!filterType || filterType === "all") return fields.slice();
        if (filterType === "primary") return fields.filter(function(f) { return f.field !== "breadcrumb"; });
        if (filterType === "breadcrumb") return fields.filter(function(f) { return f.field === "breadcrumb"; });
        var re;
        try { re = new RegExp(filterType); } catch (e) { return []; }
        return fields.filter(function(f) { return re.test(f.field); });
    }

    function evidenceFieldGroup(field) {
        var f = String(field || "");
        if (f === "usage" || f === "recency") return "boost:" + f;
        if (f === "token-claim" || f.indexOf("ancestor-") === 0) return "path-text";
        if (f === "label" || f === "aliases") return "primary-text";
        if (f === "subtitle" || f === "keywords") return "secondary-text";
        if (f === "command" || f === "path") return "technical-text";
        if (f.indexOf("semantic") >= 0 || f === "connectivity" || f === "state" || f === "navigation-context" || f === "page") return "semantic-text";
        return f;
    }

    function evidenceKindPriority(kind) {
        var k = String(kind || "");
        if (k.indexOf("exact") >= 0) return 100;
        if (k.indexOf("prefix") >= 0) return 86;
        if (k.indexOf("acronym") >= 0) return 80;
        if (k.indexOf("compact") >= 0) return 76;
        if (k.indexOf("semantic") >= 0) return 68;
        if (k.indexOf("substring") >= 0) return 52;
        if (k.indexOf("fuzzy") >= 0) return 44;
        if (k.indexOf("frequency") >= 0 || k.indexOf("recency") >= 0) return 20;
        return 50;
    }

    property var _infHaystackCache: ({})

    function inferCoveredTokenIndexes(e, query) {
        var cached = e.__coveredIdx;
        if (cached) return cached;
        var covered = [];
        var cacheKey = e.field + "|" + e.fieldText + "|" + (e.reason || "");
        var haystack = _infHaystackCache[cacheKey];
        if (!haystack) {
            haystack = Tokenize.normalizeText(e.fieldText + " " + (e.reason || "") + " " + e.field);
            _infHaystackCache[cacheKey] = haystack;
        }
        for (var i = 0; i < query.tokens.length; i += 1) {
            if (haystack.indexOf(query.tokens[i].normalized) >= 0) covered.push(i);
        }
        e.__coveredIdx = covered;
        return covered;
    }

    function coveredTokenIndexes(evidenceItems, query) {
        var covered = {};
        for (var ei = 0; ei < (evidenceItems || []).length; ei += 1) {
            var e = evidenceItems[ei];
            var tokenIndexes = e.tokenIndex !== undefined ? [e.tokenIndex] : inferCoveredTokenIndexes(e, query);
            for (var ci = 0; ci < tokenIndexes.length; ci += 1) {
                if (typeof tokenIndexes[ci] === "number") covered[tokenIndexes[ci]] = true;
            }
        }
        return covered;
    }

    function isBetterEvidence(a, b) {
        var pa = evidenceKindPriority(a.kind);
        var pb = evidenceKindPriority(b.kind);
        if (pa !== pb) return pa > pb;
        if (Math.abs(a.effective - b.effective) > 0.0001) return a.effective > b.effective;
        return a.score > b.score;
    }

    function bestPerToken(evidenceItems) {
        var best = {};
        var out = [];
        for (var i = 0; i < evidenceItems.length; i += 1) {
            var e = evidenceItems[i];
            var ti = e.tokenIndex;
            if (ti === undefined) { out.push(e); continue; }
            if (!best[ti] || isBetterEvidence(e, best[ti]))
                best[ti] = e;
        }
        var keys = Object.keys(best).map(Number).sort(function(a, b) { return a - b; });
        for (var ki = 0; ki < keys.length; ki += 1)
            out.push(best[keys[ki]]);
        return out;
    }

    function overlayEvidence(items, query) {
        var buckets = {};
        var out = [];
        for (var i = 0; i < items.length; i += 1) {
            var e = items[i];
            var group = evidenceFieldGroup(e.field);
            var tokenIndexes = e.tokenIndex !== undefined ? [e.tokenIndex] : inferCoveredTokenIndexes(e, query);
            if (group.indexOf("boost:") === 0) tokenIndexes = [group];
            if (!tokenIndexes.length) { out.push(e); continue; }
            for (var ti = 0; ti < tokenIndexes.length; ti += 1) {
                var key = tokenIndexes[ti] + ":" + group;
                var withToken = Object.assign({}, e, { tokenIndex: tokenIndexes[ti] });
                if (!buckets[key] || isBetterEvidence(withToken, buckets[key]))
                    buckets[key] = withToken;
            }
        }
        for (var key in buckets) out.push(buckets[key]);
        return out;
    }

    function _scoreEvidence(evidenceItems, node, ctx) {
        tracer.trace("scoreEvidence", function() { return { nodeId: node && node.id, evidenceCount: evidenceItems.length }; });
        if (!evidenceItems.length)
            return { value: 0, visible: ctx.query.isEmpty && (node.kind === "backend" || node.showWhenQueryEmpty || node.backendId === "backends" && ctx.directive && ctx.directive.active), reason: "no evidence" };
        var sorted = overlayEvidence(evidenceItems, ctx.query).sort(function(a, b) { return b.effective - a.effective; });
        var combined = 0;
        for (var i = 0; i < sorted.length; i += 1)
            combined = 1 - (1 - combined) * (1 - Tokenize.clamp(sorted[i].effective, 0, 1.2));
        if (ctx.query.tokens.length > 1) {
            var covered = coveredTokenIndexes(sorted, ctx.query);
            var coveredCount = Object.keys(covered).length;
            var ratio = coveredCount / ctx.query.tokens.length;
            var isActionLike = ["desktop-action", "dashboard-page", "action-group", "dashboard-group", "switch"].indexOf(node.kind) >= 0;
            var missingCount = ctx.query.tokens.length - coveredCount;
            var coverageFactor = (isActionLike ? 0.08 : 0.20) + ((isActionLike ? 0.92 : 0.80) * ratio);
            var negativeEvidenceFactor = Math.pow(isActionLike ? 0.15 : 0.30, missingCount);
            combined *= coverageFactor * negativeEvidenceFactor;
        }
        return { value: Tokenize.clamp(combined), visible: combined >= ctx.visibilityThreshold, reason: "saturating weighted evidence" };
    }

    readonly property var scoreEvidence: prof.fn("scoreEvidence", _scoreEvidence)
}
