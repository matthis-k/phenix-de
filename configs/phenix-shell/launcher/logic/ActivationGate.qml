pragma Singleton
import QtQml
import Quickshell
import qs.services
import "PolicyChain.qml"
import "DecisionDecider.qml"
import "PolicySpec.qml"
import "CompositeSearchPolicyRegistry.js" as JsRegistry

Singleton {
    readonly property var prof: Profiler.scope("launcher.activationGate", { category: "launcher" })
    function riskLevelForNode(node) {
        if (!node) return "none";
        if (node.risk && node.risk.level) return node.risk.level;
        if (node.dangerous) return "state-change";
        return "none";
    }

    function activationModeForNode(node) {
        if (!node) return "normal";
        if (node.risk && node.risk.activation) return node.risk.activation;
        if (node.dangerous) {
            var label = String(node.label || "").toLowerCase();
            if (label.indexOf("logout") >= 0 || label.indexOf("shutdown") >= 0 || label.indexOf("reboot") >= 0 || label.indexOf("hibernate") >= 0)
                return "confirm-and-explicit-prefix";
            return "confirm";
        }
        return "normal";
    }

    function _hasExplicitPrefix(queryText, ctx) {
        if (ctx) {
            if (ctx.directive && ctx.directive.active)
                return ctx.directive.prefix === ":";
            if (ctx.route && ctx.route.combine === "exclusive") {
                var eps = ctx.route.endpoints || [];
                return eps.length > 0 && eps[0].prefix === ":";
            }
            if (ctx.lastDirective && ctx.lastDirective.active)
                return ctx.lastDirective.prefix === ":";
        }
        return !!(queryText && queryText.length > 1 && queryText.indexOf(":") >= 0);
    }

    function _resolveActivation(node, ctx, queryText, confirmationSatisfied) {
        if (!node) return { allowed: false, mode: "normal", riskLevel: "none", reason: "no node", requiresConfirm: false, requiresExplicitPrefix: false };

        var mode = activationModeForNode(node);
        var level = riskLevelForNode(node);
        var conf = !!confirmationSatisfied;
        var hasPrefix = _hasExplicitPrefix(queryText, ctx);
        var allowed = true;
        var reason = "normal activation";

        switch (mode) {
        case "blocked":
            allowed = false;
            reason = "activation blocked by risk policy";
            break;
        case "confirm":
            allowed = conf;
            reason = conf ? "activation via confirmation" : "activation blocked: confirmation required";
            break;
        case "explicit-prefix":
        case "explicit-prefix-only":
            allowed = hasPrefix;
            reason = hasPrefix ? "activation via explicit prefix" : "activation blocked: explicit prefix required";
            break;
        case "confirm-and-explicit-prefix":
            allowed = conf && hasPrefix;
            reason = allowed
                ? "activation via explicit prefix + confirmation"
                : conf
                    ? "activation blocked: explicit prefix required"
                    : hasPrefix
                        ? "activation blocked: confirmation required"
                        : "activation blocked: explicit prefix required";
            break;
        default:
            allowed = true;
            reason = "normal activation";
        }

        var runtime = {
            activation: mode,
            level: level,
            confirmation: conf,
            allowed: allowed,
            reason: reason,
            hasExplicitPrefix: hasPrefix,
            queryText: queryText || ""
        };

        var profile = node && node.evaluationProfile && node.evaluationProfile.profile || {};
        var riskGateNames = profile.riskGate || ["risk-gate"];

        var riskVotes = [];
        PolicyChain.run(riskGateNames, function(name, spec) {
            var policy = PolicyChain.lookupPolicy(JsRegistry.riskGate, spec);
            if (!policy) return null;
            var vote = policy.apply(node, ctx, runtime, spec && spec.args);
            if (vote) riskVotes.push(vote);
            return vote;
        }, "accumulate");

        var gateReduced = DecisionDecider.reduce("riskGate", riskVotes, { mode: "first-wins", tieBreak: "first" });
        var gateValue = gateReduced && gateReduced.decision;
        if (gateValue && gateValue.allowed !== undefined) {
            allowed = gateValue.allowed;
        }
        if (gateValue && gateValue.reason) {
            reason = gateValue.reason;
        }

        return {
            allowed: allowed,
            mode: mode,
            riskLevel: level,
            reason: reason,
            policyReason: gateValue && gateValue.reason ? gateValue.reason : "",
            requiresConfirm: mode === "confirm" || mode === "confirm-and-explicit-prefix",
            requiresExplicitPrefix: mode === "explicit-prefix-only" || mode === "confirm-and-explicit-prefix" || mode === "explicit-prefix"
        };
    }
    readonly property var resolveActivation: prof.fn("resolveActivation", _resolveActivation)

    function guardActivation(node, action, ctx, queryText, confirmationSatisfied) {
        var resolved = resolveActivation(node, ctx, queryText, confirmationSatisfied);
        if (!resolved.allowed) {
            console.warn("ActivationGate: activation blocked for", node.label || node.id, "reason:", resolved.reason);
            return false;
        }
        return true;
    }

    function canActivate(node, action, ctx, queryText, confirmationSatisfied) {
        return guardActivation(node, action, ctx, queryText, confirmationSatisfied);
    }
}
