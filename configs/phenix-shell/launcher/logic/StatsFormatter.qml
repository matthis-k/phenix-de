import QtQml
import qs.services

BaseFormatter {
    readonly property var tracer: Logger.scope("launcher.formatter.stats", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.formatter.stats", { category: "launcher" })
    formatterName: "stats"

    function serialize(evaluation, request) {
        tracer.trace("serialize", function() { return { hasEvaluation: !!evaluation, includeBackends: request?.includeBackends }; });
        if (!evaluation) return { error: { code: "no_evaluation", message: "No evaluation available" } };

        var options = request || {};
        var s = evaluation.stats || {};
        var beTrace = evaluation.backendTrace || [];

        var result = {
            total: {
                durationMs: s.durationMs || 0,
                backendCount: s.backendCount || beTrace.length,
                participatingBackendCount: s.participatingBackendCount || beTrace.filter(function(b) { return b.participated; }).length,
                candidateCount: s.candidateCount || 0,
                evaluatedNodeCount: s.evaluatedNodeCount || 0,
                finalVisibleRowCount: s.finalVisibleRowCount || 0,
                finalVisibleTreeNodeCount: s.finalVisibleTreeNodeCount || 0,
                evaluatedVisibleCandidateCount: s.evaluatedVisibleCandidateCount || 0,
                hiddenCandidateCount: s.hiddenCandidateCount || 0,
                prunedNodeCount: s.prunedNodeCount || 0
            }
        };

        if (options.includeBackends !== false) {
            result.backends = beTrace.map(function(bt) {
                return {
                    backend: bt.backend,
                    participated: bt.participated,
                    durationMs: bt.durationMs || 0,
                    candidateCount: bt.candidateCount || 0,
                    visibleCount: bt.visibleCount || 0,
                    reasons: bt.reasons || []
                };
            });
        }

        if (options.includeStages !== false && evaluation._stages) {
            result.stages = evaluation._stages.map(function(st) {
                return {
                    name: st.name || "",
                    durationMs: st.durationMs || 0,
                    inputCount: st.inputCount,
                    outputCount: st.outputCount,
                    reasons: st.reasons || []
                };
            });
        }

        if (options.includeValidation !== false) {
            var v = evaluation.validation || { ok: true, errors: [], warnings: [] };
            result.validation = {
                ok: v.ok,
                errors: (v.errors || []).map(function(e) {
                    return { code: e.code || "", message: e.message || "", nodeId: e.nodeId || "", severity: e.severity || "error" };
                }),
                warnings: (v.warnings || []).map(function(w) {
                    return { code: w.code || "", message: w.message || "", nodeId: w.nodeId || "", severity: w.severity || "warning" };
                })
            };
        }

        return result;
    }
}
