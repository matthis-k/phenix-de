import QtQml
import qs.services
import "../" as Launcher
import "../logic/"

QtObject {
    readonly property var tracer: Logger.scope("policy.recency", { category: "policy" })
    readonly property var prof: Profiler.scope("policy.recency", { category: "policy" })

    function policyMatch(node, query, ctx, specArgs) {
        if (query.isEmpty || !isFinite(node.lastUsedDaysAgo))
            return [];
        var rec = Evidence.recencyScore(node.lastUsedDaysAgo);
        var result = [{ strategy: "recency", field: "recency", fieldText: String(node.lastUsedDaysAgo), nodeId: node.id, kind: "recency", score: rec, weight: 0.08, effective: rec * 0.08, ranges: [], reason: "last used" }];
        tracer.trace("policyMatch", function() { return { nodeId: node?.id, lastUsedDaysAgo: node.lastUsedDaysAgo, recencyScore: rec }; });
        return result;
    }

    Component.onCompleted: {
        Launcher.PolicyRegistry.registerEvidence("recency", "own", policyMatch);
    }
}
