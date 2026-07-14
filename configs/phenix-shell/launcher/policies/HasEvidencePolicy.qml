import QtQml
import qs.services
import "../" as Launcher

QtObject {
    property string policyId: "has-evidence"

    readonly property var tracer: Logger.scope("policy.hasEvidence", { category: "policy" })
    readonly property var prof: Profiler.scope("policy.hasEvidence", { category: "policy" })

    function policyApply(childEval, parentEval, ctx, specArgs) {
        var ownLen = (childEval.ownEvidence || []).length;
        var inheritedLen = (childEval.inheritedEvidence || []).length;
        tracer.trace("policyApply", function() { return { policyId: policyId, ownEvidenceCount: ownLen, inheritedEvidenceCount: inheritedLen, result: ownLen > 0 || inheritedLen > 0 }; });
        return ownLen > 0 || inheritedLen > 0;
    }

    Component.onCompleted: {
        Launcher.PolicyRegistry.registerChildVisible(policyId, policyApply);
    }
}
