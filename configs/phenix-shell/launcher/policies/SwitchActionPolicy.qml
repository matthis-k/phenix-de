import QtQml
import qs.services
import "../" as Launcher
import "../logic/"

QtObject {
    readonly property var tracer: Logger.scope("policy.switchAction", { category: "policy" })
    readonly property var prof: Profiler.scope("policy.switchAction", { category: "policy" })

    function policyMatch(node, query, ctx, specArgs) {
        if (!node.switchActions || query.isEmpty) {
            tracer.trace("policyMatch", function() { return { nodeId: node?.id, queryEmpty: query.isEmpty, hasSwitches: !!node?.switchActions, resultCount: 0 }; });
            return [];
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

        var out = [];
        for (var ti = 0; ti < query.tokens.length; ti += 1) {
            var token = query.tokens[ti].normalized;
            for (var actionId in aliasMap) {
                if (!node.switchActions[actionId])
                    continue;
                for (var ai = 0; ai < aliasMap[actionId].length; ai += 1) {
                    var alias = aliasMap[actionId][ai];
                    var fs = Evaluate.fuzzyAliasScore(token, alias);
                    var score = token === alias ? 1.0
                        : alias.indexOf(token) === 0 && token.length >= 2 ? 0.78
                        : alias.length > token.length && alias.lastIndexOf(token) === alias.length - token.length ? 0.65
                        : fs;
                    if (score > 0)
                        out.push({ strategy: "switch-action", field: "action", fieldText: alias, nodeId: node.id, originNodeId: node.id, originKind: "self", depth: 0, tokenIndex: ti, tokenIndexes: [ti], coverageCount: 1, exactness: score >= 1 ? "exact" : fs > 0 ? "fuzzy" : "prefix", actionId: actionId, actionRole: "switch-" + actionId, isExecutable: true, kind: score >= 1 ? "action-exact" : fs > 0 ? "action-fuzzy" : "action-prefix", score: score, weight: fs > 0 ? 0.42 : 0.64, effective: score * (fs > 0 ? 0.42 : 0.64), ranges: [], reason: fs > 0 ? "switch action alias fuzzy match" : "switch action alias" });
                }
            }
        }
        tracer.trace("policyMatch.result", function() { return { nodeId: node?.id, evidenceCount: out.length }; });
        return out;
    }

    Component.onCompleted: {
        Launcher.PolicyRegistry.registerEvidence("switch-action", "own", policyMatch);
    }
}
