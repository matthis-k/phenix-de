import QtQml
import qs.services
import "../" as Launcher

QtObject {
    property string policyId: "has-own-score"

    readonly property var tracer: Logger.scope("policy.hasOwnScore", { category: "policy" })
    readonly property var prof: Profiler.scope("policy.hasOwnScore", { category: "policy" })

    function policyApply(childEval, parentEval, ctx, specArgs) {
        var score = childEval.ownScore || 0;
        tracer.trace("policyApply", function() { return { policyId: policyId, ownScore: score, result: score > 0 }; });
        return score > 0;
    }

    Component.onCompleted: {
        Launcher.PolicyRegistry.registerChildVisible(policyId, policyApply);
    }
}
