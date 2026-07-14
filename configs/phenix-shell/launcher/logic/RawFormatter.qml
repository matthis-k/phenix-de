import QtQml
import qs.services

BaseFormatter {
    readonly property var tracer: Logger.scope("launcher.formatter.raw", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.formatter.raw", { category: "launcher" })
    formatterName: "raw"

    function serialize(evaluation, request) {
        tracer.trace("serialize", function() { return { hasEvaluation: !!evaluation, maxNodes: request?.maxNodes }; });
        if (!evaluation) return { error: { code: "no_evaluation", message: "No evaluation available" } };

        var options = request || {};
        var maxNodes = Math.max(1, Math.min(options.maxNodes || 50, 500));
        var maxDepth = Math.max(1, Math.min(options.maxDepth || 5, 20));
        var includeHidden = options.includeHidden !== false;

        var data = {
            query: evaluation.query || {},
            stats: evaluation.stats || {},
            backendTrace: (evaluation.backendTrace || []).slice(0, 20)
        };

        if (options.includePipelineStages && evaluation._stages) {
            data.stages = evaluation._stages;
        }

        data.visibleTree = serializeTreeBounded(evaluation.visibleTree || [], 0, maxDepth, maxNodes, includeHidden);

        var cidx = {};
        var count = 0;
        for (var id in (evaluation.candidateIndex || {})) {
            if (count >= maxNodes) break;
            if (!includeHidden && !isIdVisible(evaluation, id)) continue;
            cidx[id] = evaluation.candidateIndex[id];
            count += 1;
        }
        data.candidateIndex = cidx;

        if (evaluation.evidenceTrace) {
            data.evidenceTrace = {};
            count = 0;
            for (var eid in evaluation.evidenceTrace) {
                if (count >= maxNodes) { data.evidenceTrace._truncated = true; break; }
                if (!includeHidden && !isIdVisible(evaluation, eid)) continue;
                data.evidenceTrace[eid] = summarizeEvidence(evaluation.evidenceTrace[eid]);
                count += 1;
            }
        }

        if (evaluation.scoreTrace) {
            data.scoreTrace = {};
            count = 0;
            for (var sid in evaluation.scoreTrace) {
                if (count >= maxNodes) { data.scoreTrace._truncated = true; break; }
                if (!includeHidden && !isIdVisible(evaluation, sid)) continue;
                data.scoreTrace[sid] = evaluation.scoreTrace[sid];
                count += 1;
            }
        }

        if (options.backend) {
            data.backend = {};
            for (var bid in data.candidateIndex) {
                if (data.candidateIndex[bid].backendId === options.backend)
                    data.backend[bid] = data.candidateIndex[bid];
            }
        }

        return {
            limited: true,
            limit: {
                maxNodes: maxNodes,
                maxDepth: maxDepth
            },
            data: data
        };
    }

    function serializeTreeBounded(nodes, depth, maxDepth, maxNodes, includeHidden) {
        if (depth >= maxDepth || !nodes) return [];
        var out = [];
        for (var i = 0; i < nodes.length && out.length < maxNodes; i += 1) {
            var n = nodes[i];
            var node = {
                id: n.id || "",
                title: n.title || "",
                kind: n.kind || "",
                depth: depth,
                placement: n.placement || "",
                visible: true,
                score: n.score || 0,
                children: serializeTreeBounded(n.children, depth + 1, maxDepth, maxNodes - out.length, includeHidden)
            };
            out.push(node);
        }
        return out;
    }

    function isIdVisible(evaluation, id) {
        if (!evaluation.visibleTree) return false;
        function walk(nodes) {
            for (var i = 0; i < (nodes || []).length; i += 1) {
                if (nodes[i].id === id) return true;
                var found = walk(nodes[i].children);
                if (found) return true;
            }
            return false;
        }
        return walk(evaluation.visibleTree);
    }

    function summarizeEvidence(et) {
        if (!et) return null;
        return {
            matchedTokens: (et.matchedTokens || []).slice(0, 20),
            consumedTokens: (et.consumedTokens || []).slice(0, 20),
            missingTokens: (et.missingTokens || []).slice(0, 10),
            fieldCount: (et.fields || []).length
        };
    }
}
