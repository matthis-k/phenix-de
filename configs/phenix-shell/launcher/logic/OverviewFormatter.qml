import QtQml
import qs.services

BaseFormatter {
    readonly property var tracer: Logger.scope("launcher.formatter.overview", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.formatter.overview", { category: "launcher" })
    formatterName: "overview"

    function serialize(evaluation, options) {
        options = options || {};
        tracer.trace("serialize", function() { return { hasEvaluation: !!evaluation }; });
        if (!evaluation) return { backendSummary: [], selection: null, visible: [], stats: { visibleNodeCount: 0, hiddenCandidateCount: 0, evaluatedNodeCount: 0, durationMs: 0 } };

        var maxDepth = options.maxDepth !== undefined ? options.maxDepth : 10;
        var maxChildren = options.maxChildren !== undefined ? options.maxChildren : 32;

        var backendSummary = (evaluation.backendTrace || []).map(function(bt) {
            return {
                backend: bt.backend,
                participated: bt.participated,
                candidateCount: bt.candidateCount || 0,
                visibleCount: bt.visibleCount || 0,
                reasons: bt.reasons || []
            };
        });

        var selection = evaluation.selection ? {
            selectedId: evaluation.selection.selectedId || null,
            selectedIndex: evaluation.selection.selectedIndex !== undefined ? evaluation.selection.selectedIndex : null,
            selectedTitle: evaluation.selection.selectedTitle || null,
            reasons: evaluation.selection.reasons || []
        } : null;

        var visible = serializeTree(evaluation.visibleTree || [], 0, maxDepth, maxChildren);

        var s = evaluation.stats || {};
        var visibleCount = visible.length;
        var stats = {
            finalVisibleRowCount: s.finalVisibleRowCount || visibleCount,
            finalVisibleTreeNodeCount: s.finalVisibleTreeNodeCount || 0,
            evaluatedVisibleCandidateCount: s.evaluatedVisibleCandidateCount || 0,
            hiddenCandidateCount: s.hiddenCandidateCount || 0,
            evaluatedNodeCount: s.evaluatedNodeCount || 0,
            prunedNodeCount: s.prunedNodeCount || 0,
            visibleNodeCount: s.finalVisibleTreeNodeCount || 0,
            durationMs: s.durationMs || 0
        };

        return {
            backendSummary: backendSummary,
            selection: selection,
            visible: visible,
            stats: stats
        };
    }

    function serializeTree(nodes, depth, maxDepth, maxChildren) {
        if (depth >= maxDepth || !nodes) return [];
        var out = [];
        var count = Math.min(nodes.length, maxChildren);
        for (var i = 0; i < count; i += 1) {
            var n = nodes[i];
            var decisionsNull = !n.decisions || !n.decisions.visibility || !n.decisions.placement;
            var node = {
                id: n.id || "",
                title: n.title || "",
                kind: n.kind || "",
                depth: depth,
                placement: n.placement || "",
                visible: true,
                executable: !!n.executable,
                decisionsNull: decisionsNull,
                decisions: n.decisions ? {
                    visibility: n.decisions.visibility ? {
                        value: n.decisions.visibility.value,
                        reasons: n.decisions.visibility.reasons || []
                    } : null,
                    placement: n.decisions.placement ? {
                        value: n.decisions.placement.value,
                        reasons: n.decisions.placement.reasons || []
                    } : null,
                    flattening: n.decisions.flattening || null,
                    breadcrumbs: n.decisions.breadcrumbs || null,
                    defaultAction: n.decisions.defaultAction || null,
                    childVisibility: n.decisions.childVisibility || null
                } : null,
                defaultAction: n.defaultAction ? { name: n.defaultAction.name || n.defaultAction.id || "", label: n.defaultAction.label || "" } : null,
                breadcrumbText: n.breadcrumbText || "",
                compactMatch: n.compactMatch ? {
                    matchedTokens: n.compactMatch.matchedTokens || [],
                    consumedTokens: n.compactMatch.consumedTokens || [],
                    missingTokens: n.compactMatch.missingTokens || []
                } : null,
                compactScore: n.compactScore ? {
                    final: n.compactScore.final !== undefined ? n.compactScore.final : null,
                    own: n.compactScore.own !== undefined ? n.compactScore.own : null,
                    parent: n.compactScore.parent !== undefined ? n.compactScore.parent : null,
                    child: n.compactScore.child !== undefined ? n.compactScore.child : null
                } : null,
                reasons: {
                    shown: n.reasons && n.reasons.shown || [{ code: "visible", text: "Node is visible in results" }],
                    placement: n.reasons && n.reasons.placement || [{ code: "placement", text: "Placement: " + (n.placement || "unknown") }],
                    children: n.reasons && n.reasons.children || [],
                    action: n.reasons && n.reasons.action || []
                },
                children: serializeTree(n.children, depth + 1, maxDepth, maxChildren),
                hiddenChildCount: n.hiddenChildCount || 0,
                filteredChildCount: n.filteredChildCount || 0
            };
            out.push(node);
        }
        return out;
    }

    function makeCompactMatch(evidenceTrace) {
        if (!evidenceTrace) return null;
        return {
            matchedTokens: evidenceTrace.matchedTokens || [],
            consumedTokens: evidenceTrace.consumedTokens || [],
            missingTokens: evidenceTrace.missingTokens || []
        };
    }

    function makeCompactScore(scoreTrace) {
        if (!scoreTrace) return null;
        return {
            final: scoreTrace.final !== undefined ? scoreTrace.final : null,
            own: scoreTrace.own !== undefined ? scoreTrace.own : null,
            parent: scoreTrace.parent !== undefined ? scoreTrace.parent : null,
            child: scoreTrace.child !== undefined ? scoreTrace.child : null
        };
    }
}
