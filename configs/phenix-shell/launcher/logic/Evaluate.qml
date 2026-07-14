pragma Singleton
import QtQml
import Quickshell
import qs.services
import "Tokenize.qml"
import "IndexBuilder.qml"
import "Evidence.qml"
import "PolicyChain.qml"
import "ScoreBundle.qml"
import "TokenFlow.qml"
import "CompositeSearchPolicyRegistry.js" as JsRegistry

Singleton {
    readonly property var prof: Profiler.scope("launcher.evaluate", { category: "launcher" })
    readonly property var tracer: Logger.scope("launcher.evaluate", { category: "launcher" })
    readonly property var defaultProfile: ({
        // Leaf-conservative default: no expand/takeover/retain unless explicitly set.
        // Backends with group/switch behavior override this in their own evaluationProfile.
        fields: ["label", "aliases"],
        evidence: ["field-match", "switch-action", "semantic", "token-claim", "usage", "recency"],
        boost: ["descendant-boost"],
        childVisible: ["visible-flag"],
        tokenFlow: ["pass-all"],
        defaultAction: ["default-action-owner"],
        riskGate: ["risk-gate"]
    })

    function nodeMatchesDirective(node, ctx) {
        var directive = ctx.directive;
        if (!directive || !directive.active)
            return true;
        if (node.kind === "root")
            return true;
        if (directive.backendIds && directive.backendIds.indexOf(node.backendId) >= 0)
            return true;
        for (var i = 0; i < (directive.tags || []).length; i += 1) {
            if ((node.tags || []).indexOf(directive.tags[i]) >= 0)
                return true;
        }
        return false;
    }

    function nodeTreeMayContainDirective(node, ctx) {
        if (nodeMatchesDirective(node, ctx))
            return true;
        var closure = IndexBuilder.computeDirectiveTagClosure(node);
        for (var i = 0; i < (ctx.directive.tags || []).length; i += 1) {
            if (closure[ctx.directive.tags[i]])
                return true;
        }
        return false;
    }

    function isSingleCharQuery(query) {
        return query && !query.isEmpty && query.tokens && query.tokens.length === 1 && query.tokens[0].raw.length <= 1;
    }

    function _evaluateNode(node, query, ctx) {
        tracer.trace("evaluateNode", function() { return { nodeId: node.id, kind: node.kind, queryEmpty: !!query.isEmpty, showHidden: !!ctx.showHidden }; });
        var directiveActive = !!(ctx.directive && ctx.directive.active);
        var selfAllowed = !directiveActive || nodeMatchesDirective(node, ctx);
        if (directiveActive && !selfAllowed && !nodeTreeMayContainDirective(node, ctx)) {
            tracer.debug("prune", function() { return { nodeId: node.id, reason: "directive container only" }; });
            return { node: node, allowed: false, candidate: false, pruned: true, evidence: [], ownEvidence: [], inheritedEvidence: [], ownScore: 0, inheritedScore: 0, score: 0, visible: false, children: [] };
        }

        var singleCharQuery = isSingleCharQuery(query);
        var qEmpty = query.isEmpty;
        var directiveBrowse = directiveActive && qEmpty;
        if (ctx.candidateIds && !ctx.candidateIds[node.id] && !ctx.explicitResidualChildSearch && node.kind !== "root" && node.kind !== "backend" && !(node.showWhenQueryEmpty && qEmpty) && !(qEmpty && node.backendId === "backends" && directiveActive) && !directiveBrowse && !ctx.showHidden) {
            tracer.debug("prune", function() { return { nodeId: node.id, reason: "non-candidate" }; });
            return { node: node, allowed: selfAllowed, candidate: false, pruned: true, evidence: [], ownEvidence: [], inheritedEvidence: [], ownScore: 0, inheritedScore: 0, score: 0, visible: false, children: [] };
        }

        var ep = node.evaluationProfile || {};
        var profile = ep.profile || defaultProfile;

        var ownEvidence = [];
        var inheritedEvidence = [];
        var directCandidate = !ctx.candidateIds || !!ctx.candidateIds[node.id] || ctx.explicitResidualChildSearch || node.kind === "root" || node.kind === "backend" || node.showWhenQueryEmpty || directiveBrowse;

        if (selfAllowed && directCandidate) {
            var evidenceNames = profile.evidence || [];
            if (node && node.id && ctx._policyTrace && !ctx._policyTrace[node.id]) ctx._policyTrace[node.id] = {};
            var evidenceTimings = ctx._policyTimings ? ctx._policyTimings.evidence : null;
            // Global default fields from profile root apply to policies without explicit fields/filterType
            var globalEvidenceFields = profile.fields;
            var evidenceResult = PolicyChain.run(evidenceNames, function(name, spec) {
                var effectiveArgs = spec && spec.args;
                if (globalEvidenceFields && (!effectiveArgs || (!effectiveArgs.fields && !effectiveArgs.filterType))) {
                    effectiveArgs = Object.assign({}, effectiveArgs || {}, { fields: globalEvidenceFields });
                }
                var policy = PolicyChain.lookupPolicy(JsRegistry.evidence, spec);
                if (!policy || policy.phase !== "evidence") return null;
                var items = policy.match(node, query, ctx, effectiveArgs);
                if (!items || !items.length) return null;
                var group = policy.group || "own";
                items.forEach(function(item) {
                    if (!item.originGroup)
                        item.originGroup = group;
                });
                return items;
            }, "evidence", function(tr) {
                if (!node || !node.id || !ctx._policyTrace) return;
                if (!ctx._policyTrace[node.id]) return;
                if (!ctx._policyTrace[node.id].evidence) {
                    ctx._policyTrace[node.id].evidence = { kind: "evidence", evaluated: [], aggregate: null, final: null };
                }
                ctx._policyTrace[node.id].evidence.evaluated.push({
                    name: tr.name, priority: tr.priority || 0, enabled: true,
                    args: tr.args,
                    returned: tr.returned,
                    effect: "combined",
                    reasons: tr.returned && tr.returned.reasons ? tr.returned.reasons.slice() : []
                });
            }, evidenceTimings);
            var allEvidence = evidenceResult.value || [];
            // Inherited evidence is produced by evidence policies via originGroup: "inherited";
            // profile.inherit is not supported.
            for (var ei = 0; ei < allEvidence.length; ei += 1) {
                if (allEvidence[ei].originGroup === "inherited")
                    inheritedEvidence.push(allEvidence[ei]);
                else
                    ownEvidence.push(allEvidence[ei]);
            }
        }

        if (ownEvidence.length > 0) {
            var tokenDedup = profile.tokenDedup || "best-per-token";
            if (tokenDedup === "best-per-token")
                ownEvidence = Evidence.bestPerToken(ownEvidence);
        }

        // Single-character query: require stronger evidence, filter weak matches
        if (singleCharQuery && ownEvidence.length > 0) {
            ownEvidence = ownEvidence.filter(function(e) {
                var k = String(e.kind || e.strategy || "");
                // Allow only exact, acronym, prefix, compact, word-start matches
                if (k.indexOf("exact") >= 0) return true;
                if (k.indexOf("acronym") >= 0) return true;
                if (k.indexOf("prefix") >= 0) return e.tokenIndex === 0 || e.coverageCount > 0;
                if (k.indexOf("compact") >= 0) return true;
                if (k.indexOf("word-start") >= 0) return true;
                // Filter out: substring, fuzzy, inherited-only, usage/recency
                if (k.indexOf("substring") >= 0) return false;
                if (k.indexOf("fuzzy") >= 0) return false;
                if (k.indexOf("semantic") >= 0) return false;
                if (k === "usage" || k === "recency") return false;
                if (e.field === "usage" || e.field === "recency") return false;
                return false;
            });
        }

        var tokenFlowResult = null;
        var childQuery = query;
        var childCtx = ctx;
        var tokenFlow = null;
        if (node.kind !== "root" && node.kind !== "backend") {
            tokenFlowResult = TokenFlow.evaluate(node, query, ctx);
            tokenFlow = tokenFlowResult && tokenFlowResult.value;
            tracer.trace("tokenFlow", function() { return { nodeId: node.id, consumed: (tokenFlow && tokenFlow.consumed || []).length, passed: (tokenFlow && tokenFlow.passed || []).length, reason: (tokenFlow && tokenFlow.reason) || "none" }; });
            if (tokenFlow && tokenFlow.passed) {
                childQuery = TokenFlow.buildChildQuery(node, tokenFlow, query);
                childCtx = Object.assign({}, ctx, { query: childQuery, childQuery: childQuery, tokenFlow: tokenFlow });
                var parentConsumed = tokenFlow.consumed
                    && tokenFlow.consumed.length > 0;
                var residualCount = tokenFlow.passed
                    ? tokenFlow.passed.length
                    : 0;
                var explicitTrailingBrowse = parentConsumed
                    && query.lastTokenEmpty
                    && residualCount === 0;
                var explicitResidualChildSearch = parentConsumed
                    && residualCount > 0;
                if (directCandidate && explicitTrailingBrowse) {
                    childCtx = Object.assign({}, childCtx, {
                        candidateIds: null,
                        explicitTrailingBrowse: explicitTrailingBrowse,
                        explicitResidualChildSearch: false
                    });
                }
                if (directCandidate && explicitResidualChildSearch) {
                    childCtx = Object.assign({}, childCtx, {
                        explicitResidualChildSearch: true
                    });
                }
            }
        }

        var evaluatedChildren = evaluateChildren(node, childQuery, childCtx, directiveActive);

        var own = selfAllowed ? Evidence.scoreEvidence(ownEvidence, node, ctx) : { value: 0, visible: false, reason: "directive container only" };
        // Skip skipped-depth penalty when parent consumed tokens via token flow.
        // Children evaluating residual tokens (e.g. "ger" after parent consumed "vpn")
        // should not be penalized for their parent not matching the residual token.
        if (own.value > 0 && !query.isEmpty && !ctx.tokenFlow) {
            var depthMultiplier = skippedDepthMultiplier(node, ownEvidence, query, ctx);
            if (depthMultiplier < 1) {
                own.value = Tokenize.clamp(own.value * depthMultiplier);
                own.visible = own.value >= ctx.visibilityThreshold;
                own.reason = (own.reason || "") + " with skipped-depth penalty";
            }
        }
        if (node.kind === "backend") {
            own.value = Tokenize.clamp(own.value * 0.65);
            own.visible = ctx.query.isEmpty || own.visible;
        }
        if (ep.scorePolicy === "semantic-result")
            own.visible = ownEvidence.length > 0;

        var inheritedResult = selfAllowed && inheritedEvidence.length ? Evidence.scoreEvidence(inheritedEvidence, node, ctx) : { value: 0 };
        var inheritedScore = inheritedResult.value;

        var scores = { ownScore: own.value, inheritedScore: inheritedScore };
        var boostNames = profile.boost || [];
        if (node && node.id && ctx._policyTrace && !ctx._policyTrace[node.id]) ctx._policyTrace[node.id] = {};
        var boostTimings = ctx._policyTimings ? ctx._policyTimings.boost : null;
        var descendantBoost = (PolicyChain.run(boostNames, function(name, spec) {
            var bpol = PolicyChain.lookupPolicy(JsRegistry.boost, spec);
            if (!bpol || bpol.phase !== "boost") return null;
            var boostVal = bpol.apply(node, query, ctx, evaluatedChildren, scores, spec && spec.args);
            return boostVal > 0 ? boostVal : null;
        }, "boost", function(tr) {
            if (!node || !node.id || !ctx._policyTrace) return;
            if (!ctx._policyTrace[node.id]) return;
            if (!ctx._policyTrace[node.id].boost) {
                ctx._policyTrace[node.id].boost = { kind: "boost", evaluated: [], aggregate: null, final: null };
            }
            ctx._policyTrace[node.id].boost.evaluated.push({
                name: tr.name, priority: tr.priority || 0, enabled: true,
                args: tr.args,
                returned: tr.returned,
                effect: tr.effect || "combined",
                reasons: tr.returned && tr.returned.reasons ? tr.returned.reasons.slice() : []
            });
        }, boostTimings).value) || 0;

        var finalScore = Tokenize.clamp(Math.max(own.value, inheritedScore, descendantBoost));
        tracer.trace("score", function() { return { nodeId: node.id, own: own.value, inherited: inheritedScore, descendant: descendantBoost, final: finalScore, visible: own.visible }; });

        var actionAliasBoost = 0;
        if (node.switchActions && own.value > 0) {
            var aliasPol = JsRegistry.boost.get("switch-aliases");
            if (aliasPol) {
                var aliasBoostVal = aliasPol.apply(node, query, ctx, evaluatedChildren, scores);
                if (aliasBoostVal > 0)
                    actionAliasBoost = aliasBoostVal;
            }
        }
        if (actionAliasBoost > 0)
            finalScore = Tokenize.clamp(finalScore + own.value * 0.15 * actionAliasBoost);

        var retained = evaluatedChildren.filter(function(c) { return c.candidate || c.visible || ctx.showHidden; });
        var bestChildMatchDepth = 9999;
        for (var b = 0; b < retained.length; b += 1) {
            if (retained[b].visible || ctx.showHidden) {
                var d = (retained[b].matchDepth === undefined ? 0 : retained[b].matchDepth) + 1;
                if (d < bestChildMatchDepth)
                    bestChildMatchDepth = d;
            }
        }

        var mergedEvidence = ownEvidence.concat(inheritedEvidence);

        // Capture evidence trace
        if (node && node.id && ctx._evidenceTrace) {
            var matchedTokens = [];
            var consumedTokens = [];
            var missingTokens = [];
            var tokenIndexes = {};
            for (var ei = 0; ei < mergedEvidence.length; ei += 1) {
                var evItem = mergedEvidence[ei];
                var ti = evItem.tokenIndex;
                if (ti !== undefined && ti >= 0) {
                    tokenIndexes[ti] = true;
                    matchedTokens.push(query.tokens[ti] ? query.tokens[ti].normalized : String(ti));
                    consumedTokens.push(query.tokens[ti] ? query.tokens[ti].normalized : String(ti));
                }
            }
            for (var ti2 = 0; ti2 < (query.tokens || []).length; ti2 += 1) {
                if (!tokenIndexes[ti2]) missingTokens.push(query.tokens[ti2].normalized);
            }
            var fields = [];
            for (var ei2 = 0; ei2 < mergedEvidence.length; ei2 += 1) {
                var e2 = mergedEvidence[ei2];
                if (fields.length < 20) {
                    fields.push({
                        name: e2.field || "",
                        value: e2.fieldText || "",
                        normalized: Tokenize.normalizeText(e2.fieldText || ""),
                        weight: e2.weight || 0
                    });
                }
            }
            ctx._evidenceTrace[node.id] = {
                nodeId: node.id,
                fields: fields,
                consumedTokens: consumedTokens,
                matchedTokens: matchedTokens,
                missingTokens: missingTokens,
                summaries: null
            };
        }

        // Capture score trace
        if (node && node.id && ctx._scoreTrace) {
            ctx._scoreTrace[node.id] = {
                nodeId: node.id,
                final: finalScore,
                own: own.value,
                parent: inheritedScore,
                child: descendantBoost,
                inherited: inheritedScore,
                breakdown: [
                    { source: "own", value: own.value, reason: { code: "own_evidence", text: "Own evidence score" } },
                    { source: "inherited", value: inheritedScore, reason: { code: "inherited_evidence", text: "Inherited evidence score" } },
                    { source: "descendant", value: descendantBoost, reason: { code: "descendant_boost", text: "Descendant boost" } }
                ]
            };
        }

        // Capture policy trace — preserve real evaluated entries, only add aggregate/final
        if (node && node.id && ctx._policyTrace) {
            if (!ctx._policyTrace[node.id]) ctx._policyTrace[node.id] = {};
            var evidenceTrace = ctx._policyTrace[node.id].evidence;

            // Only synthesize evidence policy results if no real PolicyChain entries exist
            if (!evidenceTrace) {
                evidenceTrace = { kind: "evidence", evaluated: [], aggregate: null, final: null };
                ctx._policyTrace[node.id].evidence = evidenceTrace;
            }
            if (evidenceTrace.evaluated.length === 0) {
                var evidencePolicyResults = [];
                for (var ei3 = 0; ei3 < mergedEvidence.length; ei3 += 1) {
                    var e3 = mergedEvidence[ei3];
                    evidencePolicyResults.push({
                        name: e3.strategy || e3.field || "unknown",
                        priority: 0,
                        enabled: true,
                        returned: { value: { score: e3.score, weight: e3.weight, effective: e3.effective }, reasons: [{ code: e3.kind || "match", text: e3.reason || "evidence match" }] },
                        effect: "selected",
                        reasons: [{ code: e3.kind || "match", text: e3.reason || "evidence match" }]
                    });
                }
                evidenceTrace.evaluated = evidencePolicyResults;
            }
            evidenceTrace.aggregate = {
                strategy: "accumulate",
                inputCount: evidenceTrace.evaluated.length,
                result: { score: own.value },
                reasons: [{ code: "accumulated", text: "Evidence accumulated from " + evidenceTrace.evaluated.length + " policies" }]
            };
            evidenceTrace.final = {
                value: { score: own.value },
                decision: { score: own.value },
                reasons: [{ code: "evidence_done", text: "Evidence computed" }]
            };

            ctx._policyTrace[node.id].scoring = {
                kind: "scoring",
                evaluated: [
                    { name: "ownScore", priority: 0, enabled: true, returned: { value: own.value, reasons: [{ code: "score_own", text: "Own score: " + own.value }] }, effect: "combined", reasons: [{ code: "scored", text: "Score computed" }] },
                    { name: "inheritedScore", priority: 0, enabled: true, returned: { value: inheritedScore, reasons: [{ code: "score_inherited", text: "Inherited score: " + inheritedScore }] }, effect: "combined", reasons: [] },
                    { name: "descendantBoost", priority: 0, enabled: true, returned: { value: descendantBoost, reasons: [{ code: "score_descendant", text: "Descendant boost: " + descendantBoost }] }, effect: "combined", reasons: [] }
                ],
                aggregate: { strategy: "max", inputCount: 3, result: finalScore, reasons: [{ code: "max_score", text: "Final score is max of own/inherited/descendant" }] },
                final: { value: finalScore, reasons: [{ code: "score_final", text: "Final score: " + finalScore }] }
            };
            ctx._policyTrace[node.id].tokenFlow = {
                kind: "tokenFlow",
                evaluated: [{
                    name: (tokenFlowResult && tokenFlowResult.value && tokenFlowResult.value.reason) || "token-flow",
                    priority: 0,
                    enabled: true,
                    returned: tokenFlowResult && tokenFlowResult.value ? {
                        value: { consumed: (tokenFlowResult.value.consumed || []).length, passed: (tokenFlowResult.value.passed || []).length },
                        reasons: [{ code: "token_flow", text: (tokenFlowResult.value.reason || "token flow evaluated") }]
                    } : null,
                    effect: "selected",
                    reasons: [{ code: "token_flow", text: (tokenFlowResult && tokenFlowResult.value && tokenFlowResult.value.reason) || "token flow" }]
                }],
                final: { value: tokenFlowResult ? tokenFlowResult.value : null, reasons: [{ code: "token_flow_done", text: "Token flow evaluated" }] }
            };
        }

        var hasBaseEvidence = ownEvidence.some(function(e) {
            return e.field !== "usage" && e.field !== "recency";
        });
        // A node with only usage/recency evidence should not be visible unless
        // there is base evidence (field-match, semantic, switch-action, token-claim).
        var usageOrRecencyOnly = ownEvidence.length > 0 && !hasBaseEvidence;
        var ownVisible = own.visible && !usageOrRecencyOnly;

        var result = {
            node: node,
            allowed: selfAllowed,
            candidate: (selfAllowed && (directCandidate || ownEvidence.length > 0 || own.visible)) || retained.length > 0,
            pruned: false,
            evidence: mergedEvidence,
            ownEvidence: ownEvidence,
            inheritedEvidence: inheritedEvidence,
            ownScore: own.value,
            ownScoreBase: hasBaseEvidence ? own.value : 0,
            inheritedScore: inheritedScore,
            descendantScore: descendantBoost,
            score: finalScore,
            matchDepth: ownVisible ? 0 : bestChildMatchDepth < 9999 ? bestChildMatchDepth : 9999,
            ownVisible: ownVisible,
            hasBaseEvidence: hasBaseEvidence,
            visible: ctx.showHidden || ownVisible || retained.some(function(c) { return c.visible || ctx.showHidden; }) || (ctx.query.isEmpty && node.kind === "backend" && !directiveActive),
            visibleReason: ownVisible ? own.reason : (usageOrRecencyOnly ? "usage/recency only, no base evidence" : own.reason),
            children: profile.keepAllChildren ? retained : retained.sort(compareEvaluated),
            tokenFlow: tokenFlow
        };

        result.scoreBundle = ScoreBundle.fromEvaluated(result, query);
        return result;
    }

    readonly property var evaluateNode: prof.fn("evaluateNode", _evaluateNode)

    function _evaluateChildren(node, query, ctx, directiveActive) {
        var children = node.children || [];
        tracer.trace("evaluateChildren", function() { return { nodeId: node.id, childCount: children.length, queryEmpty: !!query.isEmpty }; });

        // Gate expensive child expansion for single-character or very short queries
        // when this node has exploration.descend === false (e.g., VPN country list).
        // Without this, every child (even pruned ones) gets walk-evaluated.
        // Bypass when the parent explicitly passed residual tokens for child search.
        var behavior = node && node.behavior || {};
        var exploration = behavior.exploration || {};
        var isShortQuery = query && !query.isEmpty && query.tokens && query.tokens.length <= 1
            && query.tokens[0].raw.length <= 2;
        if (isShortQuery && exploration.descend === false && children.length > 16
            && !(ctx && ctx.explicitResidualChildSearch)) {
            return [];
        }

        var effectiveQuery = (ctx && ctx.childQuery) || query;
        var effectiveCtx = ctx && ctx.tokenFlow ? ctx : ctx;

        var routeCtx = ctx && ctx.route;
        if (routeCtx && routeCtx.combine === "exclusive" && routeCtx.endpoints && routeCtx.endpoints.length > 0) {
            var allowedIds = {};
            for (var ri = 0; ri < routeCtx.endpoints.length; ri += 1) {
                var ep = routeCtx.endpoints[ri];
                if (ep.node && ep.node.backendId)
                    allowedIds[ep.node.backendId] = true;
            }
            var exclusiveChildren = children.filter(function(child) {
                return child.backendId && allowedIds[child.backendId];
            });
            if (exclusiveChildren.length > 0)
                return evaluateChildList(exclusiveChildren, effectiveQuery, effectiveCtx, directiveActive);
        }
        return evaluateChildList(children, effectiveQuery, effectiveCtx, directiveActive);
    }

    readonly property var evaluateChildren: prof.fn("evaluateChildren", _evaluateChildren)

    function evaluateChildList(children, query, ctx, directiveActive) {
        var out = [];
        // Skip evaluateNode for non-candidate children when candidate filtering is active.
        // Only skip when the query is non-empty (empty query browsing evaluates everything)
        // and when the context isn't in explicit residual search mode (which needs all children).
        var canSkipNonCandidates = ctx.candidateIds && !ctx.showHidden
            && !(ctx.directive && ctx.directive.active) && query && !query.isEmpty
            && !ctx.explicitResidualChildSearch;
        for (var i = 0; i < (children || []).length; i += 1) {
            var child = children[i];
            if (canSkipNonCandidates && !ctx.candidateIds[child.id]
                && child.kind !== "root" && child.kind !== "backend")
                continue;
            if (!directiveActive || nodeTreeMayContainDirective(child, ctx))
                out.push(evaluateNode(child, query, ctx));
        }
        return out;
    }

    function compareEvaluated(a, b) {
        var scoreDelta = b.score - a.score;
        if (Math.abs(scoreDelta) > 0.0001) return scoreDelta;
        var backendDelta = (b.node.backendPriority || 0) - (a.node.backendPriority || 0);
        if (backendDelta !== 0) return backendDelta;
        var lengthDelta = String(a.node.label || "").length - String(b.node.label || "").length;
        if (lengthDelta !== 0) return lengthDelta;
        return String(a.node.label || "").localeCompare(String(b.node.label || ""));
    }

    function collectParentChain(node) {
        if (node.__parentChain) return node.__parentChain;
        var chain = [];
        var cur = node;
        while (cur && cur.kind !== "root") {
            chain.unshift(cur);
            cur = cur.parent;
        }
        node.__parentChain = chain;
        return chain;
    }

    function fuzzyAliasScore(token, alias) {
        var maxDistance = Tokenize.fuzzyDistanceLimit(token, alias);
        if (maxDistance <= 0 || Math.abs(alias.length - token.length) > maxDistance || token === alias)
            return 0;
        var distance = Tokenize.boundedDamerauLevenshtein(token, alias, maxDistance);
        if (distance > maxDistance)
            return 0;
        var similarity = 1 - distance / Math.max(token.length, alias.length, 1);
        return 0.44 + similarity * 0.14;
    }

    function hasBaseEvidence(ev) {
        return (ev.ownEvidence || ev.evidence || []).some(function(e) {
            return e.field !== "usage" && e.field !== "recency";
        });
    }

    function skippedDepthMultiplier(node, evidenceItems, query, ctx) {
        var ownExactness = evidenceExactness(evidenceItems || []);
        var chain = collectParentChain(node);
        var skipped = 0;
        var multiplier = 1;

        for (var i = chain.length - 2; i >= 0; i -= 1) {
            var ancestor = chain[i];
            if (!ancestor || ancestor.kind === "root" || ancestor.kind === "backend")
                continue;
            if (ancestorMatchesQuery(ancestor, query, ctx))
                break;
            skipped += 1;
            var nodePenalty = depthPenaltyFor(ancestor);
            if (nodePenalty <= 0)
                continue;
            var skippedWeight = Math.pow(skipped, 1.15);
            var exactnessRelief = ownExactness >= 0.9 ? 0.55 : 0.04 + ownExactness * 0.12;
            var penalty = Tokenize.clamp(nodePenalty * skippedWeight * (1 - exactnessRelief), 0, 0.92);
            multiplier *= (1 - penalty);
        }

        return Tokenize.clamp(multiplier, 0, 1);
    }

    function depthPenaltyFor(node) {
        var behavior = node && node.behavior || {};
        var raw = behavior.depthPenalty;

        var n = Number(raw === undefined ? 0 : raw);
        return isFinite(n) ? Tokenize.clamp(n, 0, 1) : 0;
    }

    function ancestorMatchesQuery(node, query, ctx) {
        var fields = IndexBuilder.searchableFields(node);
        var filtered = Evidence.filterFields(fields, "primary");
        for (var i = 0; i < filtered.length; i += 1) {
            var matches = Evidence.matchField(filtered[i], query, ["exact", "prefix", "compact", "acronym"]);
            if (matches && matches.length > 0)
                return true;
        }
        return false;
    }

    function evidenceExactness(evidenceItems) {
        var best = 0;
        for (var i = 0; i < (evidenceItems || []).length; i += 1) {
            var e = evidenceItems[i] || {};
            var kind = String(e.kind || e.exactness || e.strategy || "");
            var value = 0.25;
            if (kind.indexOf("exact") >= 0)
                value = 1.0;
            else if (kind.indexOf("acronym") >= 0)
                value = 0.65;
            else if (kind.indexOf("prefix") >= 0)
                value = 0.42;
            else if (kind.indexOf("compact") >= 0)
                value = 0.38;
            else if (kind.indexOf("semantic") >= 0)
                value = 0.34;
            else if (kind.indexOf("substring") >= 0)
                value = 0.22;
            else if (kind.indexOf("fuzzy") >= 0)
                value = 0.16;
            best = Math.max(best, value);
        }
        return best;
    }
}
