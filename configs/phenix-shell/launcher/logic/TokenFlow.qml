pragma Singleton
import QtQml
import Quickshell
import qs.services
import "Tokenize.qml"
import "Evidence.qml"
import "PolicyChain.qml"
import "CompositeSearchPolicyRegistry.js" as JsRegistry

Singleton {
    readonly property var prof: Profiler.scope("launcher.tokenFlow", { category: "launcher" })
    readonly property var tracer: Logger.scope("launcher.tokenFlow", { category: "launcher" })

    function _evaluate(node, query, ctx) {
        tracer.trace("evaluate", function() { return { nodeId: node.id, tokenCount: (query.tokens || []).length }; });
        var profile = (node.evaluationProfile && node.evaluationProfile.profile) || {};
        var flowNames = profile.tokenFlow || ["pass-all"];
        return PolicyChain.run(flowNames, function(name, spec) {
            var policy = PolicyChain.lookupPolicy(JsRegistry.tokenFlow, spec);
            if (!policy) return null;
            return policy.apply(node, query, ctx, spec && spec.args);
        }, "first-wins");
    }

    readonly property var evaluate: prof.fn("evaluate", _evaluate)

    function passAll(node, query, ctx, args) {
        return {
            consumed: [],
            passed: (query.tokens || []).slice(),
            inherited: [],
            reason: "pass-all: all tokens passed to children unchanged"
        };
    }

    function consumeOwnPassRest(node, query, ctx, args) {
        tracer.trace("consumeOwnPassRest", function() { return { nodeId: node.id, tokenCount: (query.tokens || []).length }; });
        var fields = (args && args.fields) || ["label", "alias", "keyword"];
        var inheritAsContext = args && args.inheritConsumedAsContext;
        var consumed = [];
        var consumedIds = {};
        var inheritConsumed = [];

        for (var ti = 0; ti < (query.tokens || []).length; ti += 1) {
            var token = query.tokens[ti];
            var matched = false;
            for (var fi = 0; fi < fields.length; fi += 1) {
                var fieldValues = nodeFieldValues(node, fields[fi]);
                for (var vi = 0; vi < fieldValues.length; vi += 1) {
                    if (Tokenize.normalizeText(fieldValues[vi]).indexOf(token.normalized) === 0 ||
                        Tokenize.normalizeText(fieldValues[vi]) === token.normalized) {
                        consumed.push({
                            tokenId: "tok_" + ti,
                            tokenText: token.raw,
                            field: fields[fi],
                            strength: token.normalized === Tokenize.normalizeText(fieldValues[vi]) ? 1.0 : 0.8,
                            mode: "hard",
                            reason: "token matches " + fields[fi]
                        });
                        consumedIds[ti] = true;
                        if (inheritAsContext) {
                            inheritConsumed.push({
                                tokenId: "tok_" + ti,
                                tokenText: token.raw,
                                field: fields[fi],
                                strength: 0.5,
                                mode: "context",
                                reason: "inherited as context from consumed " + fields[fi]
                            });
                        }
                        matched = true;
                        break;
                    }
                }
                if (matched) break;
            }
        }

        var passed = [];
        for (var pi = 0; pi < (query.tokens || []).length; pi += 1) {
            if (!consumedIds[pi])
                passed.push(query.tokens[pi]);
        }

        return {
            consumed: consumed,
            passed: passed,
            inherited: inheritConsumed,
            reason: "consume-own-pass-rest: consumed " + consumed.length + " tokens, passed " + passed.length
        };
    }

    function claimContextPassAll(node, query, ctx, args) {
        tracer.trace("claimContextPassAll", function() { return { nodeId: node.id }; });
        var fields = (args && args.fields) || ["label", "alias", "keyword"];
        var claims = [];

        for (var ti = 0; ti < (query.tokens || []).length; ti += 1) {
            var token = query.tokens[ti];
            var matched = false;
            for (var fi = 0; fi < fields.length; fi += 1) {
                var values = nodeFieldValues(node, fields[fi]);
                for (var vi = 0; vi < values.length; vi += 1) {
                    if (Tokenize.normalizeText(values[vi]).indexOf(token.normalized) === 0) {
                        claims.push({
                            tokenId: "tok_" + ti,
                            tokenText: token.raw,
                            field: fields[fi],
                            strength: 0.4,
                            mode: "context",
                            reason: "context claim from " + fields[fi]
                        });
                        matched = true;
                        break;
                    }
                }
                if (matched) break;
            }
        }

        return {
            consumed: claims,
            passed: (query.tokens || []).slice(),
            inherited: claims,
            reason: "claim-context-pass-all: " + claims.length + " context claims, all tokens passed"
        };
    }

    function consumeNamespacePassRest(node, query, ctx, args) {
        tracer.trace("consumeNamespacePassRest", function() { return { nodeId: node.id }; });
        var fields = (args && args.fields) || ["label", "alias"];
        var sameLevelFirst = args && args.sameLevelFirst;

        var consumed = [];
        var consumedIds = {};

        for (var ti = 0; ti < (query.tokens || []).length; ti += 1) {
            var token = query.tokens[ti];
            for (var fi = 0; fi < fields.length; fi += 1) {
                var values = nodeFieldValues(node, fields[fi]);
                var matched = false;
                for (var vi = 0; vi < values.length; vi += 1) {
                    var norm = Tokenize.normalizeText(values[vi]);
                    if (norm === token.normalized || norm.indexOf(token.normalized) === 0) {
                        consumed.push({
                            tokenId: "tok_" + ti,
                            tokenText: token.raw,
                            field: fields[fi],
                            strength: norm === token.normalized ? 1.0 : 0.75,
                            mode: "hard",
                            reason: "namespace token matched " + fields[fi]
                        });
                        consumedIds[ti] = true;
                        matched = true;
                        break;
                    }
                }
                if (matched) break;
            }
        }

        var passed = [];
        for (var pi = 0; pi < (query.tokens || []).length; pi += 1) {
            if (!consumedIds[pi])
                passed.push(query.tokens[pi]);
        }

        return {
            consumed: consumed,
            passed: passed,
            inherited: [],
            reason: "consume-namespace-pass-rest: consumed " + consumed.length + " namespace tokens"
        };
    }

    function consumeActionToken(node, query, ctx, args) {
        tracer.trace("consumeActionToken", function() { return { nodeId: node.id, aliasCount: ((args && args.aliases) || []).length }; });
        var aliases = (args && args.aliases) || [];
        var consumed = [];
        var consumedIds = {};
        var normAliases = aliases.map(Tokenize.normalizeText);

        for (var ti = 0; ti < (query.tokens || []).length; ti += 1) {
            var token = query.tokens[ti];
            if (normAliases.indexOf(token.normalized) >= 0) {
                consumed.push({
                    tokenId: "tok_" + ti,
                    tokenText: token.raw,
                    field: "action",
                    strength: 1.0,
                    mode: "hard",
                    reason: "explicit action alias match"
                });
                consumedIds[ti] = true;
            }
        }

        var passed = [];
        for (var pi = 0; pi < (query.tokens || []).length; pi += 1) {
            if (!consumedIds[pi])
                passed.push(query.tokens[pi]);
        }

        return {
            consumed: consumed,
            passed: passed,
            inherited: [],
            reason: "consume-action-token: consumed " + consumed.length + " action tokens"
        };
    }

    function consumeSwitchPassRest(node, query, ctx, args) {
        tracer.trace("consumeSwitchPassRest", function() { return { nodeId: node.id }; });
        var consumed = [];
        var consumedIds = {};
        var serviceFields = (args && args.fields) || ["label", "alias"];
        var actionAliases = ["on", "off", "toggle", "enable", "disable", "start", "stop"];

        for (var ti = 0; ti < (query.tokens || []).length; ti += 1) {
            var token = query.tokens[ti];
            var matched = false;

            for (var fi = 0; fi < serviceFields.length; fi += 1) {
                var values = nodeFieldValues(node, serviceFields[fi]);
                for (var vi = 0; vi < values.length; vi += 1) {
                    var norm = Tokenize.normalizeText(values[vi]);
                    if (norm === token.normalized || norm.indexOf(token.normalized) === 0) {
                        consumed.push({ tokenId: "tok_" + ti, tokenText: token.raw, field: serviceFields[fi], strength: norm === token.normalized ? 1.0 : 0.75, mode: "hard", reason: "switch service token matched " + serviceFields[fi] });
                        consumedIds[ti] = true;
                        matched = true;
                        break;
                    }
                }
                if (matched) break;
            }

            if (!matched && actionAliases.indexOf(token.normalized) >= 0) {
                consumed.push({ tokenId: "tok_" + ti, tokenText: token.raw, field: "action", strength: 1.0, mode: "hard", reason: "switch action token matched" });
                consumedIds[ti] = true;
            }
        }

        var passed = [];
        for (var pi = 0; pi < (query.tokens || []).length; pi += 1) {
            if (!consumedIds[pi])
                passed.push(query.tokens[pi]);
        }

        return {
            consumed: consumed,
            passed: passed,
            inherited: [],
            reason: "consume-switch-pass-rest: consumed " + consumed.length + " switch tokens"
        };
    }

    function consumePathSegment(node, query, ctx, args) {
        tracer.trace("consumePathSegment", function() { return { nodeId: node.id }; });
        var sameLevelFirst = args && args.sameLevelFirst;
        var recurseWhenNoLocalMatch = args && args.recurseWhenNoLocalMatch;

        var consumed = [];
        var consumedIds = {};

        if ((query.tokens || []).length > 0) {
            var firstToken = query.tokens[0];
            var pathValues = nodeFieldValues(node, "path").concat(nodeFieldValues(node, "label"));
            for (var vi = 0; vi < pathValues.length; vi += 1) {
                var norm = Tokenize.normalizeText(pathValues[vi]);
                if (norm === firstToken.normalized || norm.indexOf(firstToken.normalized) === 0) {
                    consumed.push({
                        tokenId: "tok_0",
                        tokenText: firstToken.raw,
                        field: "path",
                        strength: norm === firstToken.normalized ? 1.0 : 0.7,
                        mode: "hard",
                        reason: "path segment consumed by parent"
                    });
                    consumedIds[0] = true;
                    break;
                }
            }
        }

        var passed = [];
        for (var pi = 0; pi < (query.tokens || []).length; pi += 1) {
            if (!consumedIds[pi])
                passed.push(query.tokens[pi]);
        }

        return {
            consumed: consumed,
            passed: passed,
            inherited: [],
            reason: "consume-path-segment: consumed " + consumed.length + " path tokens"
        };
    }

    function buildChildQuery(node, tokenFlowResult, originalQuery) {
        tracer.trace("buildChildQuery", function() { return { nodeId: node.id, passedCount: (tokenFlowResult.passed || []).length, inheritedCount: (tokenFlowResult.inherited || []).length }; });
        var passedTokens = tokenFlowResult.passed || [];
        var inherited = tokenFlowResult.inherited || [];
        var inheritedText = inherited.map(function(i) { return i.tokenText; }).join(" ");
        var isInherited = inherited.length > 0;

        return {
            raw: originalQuery.raw,
            tokens: passedTokens,
            isEmpty: passedTokens.length === 0,
            lastTokenEmpty: originalQuery.lastTokenEmpty,
            inherited: inherited,
            inheritedContext: isInherited,
            inheritedText: inheritedText,
            fullQuery: originalQuery,
            inheritedSource: isInherited ? inherited : null,
            tokenIndexOrigin: "tokenFlow"
        };
    }

    function nodeFieldValues(node, field) {
        if (!node) return [];
        switch (field) {
        case "label": return [node.label || ""];
        case "alias": return node.aliases || [];
        case "keyword": return node.keywords || [];
        case "path": return [node.path || "", node.subtitle || ""];
        case "action": return node.switchActions ? Object.keys(node.switchActions).map(function(k) { return k; }).concat(["on", "off", "toggle"]) : [];
        default: return [];
        }
    }
}
