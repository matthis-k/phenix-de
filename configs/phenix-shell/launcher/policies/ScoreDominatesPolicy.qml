import QtQml
import qs.services
import "../" as Launcher

QtObject {
    property string policyId
    property real margin: 0.03

    readonly property var tracer: Logger.scope("policy.scoreDominates", { category: "policy" })
    readonly property var prof: Profiler.scope("policy.scoreDominates", { category: "policy" })

    function policyApply(childEval, parentEval, ctx, specArgs) {
        var effectiveMargin = specArgs && specArgs.margin !== undefined
            ? Number(specArgs.margin)
            : margin;
        var childScore = childEval.score || 0;
        var parentScore = parentEval.score || 0;
        tracer.trace("policyApply", function() { return { policyId: policyId, childScore: childScore, parentScore: parentScore, margin: effectiveMargin, result: childScore >= parentScore + effectiveMargin }; });
        return childScore >= parentScore + effectiveMargin;
    }

    Component.onCompleted: {
        Launcher.PolicyRegistry.registerChildBypass(policyId, policyApply);
    }
}
