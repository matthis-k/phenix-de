import QtQml
import qs.services

BaseFormatter {
    readonly property var tracer: Logger.scope("launcher.formatter.inspect", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.formatter.inspect", { category: "launcher" })
    formatterName: "inspect"

    function serialize(evaluation, request) {
        tracer.trace("serialize", function() { return { nodeId: request?.nodeId }; });
        if (!evaluation) return { error: { code: "no_evaluation", message: "No evaluation available" } };
        var nodeId = String(request.nodeId || "");
        if (!nodeId) return { error: { code: "no_node_id", message: "nodeId is required" } };

        var node = evaluation.candidateIndex ? evaluation.candidateIndex[nodeId] : null;
        var visibleNode = findInVisibleTree(evaluation.visibleTree || [], nodeId);
        if (!node && !visibleNode) {
            var availableIds = evaluation.candidateIndex ? Object.keys(evaluation.candidateIndex).slice(0, 50) : [];
            return {
                error: {
                    code: "node_not_found",
                    message: "No candidate with id '" + nodeId + "' exists in this evaluation.",
                    availableVisibleIds: availableIds
                }
            };
        }

        var include = request.include || {};

        var result = {
            node: {
                id: nodeId,
                title: (node && node.label) || (visibleNode && visibleNode.title) || "",
                kind: (node && node.kind) || (visibleNode && visibleNode.kind) || "",
                backend: (node && node.backendId) || "",
                path: (node && node.path) || [],
                placement: (node && node.placement) || (visibleNode && visibleNode.placement) || "",
                visible: node ? !!node.visible : true
            }
        };

        if (include.fields !== false) {
            var evidenceTrace = evaluation.evidenceTrace ? evaluation.evidenceTrace[nodeId] : null;
            var fields = [];
            if (evidenceTrace && evidenceTrace.fields) {
                fields = evidenceTrace.fields.map(function(f) {
                    return { name: f.name, value: f.value, normalized: f.normalized, weight: f.weight };
                });
            }
            result.searchable = { fields: fields };
        }

        if (include.matching !== false) {
            var et = evaluation.evidenceTrace ? evaluation.evidenceTrace[nodeId] : null;
            result.matching = {
                consumedTokens: et ? (et.consumedTokens || []) : [],
                matchedTokens: et ? (et.matchedTokens || []) : [],
                missingTokens: et ? (et.missingTokens || []) : [],
                ranges: et ? (et.ranges || []) : [],
                pathMatch: et ? (et.summaries && et.summaries.pathMatch) || null : null,
                acronymMatch: et ? (et.summaries && et.summaries.acronymMatch) || null : null
            };
        }

        if (include.scoring !== false) {
            var st = evaluation.scoreTrace ? evaluation.scoreTrace[nodeId] : null;
            result.scoring = {
                final: st ? st.final : (node ? node.score : null),
                own: st ? st.own : (node ? node.ownScore : null),
                parent: st ? st.parent : null,
                child: st ? st.child : null,
                inherited: st ? st.inherited : null,
                breakdown: st ? (st.breakdown || []) : []
            };
        }

        if (include.decisions !== false) {
            var dt = evaluation.decisionTrace ? evaluation.decisionTrace[nodeId] : null;
            result.decisions = {
                visibility: dt ? dt.visibility : null,
                placement: dt ? dt.placement : null,
                flattening: dt ? dt.flattening : null,
                breadcrumbs: dt ? dt.breadcrumbs : null,
                defaultAction: dt ? dt.defaultAction : null,
                childVisibility: dt ? dt.childVisibility : null
            };
        }

        if (include.childrenSummary !== false) {
            var visibleChildren = [];
            var hiddenCount = 0;
            var filteredCount = 0;
            if (evaluation.visibleTree) {
                var vn = findInVisibleTree(evaluation.visibleTree, nodeId);
                if (vn && vn.children) {
                    for (var ci = 0; ci < vn.children.length; ci += 1) {
                        visibleChildren.push(vn.children[ci].id || "");
                    }
                }
            }
            result.childrenSummary = {
                visibleChildIds: visibleChildren,
                hiddenChildCount: hiddenCount,
                filteredChildCount: filteredCount
            };
        }

        return result;
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
