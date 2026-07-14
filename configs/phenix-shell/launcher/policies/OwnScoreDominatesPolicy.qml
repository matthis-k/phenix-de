import QtQml
import qs.services
import "../" as Launcher

QtObject {
    property string policyId
    property real margin: 0.03

    readonly property var tracer: Logger.scope("policy.ownScoreDominates", { category: "policy" })
    readonly property var prof: Profiler.scope("policy.ownScoreDominates", { category: "policy" })

    function policyApply(childEval, parentEval, ctx, specArgs) {
        var effectiveMargin = specArgs && specArgs.margin !== undefined
            ? Number(specArgs.margin)
            : margin;
        var childOwn = childEval.ownScore || 0;
        var parentOwn = parentEval.ownScore || 0;
        tracer.trace("policyApply", function() { return { policyId: policyId, childOwnScore: childOwn, parentOwnScore: parentOwn, margin: effectiveMargin, result: childOwn >= parentOwn + effectiveMargin }; });
        return childOwn >= parentOwn + effectiveMargin;
    }

    Component.onCompleted: {
        Launcher.PolicyRegistry.registerChildBypass(policyId, policyApply);
    }
}
