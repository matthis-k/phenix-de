import QtQml
import qs.services
import "../" as Launcher

QtObject {
    property string policyId: "score-beats-parent"

    readonly property var tracer: Logger.scope("policy.scoreBeatsParent", { category: "policy" })
    readonly property var prof: Profiler.scope("policy.scoreBeatsParent", { category: "policy" })

    function policyApply(childEval, parentEval, ctx, specArgs) {
        var childScore = childEval.score || 0;
        var parentScore = parentEval.score || 0;
        tracer.trace("policyApply", function() { return { policyId: policyId, childScore: childScore, parentScore: parentScore, result: childScore > parentScore }; });
        return childScore > parentScore;
    }

    Component.onCompleted: {
        Launcher.PolicyRegistry.registerChildBypass(policyId, policyApply);
    }
}
