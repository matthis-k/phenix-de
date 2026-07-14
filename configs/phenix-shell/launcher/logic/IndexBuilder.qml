pragma Singleton
import QtQml
import Quickshell
import qs.services
import "Tokenize.qml"

Singleton {
    readonly property var prof: Profiler.scope("launcher.indexBuilder", { category: "launcher" })
    readonly property var tracer: Logger.scope("launcher.indexBuilder", { category: "launcher" })
    function prepareSearchableField(field) {
        var text = String(field.text === undefined || field.text === null ? "" : field.text);
        field.text = text;
        field.normText = Tokenize.normalizeText(text);
        field.words = Tokenize.splitWordsWithRanges(text);
        field.compact = Tokenize.compactWithMap(text);
        field.acronymLetters = Tokenize.getAcronymRanges(text);
        return field;
    }

    function searchableFields(node) {
        if (node.__searchableFields)
            return node.__searchableFields;
        tracer.trace("searchableFields", function() { return { nodeId: node.id, kind: node.kind }; });
        var w = node.fieldWeights || {};
        var fields = [{ field: "label", text: node.label, weight: w.label === undefined ? 1.0 : w.label, nodeId: node.id, primary: true }];
        if (node.subtitle) fields.push({ field: "subtitle", text: node.subtitle, weight: w.subtitle === undefined ? 0.55 : w.subtitle, nodeId: node.id });
        if (node.aliases && node.aliases.length) fields.push({ field: "aliases", text: node.aliases.join(" "), weight: w.aliases === undefined ? 0.72 : w.aliases, nodeId: node.id, primary: true });
        if (node.keywords && node.keywords.length) fields.push({ field: "keywords", text: node.keywords.join(" "), weight: w.keywords === undefined ? 0.45 : w.keywords, nodeId: node.id });
        if (node.command) fields.push({ field: "command", text: node.command, weight: w.command === undefined ? 0.25 : w.command, nodeId: node.id });
        if (node.path) fields.push({ field: "path", text: node.path, weight: w.path === undefined ? 0.38 : w.path, nodeId: node.id });
        if (node.breadcrumbLabel) fields.push({ field: "breadcrumb", text: node.breadcrumbLabel, weight: w.breadcrumb === undefined ? 0.5 : w.breadcrumb, nodeId: node.id });
        node.__searchableFields = fields.map(prepareSearchableField);
        return node.__searchableFields;
    }

    function buildSearchIndex(root) {
        tracer.trace("buildSearchIndex", function() { return { rootId: root && root.id }; });
        var index = { exact: {}, prefix: {}, compact: {}, compactPrefix: {}, acronym: {}, acronymPrefix: {}, terms: {}, termsByLength: {}, nodesById: {} };
        var _termsSeen = {};
        function addTermToTermsByLength(term) {
            if (!term || _termsSeen[term]) return;
            _termsSeen[term] = true;
            var len = term.length;
            if (!index.termsByLength[len]) index.termsByLength[len] = [];
            index.termsByLength[len].push(term);
        }
        function mergeMap(target, source) {
            for (var key in source) {
                if (!target[key]) target[key] = [];
                var nodes = source[key] || [];
                for (var ni = 0; ni < nodes.length; ni += 1)
                    if (target[key].indexOf(nodes[ni]) < 0)
                        target[key].push(nodes[ni]);
            }
        }
        function visit(node, parentBreadcrumbAcro) {
            index.nodesById[node.id] = node;
            delete node.__searchableFields;
            var labelAcro = Tokenize.getAcronymRanges(node.label || "");
            var firstLetter = (labelAcro[0] || {}).char || "";
            var parentLetter = (parentBreadcrumbAcro || "").slice(-1);
            var breadcrumbAcro = parentBreadcrumbAcro || "";
            if (firstLetter) {
                breadcrumbAcro = (parentLetter || "") + firstLetter;
                if (breadcrumbAcro.length >= 2)
                    node.breadcrumbLabel = breadcrumbAcro.toUpperCase().split("").join(" ");
            }
            var fields = searchableFields(node);
            for (var fi = 0; fi < fields.length; fi += 1)
                addFieldToIndex(index, fields[fi], node);
            for (var ci = 0; ci < (node.children || []).length; ci += 1)
                visit(node.children[ci], breadcrumbAcro);
        }
        function addIndexEntry(map, key, nd) {
            if (!key) return;
            if (!map[key]) map[key] = [];
            if (map[key].indexOf(nd) < 0) map[key].push(nd);
        }
        function addFieldToIndex(idx, field, nd) {
            var words = field.words || [];
            for (var wi = 0; wi < words.length; wi += 1) {
                var word = words[wi].norm;
                if (!word) continue;
                addIndexEntry(idx.exact, word, nd);
                addIndexEntry(idx.terms, word, nd);
                addTermToTermsByLength(word);
                for (var pi = 1; pi <= word.length; pi += 1)
                    addIndexEntry(idx.prefix, word.slice(0, pi), nd);
            }
            var compact = field.compact && field.compact.compact || "";
            if (compact.length >= 2) {
                addIndexEntry(idx.compact, compact, nd);
                addIndexEntry(idx.terms, compact, nd);
                addTermToTermsByLength(compact);
                for (var cpi = 2; cpi <= compact.length; cpi += 1)
                    addIndexEntry(idx.compactPrefix, compact.slice(0, cpi), nd);
            }
            var acronym = (field.acronymLetters || []).map(function(x) { return x.char; }).join("");
            if (acronym.length >= 2) {
                addIndexEntry(idx.acronym, acronym, nd);
                for (var api = 2; api <= acronym.length; api += 1)
                    addIndexEntry(idx.acronymPrefix, acronym.slice(0, api), nd);
            }
        }
        visit(root, "");
        computeDirectiveTagClosure(root);
        root.__searchIndex = index;
        return index;
    }

    function computeDirectiveTagClosure(node) {
        if (node.__directiveTagClosure) return node.__directiveTagClosure;
        var closure = {};
        for (var ti = 0; ti < (node.tags || []).length; ti += 1)
            closure[node.tags[ti]] = true;
        for (var ci = 0; ci < (node.children || []).length; ci += 1) {
            var childClosure = computeDirectiveTagClosure(node.children[ci]);
            for (var key in childClosure) closure[key] = true;
        }
        node.__directiveTagClosure = closure;
        return closure;
    }

    function collectCandidateIds(index, query, marked, capState) {
        if (!index || query.isEmpty) return null;
        marked = marked || {};
        capState = capState || { hits: 0, cap: 256, fuzzyCap: 12 };
        for (var ti = 0; ti < query.tokens.length; ti += 1) {
            if (capState.hits >= capState.cap) break;
            var token = query.tokens[ti].normalized;
            var compactToken = Tokenize.compactWithMap(query.tokens[ti].raw).compact || token;
            collectIndexHitsCapped(index.exact, token, marked, capState);
            collectIndexHitsCapped(index.prefix, token, marked, capState);
            collectIndexHitsCapped(index.compact, compactToken, marked, capState);
            collectIndexHitsCapped(index.compactPrefix, compactToken, marked, capState);
            collectIndexHitsCapped(index.acronym, token, marked, capState);
            collectIndexHitsCapped(index.acronymPrefix, token, marked, capState);
            collectFuzzyHitsCapped(index, token, marked, capState);
        }
        return marked;
    }

    function collectIndexHitsCapped(map, key, marked, capState) {
        var nodes = map[key] || [];
        for (var i = 0; i < nodes.length; i += 1) {
            if (capState.hits >= capState.cap) return;
            capState.hits += 1;
                    markNodeFamily(marked, nodes[i], key, capState.query);
        }
    }

    function collectFuzzyHitsCapped(idx, token, marked, capState) {
        if (String(token || "").length < 4) return;
        var tokenLen = token.length;
        // Tighter candidate-collection distance: floor(len/4), min 1.
        // Only catches very close misspellings, not tangentially related words.
        var maxDist = Math.max(1, Math.floor(tokenLen / 4));
        var fuzzyLimit = capState.fuzzyCap || 12;
        var minLen = Math.max(tokenLen - 2, 3);
        var maxLen = tokenLen + 2;
        for (var len = minLen; len <= maxLen; len += 1) {
            if (fuzzyLimit <= 0) return;
            var bucket = idx.termsByLength[len];
            if (!bucket) continue;
            for (var ti = 0; ti < bucket.length; ti += 1) {
                if (capState.hits >= capState.cap) return;
                if (fuzzyLimit <= 0) return;
                var term = bucket[ti];
                if (term === token) continue;
                if (Tokenize.boundedDamerauLevenshtein(token, term, maxDist) > maxDist) continue;
                fuzzyLimit -= 1;
                collectIndexHitsCapped(idx.terms, term, marked, capState);
            }
        }
    }

    function markNodeAndAncestors(marked, node) {
        var cur = node;
        while (cur) {
            if (marked[cur.id]) break;
            marked[cur.id] = true;
            cur = cur.parent;
        }
    }

    function markNodeAndDescendants(marked, node, limit) {
        if (limit && limit.remaining <= 0) return;
        if (marked[node.id]) return;
        marked[node.id] = true;
        if (limit) limit.remaining -= 1;
        var children = node.children;
        if (!children) return;
        for (var i = 0; i < children.length; i += 1) {
            if (limit && limit.remaining <= 0) return;
            markNodeAndDescendants(marked, children[i], limit);
        }
    }

    function explorationPreviewLimit(node) {
        var behavior = node && node.behavior || {};
        var exploration = behavior.exploration || {};
        if (exploration.previewChildrenLimit !== undefined) {
            var configured = Number(exploration.previewChildrenLimit);
            if (isFinite(configured) && configured >= 0)
                return configured;
        }
        return 8;
    }

    function markPreviewChildren(marked, node, limit) {
        var children = node.children || [];
        for (var i = 0; i < children.length && i < limit; i += 1)
            marked[children[i].id] = true;
    }

    function markNodeFamily(marked, node, matchKey, query) {
        markNodeAndAncestors(marked, node);
        var exploration = node && node.behavior && node.behavior.exploration || {};
        if (exploration.descend === false) {
            if (query && query.lastTokenEmpty)
                markPreviewChildren(marked, node, explorationPreviewLimit(node));
            return;
        }
        // Limit descendant marking to prevent a single match from flooding
        // the candidate set with hundreds of children (e.g. 50 VPN destinations).
        markNodeAndDescendants(marked, node, { remaining: 32 });
    }

    function _collectCandidateIdsForRoots(roots, query, cap) {
        if (query.isEmpty) return null;
        tracer.trace("collectCandidateIdsForRoots", function() { return { rootCount: (roots || []).length, tokenCount: (query.tokens || []).length, cap: cap }; });
        // Single-character queries get a lower cap to prevent excessive weak matches
        var isSingleChar = query && !query.isEmpty && query.tokens && query.tokens.length === 1
            && query.tokens[0].raw.length <= 1;
        var effectiveCap = isSingleChar ? Math.min(cap || 256, 80) : (cap || 256);
        var marked = {};
        var capState = { hits: 0, cap: effectiveCap, query: query };
        for (var i = 0; i < (roots || []).length; i += 1) {
            if (capState.hits >= capState.cap) break;
            var index = roots[i].__searchIndex || buildSearchIndex(roots[i]);
            collectCandidateIds(index, query, marked, capState);
        }
        return marked;
    }
    readonly property var collectCandidateIdsForRoots: prof.fn("collectCandidateIdsForRoots", _collectCandidateIdsForRoots)
}
