import QtQml
import qs.services
import "../" as Launcher
import "../logic/"

QtObject {
    property string policyId: "expand-on-trailing-space"

    readonly property var tracer: Logger.scope("policy.expandOnTrailingSpace", { category: "policy" })
    readonly property var prof: Profiler.scope("policy.expandOnTrailingSpace", { category: "policy" })

    function policyApply(childEval, parentEval, ctx, specArgs) {
        if (ctx.query.lastTokenEmpty) {
            tracer.trace("policyApply", function() { return { policyId: policyId, reason: "last token empty", result: true }; });
            return true;
        }

        var parentCov = Evidence.coveredTokenIndexes(parentEval.evidence || [], ctx.query);
        var childCov = Evidence.coveredTokenIndexes(childEval.evidence || [], ctx.query);
        if (Object.keys(parentCov).length === 0) {
            tracer.trace("policyApply", function() { return { policyId: policyId, reason: "no parent coverage", result: false }; });
            return false;
        }

        for (var key in childCov) {
            if (key in parentCov) continue;
            tracer.trace("policyApply", function() { return { policyId: policyId, reason: "child covers uncovered token", tokenIndex: parseInt(key), result: true }; });
            return true;
        }
        tracer.trace("policyApply", function() { return { policyId: policyId, reason: "no new coverage", result: false }; });
        return false;
    }

    Component.onCompleted: {
        Launcher.PolicyRegistry.registerChildVisible(policyId, policyApply);
    }
}
