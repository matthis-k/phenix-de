import QtQml
import qs.services
import "../" as Launcher

QtObject {
    property string policyId
    property real threshold: 0.25

    readonly property var tracer: Logger.scope("policy.aboveMinScore", { category: "policy" })
    readonly property var prof: Profiler.scope("policy.aboveMinScore", { category: "policy" })

    function policyApply(childEval, parentEval, ctx, specArgs) {
        var effectiveThreshold = specArgs && specArgs.threshold !== undefined
            ? Number(specArgs.threshold)
            : threshold;
        var score = childEval.score || 0;
        tracer.trace("policyApply", function() { return { policyId: policyId, score: score, threshold: effectiveThreshold, result: score >= effectiveThreshold }; });
        return score >= effectiveThreshold;
    }

    Component.onCompleted: {
        Launcher.PolicyRegistry.registerChildVisible(policyId, policyApply);
    }
}
