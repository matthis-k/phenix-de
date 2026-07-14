import QtQml
import qs.services

BaseFormatter {
    readonly property var tracer: Logger.scope("launcher.formatter.policies", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.formatter.policies", { category: "launcher" })
    formatterName: "policies"

    function serialize(evaluation, request) {
        tracer.trace("serialize", function() { return { nodeId: request?.nodeId, kind: request?.kind }; });
        if (!evaluation) return { error: { code: "no_evaluation", message: "No evaluation available" } };

        var nodeId = request.nodeId || "";
        var kind = request.kind || "";
        var maxNodes = request.maxNodes || 50;

        var policyTrace = evaluation.policyTrace || {};
        var decisionTrace = evaluation.decisionTrace || {};

        if (nodeId) {
            var nodePolicy = policyTrace[nodeId] || {};
            var nodeInfo = findNodeInfo(evaluation, nodeId);

            var kinds = kind ? [kind] : Object.keys(nodePolicy);
            var policyKinds = [];
            var count = 0;
            for (var ki = 0; ki < kinds.length && count < maxNodes; ki += 1) {
                var k = kinds[ki];
                var kt = nodePolicy[k];
                if (!kt) continue;
                count += 1;
                policyKinds.push(serializePolicyKind(k, kt));
            }

            var decisions = decisionTrace[nodeId] || null;

            return {
                scope: "node",
                node: {
                    id: nodeId,
                    title: nodeInfo ? nodeInfo.title : "",
                    visible: nodeInfo ? nodeInfo.visible : false,
                    placement: nodeInfo ? nodeInfo.placement : ""
                },
                policyKinds: policyKinds
            };
        }

        var allNodeIds = Object.keys(policyTrace);
        var includedCount = Math.min(allNodeIds.length, maxNodes);
        var truncated = allNodeIds.length > maxNodes;

        var policyKinds = [];
        var kindCount = {};
        if (kind) {
            for (var ni = 0; ni < allNodeIds.length && ni < maxNodes; ni += 1) {
                var nid = allNodeIds[ni];
                var nk = policyTrace[nid][kind];
                if (nk) {
                    if (!kindCount[kind]) { kindCount[kind] = 0; policyKinds.push(serializePolicyKind(kind, nk)); }
                    kindCount[kind] = (kindCount[kind] || 0) + 1;
                }
            }
        } else {
            for (var ni2 = 0; ni2 < allNodeIds.length && ni2 < maxNodes; ni2 += 1) {
                var nid2 = allNodeIds[ni2];
                var kinds2 = policyTrace[nid2] || {};
                for (var k2 in kinds2) {
                    if (!kindCount[k2]) { kindCount[k2] = 0; policyKinds.push(serializePolicyKindSummary(k2)); }
                    kindCount[k2] += 1;
                }
            }
        }

        return {
            scope: "query",
            queryWide: {
                visibleNodeCount: (evaluation.stats && evaluation.stats.visibleNodeCount) || 0,
                includedNodeCount: includedCount,
                truncated: truncated
            },
            policyKinds: policyKinds
        };
    }

    function serializePolicyKind(kind, trace) {
        if (!trace) return { kind: kind || "", evaluated: [], aggregate: null, decider: null, final: null };

        return {
            kind: trace.kind || kind,
            evaluated: (trace.evaluated || []).map(function(e) {
                return {
                    name: e.name || "",
                    priority: e.priority || 0,
                    enabled: e.enabled !== false,
                    args: e.args || null,
                    defaultedArgs: e.defaultedArgs || null,
                    returned: e.returned || null,
                    effect: e.effect || "no-op",
                    reasons: e.reasons || []
                };
            }),
            aggregate: trace.aggregate ? {
                strategy: trace.aggregate.strategy || "",
                inputCount: trace.aggregate.inputCount || 0,
                result: trace.aggregate.result !== undefined ? trace.aggregate.result : null,
                reasons: trace.aggregate.reasons || []
            } : null,
            decider: trace.decider ? {
                name: trace.decider.name || "",
                input: trace.decider.input !== undefined ? trace.decider.input : null,
                output: trace.decider.output !== undefined ? trace.decider.output : null,
                reasons: trace.decider.reasons || []
            } : null,
            final: trace.final ? {
                value: trace.final.value !== undefined ? trace.final.value : null,
                reasons: trace.final.reasons || [],
                source: trace.final.source || ""
            } : null
        };
    }

    function serializePolicyKindSummary(kind) {
        return {
            kind: kind,
            evaluated: [],
            aggregate: null,
            decider: null,
            final: null,
            _summary: true
        };
    }

    function findNodeInfo(evaluation, nodeId) {
        if (evaluation.candidateIndex && evaluation.candidateIndex[nodeId]) {
            var ci = evaluation.candidateIndex[nodeId];
            return { title: ci.label || "", visible: ci.visible || false, placement: ci.placement || "" };
        }
        var vn = findInVisibleTree(evaluation.visibleTree || [], nodeId);
        if (vn) return { title: vn.title || "", visible: true, placement: vn.placement || "" };
        return null;
    }

    function findInVisibleTree(nodes, nodeId) {
        for (var i = 0; i < (nodes || []).length; i += 1) {
            if (nodes[i].id === nodeId) return nodes[i];
            var found = findInVisibleTree(nodes[i].children, nodeId);
            if (found) return found;
        }
        return null;
    }
}
