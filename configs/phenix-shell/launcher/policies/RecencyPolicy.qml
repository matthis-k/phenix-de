import QtQml
import qs.services
import "../" as Launcher
import "../logic/"

QtObject {
    readonly property var tracer: Logger.scope("policy.recency", { category: "policy" })
    readonly property var prof: Profiler.scope("policy.recency", { category: "policy" })

    function policyMatch(node, query, ctx, specArgs) {
        const metrics = LauncherUsage.metricsFor(node);
        if (!isFinite(metrics.daysAgo) || metrics.daysAgo >= 9999)
            return [];

        const recency = Evidence.recencyScore(metrics.daysAgo);
        const weight = query.isEmpty ? 0.52 : 0.08;
        const result = [{
            strategy: "recency",
            field: "recency",
            fieldText: String(metrics.daysAgo),
            nodeId: node.id,
            kind: "recency",
            score: recency,
            weight: weight,
            effective: recency * weight,
            ranges: [],
            reason: query.isEmpty ? "recently used" : "last used"
        }];
        tracer.trace("policyMatch", function() {
            return { nodeId: node?.id, lastUsedDaysAgo: metrics.daysAgo, recencyScore: recency, weight: weight };
        });
        return result;
    }

    Component.onCompleted: {
        Launcher.PolicyRegistry.registerEvidence("recency", "own", policyMatch);
    }
}
