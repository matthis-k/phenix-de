import QtQml
import qs.services

BaseFormatter {
    readonly property var tracer: Logger.scope("launcher.formatter.action", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.formatter.action", { category: "launcher" })
    formatterName: "action"

    function serialize(evaluation, request) {
        tracer.trace("serialize", function() { return { nodeId: request?.nodeId, input: request?.input }; });
        if (!evaluation) return { error: { code: "no_evaluation", message: "No evaluation available" } };
        var nodeId = String(request.nodeId || "");
        if (!nodeId) return { error: { code: "no_node_id", message: "nodeId is required" } };
        var input = String(request.input || "enter").toLowerCase().replace(/-/g, "-");

        var nodeInfo = findNodeInfo(evaluation, nodeId);
        if (!nodeInfo) {
            return { error: { code: "node_not_found", message: "No node with id '" + nodeId + "' found" } };
        }

        var selected = evaluation.selection && evaluation.selection.selectedId === nodeId;
        var actionIndex = evaluation.actionIndex || {};

        // Prefer enriched actionIndex (built from real RecipeResolver/row data)
        var nodeActions = actionIndex[nodeId] || {};
        var resolved = nodeActions[input] || resolveFallbackAction(evaluation, nodeId, input, nodeInfo);

        // Build alternative list from ALL known inputs in actionIndex (not just hardcoded list)
        var alternatives = [];
        for (var ak in nodeActions) {
            if (ak === input) continue;
            var alt = nodeActions[ak];
            if (alt && alt.exists) {
                alternatives.push({
                    input: ak,
                    action: alt.name || "",
                    reasons: alt.reasons || [],
                    steps: (alt.steps || []).map(function(s) { return { kind: s.kind, label: s.label }; })
                });
            }
        }

        var result = {
            node: {
                id: nodeId,
                title: nodeInfo.title,
                visible: nodeInfo.visible,
                selected: selected,
                executable: nodeInfo.executable || !!resolved.exists
            },
            input: input,
            resolvedAction: {
                exists: resolved.exists || false,
                name: resolved.name || "",
                label: resolved.label || "",
                source: resolved.source || "",
                reasons: resolved.reasons || [],
                steps: resolved.steps || []
            },
            alternatives: alternatives
        };

        return result;
    }

    function visibleHints(evaluation, nodeId) {
        var hints = [];
        if (evaluation.visibleTree) {
            var vn = findInVisibleTree(evaluation.visibleTree, nodeId);
            if (!vn) hints.push("Node not found in visibleTree.");
            else if (!vn.visible) hints.push("Node is hidden in visibleTree.");
        }
        if (evaluation.candidateIndex) {
            var ci = evaluation.candidateIndex[nodeId];
            if (ci) {
                if (!ci.visible) hints.push("Candidate is marked not visible.");
                if (ci.placement && ci.placement.indexOf("hidden") >= 0) hints.push("Placement: " + ci.placement);
            }
        }
        return hints;
    }

    function resolveFallbackAction(evaluation, nodeId, input, nodeInfo) {
        // Diagnostic-only fallback: never reconstruct action behavior from row data.
        // The actionIndex from the real resolver path is the single source of truth.
        // This function only produces structured diagnostics explaining why no action
        // was found in the actionIndex.
        var row = findRow(evaluation, nodeId);
        var hasRowHint = row && !!(row.enter || row.recipes || row.defaultAction || (row.actions && row.actions.length > 0));
        var visibilityHints = visibleHints(evaluation, nodeId);

        var debugHints = [];
        if (hasRowHint) {
            debugHints.push("Node has row data but actionIndex has no entry for input '" + input +
                "'. Available inputs in actionIndex: " + Object.keys(evaluation.actionIndex || {}).join(", ") + ".");
        }
        if (!hasRowHint) {
            debugHints.push("Node has no row data — likely filtered out or not present in evaluation.rows.");
        }
        if (visibilityHints.length > 0) {
            debugHints = debugHints.concat(visibilityHints);
        }

        return {
            exists: false,
            name: "noop",
            label: "No action available for input '" + input + "'",
            source: "action-resolver",
            reasons: [{ code: "no_action_in_index", text: "actionIndex has no entry for node '" + nodeId + "' input '" + input + "'. This is diagnostic-only; use debug/resolve for authoritative action resolution." }],
            steps: [],
            debugHints: debugHints.length > 0 ? debugHints : undefined
        };
    }

    function findRow(evaluation, nodeId) {
        if (!evaluation || !evaluation.rows) return null;
        function walk(rows) {
            for (var i = 0; i < (rows || []).length; i += 1) {
                var r = rows[i];
                if ((r.nodeId || r.id || "") === nodeId) return r;
                var found = walk(r.children);
                if (found) return found;
            }
            return null;
        }
        return walk(evaluation.rows);
    }

    function findNodeInfo(evaluation, nodeId) {
        // Search rows first (most accurate for executable info)
        var row = findRow(evaluation, nodeId);
        if (row) {
            return { id: nodeId, title: row.title || row.label || "", visible: true, executable: !!row.executable || !!row.hasAction };
        }
        var vn = findInVisibleTree(evaluation.visibleTree || [], nodeId);
        if (vn) return { id: nodeId, title: vn.title || "", visible: true, executable: vn.executable || false };
        if (evaluation.candidateIndex && evaluation.candidateIndex[nodeId]) {
            var ci = evaluation.candidateIndex[nodeId];
            return { id: nodeId, title: ci.label || "", visible: ci.visible, executable: false };
        }
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
