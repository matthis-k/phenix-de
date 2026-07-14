import QtQml
import qs.services
import "../" as Launcher
import "../logic/"

QtObject {
    readonly property var tracer: Logger.scope("policy.semantic", { category: "policy" })
    readonly property var prof: Profiler.scope("policy.semantic", { category: "policy" })

    function policyMatch(node, query, ctx, specArgs) {
        var result = Evidence.matchSemantic(node, query);
        tracer.trace("policyMatch", function() { return { nodeId: node?.id, resultCount: result ? result.length : 0 }; });
        return result;
    }

    Component.onCompleted: {
        Launcher.PolicyRegistry.registerEvidence("semantic", "own", policyMatch);
    }
}
