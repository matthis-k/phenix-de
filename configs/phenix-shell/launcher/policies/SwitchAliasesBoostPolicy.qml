import QtQml
import qs.services
import "../" as Launcher
import "../logic/"

QtObject {
    readonly property var tracer: Logger.scope("policy.switchAliasesBoost", { category: "policy" })
    readonly property var prof: Profiler.scope("policy.switchAliasesBoost", { category: "policy" })

    function policyApply(node, query, ctx, evaluatedChildren, scores) {
        if (!node.switchActions || !scores || !scores.ownScore || scores.ownScore <= 0) {
            tracer.trace("policyApply.skip", function() { return { nodeId: node?.id, reason: "no switch actions or no own score" }; });
            return 0;
        }

        var aliasMap = {
            on: ["on", "enable", "connect"],
            off: ["off", "disable", "disconnect"],
            toggle: ["toggle", "switch"]
        };
        var acronym = String(node.label || "").replace(/[^A-Za-z0-9]/g, "").charAt(0).toLowerCase();
        if (acronym) {
            aliasMap.on.push(acronym + "o");
            aliasMap.off.push(acronym + "f");
            aliasMap.toggle.push(acronym + "t");
        }

        var bestTokenScore = 0;
        for (var ti = 0; ti < query.tokens.length; ti += 1) {
            var token = query.tokens[ti].normalized;
            for (var actionId in aliasMap) {
                for (var ai = 0; ai < aliasMap[actionId].length; ai += 1) {
                    var alias = aliasMap[actionId][ai];
                    var score = token === alias ? 1.0
                        : alias.indexOf(token) === 0 && token.length >= 2 ? 0.78
                        : alias.length > token.length && alias.lastIndexOf(token) === alias.length - token.length ? 0.65
                        : Evaluate.fuzzyAliasScore(token, alias);
                    bestTokenScore = Math.max(bestTokenScore, score);
                }
            }
        }
        tracer.trace("policyApply.result", function() { return { nodeId: node?.id, bestTokenScore: bestTokenScore }; });
        return bestTokenScore;
    }

    Component.onCompleted: {
        Launcher.PolicyRegistry.registerBoost("switch-aliases", policyApply);
    }
}
