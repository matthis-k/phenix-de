import QtQml
import qs.services
import "../" as Launcher
import "../logic/"

QtObject {
    readonly property var tracer: Logger.scope("policy.usage", { category: "policy" })
    readonly property var prof: Profiler.scope("policy.usage", { category: "policy" })

    function policyMatch(node, query, ctx, specArgs) {
        if (query.isEmpty || !node.usageCount || node.usageCount <= 0)
            return [];
        var usage = Evidence.frequencyScore(node.usageCount);
        var result = [{ strategy: "usage", field: "usage", fieldText: String(node.usageCount), nodeId: node.id, kind: "frequency", score: usage, weight: 0.12, effective: usage * 0.12, ranges: [], reason: "usage frequency" }];
        tracer.trace("policyMatch", function() { return { nodeId: node?.id, usageCount: node.usageCount, score: usage, effective: usage * 0.12 }; });
        return result;
    }

    Component.onCompleted: {
        Launcher.PolicyRegistry.registerEvidence("usage", "own", policyMatch);
    }
}
