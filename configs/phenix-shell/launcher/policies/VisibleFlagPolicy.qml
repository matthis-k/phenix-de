import QtQml
import qs.services
import "../" as Launcher

QtObject {
    property string policyId: "visible-flag"

    readonly property var tracer: Logger.scope("policy.visibleFlag", { category: "policy" })
    readonly property var prof: Profiler.scope("policy.visibleFlag", { category: "policy" })

    function policyApply(childEval, parentEval, ctx, specArgs) {
        tracer.trace("policyApply", function() { return { policyId: policyId, visible: childEval.visible, result: childEval.visible === true }; });
        return childEval.visible === true;
    }

    Component.onCompleted: {
        Launcher.PolicyRegistry.registerChildVisible(policyId, policyApply);
    }
}
