import QtQml
import qs.services
import "../" as Launcher

QtObject {
    property string policyId: "candidate-or-visible"

    readonly property var tracer: Logger.scope("policy.candidateOrVisible", { category: "policy" })
    readonly property var prof: Profiler.scope("policy.candidateOrVisible", { category: "policy" })

    function policyApply(childEval, parentEval, ctx, specArgs) {
        var isCandidate = childEval.candidate === true;
        var isVisible = childEval.visible === true;
        tracer.trace("policyApply", function() { return { policyId: policyId, candidate: isCandidate, visible: isVisible, result: isCandidate || isVisible }; });
        return isCandidate || isVisible;
    }

    Component.onCompleted: {
        Launcher.PolicyRegistry.registerChildVisible(policyId, policyApply);
    }
}
