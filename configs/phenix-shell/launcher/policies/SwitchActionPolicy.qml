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

        for (var actionId in aliasMap) {
            var action = node.switchActions[actionId];
            if (!action)
                continue;
            aliasMap[actionId] = uniqueAliases(aliasMap[actionId].concat(actionAliases(action)));
        }

        var out = [];
        for (var ti = 0; ti < query.tokens.length; ti += 1) {
            var token = query.tokens[ti].normalized;
            for (var role in aliasMap) {
                if (!node.switchActions[role])
                    continue;
                for (var ai = 0; ai < aliasMap[role].length; ai += 1) {
                    var alias = aliasMap[role][ai];
                    var fs = Evaluate.fuzzyAliasScore(token, alias);
                    var score = token === alias ? 1.0
                        : alias.indexOf(token) === 0 && token.length >= 2 ? 0.78
                        : alias.length > token.length && alias.lastIndexOf(token) === alias.length - token.length ? 0.65
                        : fs;
                    if (score > 0)
                        out.push({ strategy: "switch-action", field: "action", fieldText: alias, nodeId: node.id, originNodeId: node.id, originKind: "self", depth: 0, tokenIndex: ti, tokenIndexes: [ti], coverageCount: 1, exactness: score >= 1 ? "exact" : fs > 0 ? "fuzzy" : "prefix", actionId: role, actionRole: "switch-" + role, isExecutable: true, kind: score >= 1 ? "action-exact" : fs > 0 ? "action-fuzzy" : "action-prefix", score: score, weight: fs > 0 ? 0.42 : 0.64, effective: score * (fs > 0 ? 0.42 : 0.64), ranges: [], reason: fs > 0 ? "switch action alias fuzzy match" : "switch action alias" });
                }
            }
        }
        tracer.trace("policyMatch.result", function() { return { nodeId: node?.id, evidenceCount: out.length }; });
        return out;
    }

    function actionAliases(action) {
        var values = [];
        values = values.concat(action && action.aliases || []);
        if (action) {
            values.push(action.id || "");
            values.push(action.label || action.title || "");
            if (action.payload) {
                values.push(action.payload.op || "");
                values.push(action.payload.actionId || "");
            }
            var presentation = action.presentation || action.payload && action.payload.presentation;
            if (presentation) {
                values.push(presentation.title || "");
                values.push(presentation.subtitle || "");
            }
        }

        var out = [];
        for (var i = 0; i < values.length; i += 1) {
            var normalized = Tokenize.normalizeText(values[i]);
            if (!normalized)
                continue;
            out.push(normalized);
            out = out.concat(normalized.split(/\s+/));
        }
        return out;
    }

    function uniqueAliases(values) {
        var seen = {};
        return (values || []).map(Tokenize.normalizeText).filter(function(value) {
            if (!value || seen[value])
                return false;
            seen[value] = true;
            return true;
        });
    }

    Component.onCompleted: {
        Launcher.PolicyRegistry.registerEvidence("switch-action", "own", policyMatch);
    }
}
