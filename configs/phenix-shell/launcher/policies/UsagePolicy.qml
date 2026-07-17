import QtQml
import qs.services
import "../" as Launcher
import "../logic/"

QtObject {
    readonly property var tracer: Logger.scope("policy.usage", { category: "policy" })
    readonly property var prof: Profiler.scope("policy.usage", { category: "policy" })

    function policyMatch(node, query, ctx, specArgs) {
        const metrics = LauncherUsage.metricsFor(node);
        if (!metrics.count || metrics.count <= 0)
            return [];

        const usage = Evidence.frequencyScore(metrics.count);
        const weight = query.isEmpty ? 0.72 : 0.12;
        const result = [{
            strategy: "usage",
            field: "usage",
            fieldText: String(metrics.count),
            nodeId: node.id,
            kind: "frequency",
            score: usage,
            weight: weight,
            effective: usage * weight,
            ranges: [],
            reason: query.isEmpty ? "frequently used" : "usage frequency"
        }];
        tracer.trace("policyMatch", function() {
            return { nodeId: node?.id, usageCount: metrics.count, score: usage, weight: weight };
        });
        return result;
    }

    Component.onCompleted: {
        Launcher.PolicyRegistry.registerEvidence("usage", "own", policyMatch);
    }
}
