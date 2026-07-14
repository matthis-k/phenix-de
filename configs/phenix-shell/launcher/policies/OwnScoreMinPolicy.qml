import QtQml
import qs.services
import "../" as Launcher

QtObject {
    property string policyId
    property real threshold: 0.25

    readonly property var tracer: Logger.scope("policy.ownScoreMin", { category: "policy" })
    readonly property var prof: Profiler.scope("policy.ownScoreMin", { category: "policy" })

    function policyApply(childEval, parentEval, ctx, specArgs) {
        var effectiveThreshold = specArgs && specArgs.threshold !== undefined
            ? Number(specArgs.threshold)
            : threshold;
        var score = childEval.ownScore || 0;
        tracer.trace("policyApply", function() { return { policyId: policyId, ownScore: score, threshold: effectiveThreshold, result: score >= effectiveThreshold }; });
        return score >= effectiveThreshold;
    }

    Component.onCompleted: {
        Launcher.PolicyRegistry.registerChildVisible(policyId, policyApply);
    }
}
