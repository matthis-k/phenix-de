import QtQml
import qs.services
import "../" as Launcher
import "../logic/"

QtObject {
    readonly property var tracer: Logger.scope("policy.tokenClaim", { category: "policy" })
    readonly property var prof: Profiler.scope("policy.tokenClaim", { category: "policy" })

    function policyMatch(node, query, ctx, specArgs) {
        if (!node.behavior || !node.behavior.tokenPolicy || !node.behavior.tokenPolicy.tokens || query.isEmpty)
            return [];
        var claims = Evidence.claimMatchingTokens(query, node.behavior.tokenPolicy.tokens, node.behavior.tokenPolicy);
        var out = [];
        for (var ci = 0; ci < claims.length; ci += 1)
            out.push(Evidence.tokenClaimToEvidence(node, query, claims[ci]));
        tracer.trace("policyMatch", function() { return { nodeId: node?.id, claimCount: claims.length, resultCount: out.length }; });
        return out;
    }

    Component.onCompleted: {
        Launcher.PolicyRegistry.registerEvidence("token-claim", "own", policyMatch);
    }
}
