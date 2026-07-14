import QtQml
import qs.services
import "../" as Launcher

QtObject {
    property string policyId: "own-score-beats-parent"

    readonly property var tracer: Logger.scope("policy.ownScoreBeatsParent", { category: "policy" })
    readonly property var prof: Profiler.scope("policy.ownScoreBeatsParent", { category: "policy" })

    function policyApply(childEval, parentEval, ctx, specArgs) {
        var childOwn = childEval.ownScore || 0;
        var parentOwn = parentEval.ownScore || 0;
        tracer.trace("policyApply", function() { return { policyId: policyId, childOwnScore: childOwn, parentOwnScore: parentOwn, result: childOwn > parentOwn }; });
        return childOwn > parentOwn;
    }

    Component.onCompleted: {
        Launcher.PolicyRegistry.registerChildVisible(policyId, policyApply);
        Launcher.PolicyRegistry.registerChildBypass(policyId, policyApply);
    }
}
