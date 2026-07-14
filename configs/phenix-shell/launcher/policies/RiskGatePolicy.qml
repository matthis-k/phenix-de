import QtQml
import qs.services
import "../" as Launcher
import "../logic/"

QtObject {
    readonly property var tracer: Logger.scope("policy.riskGate", { category: "policy" })
    readonly property var prof: Profiler.scope("policy.riskGate", { category: "policy" })

    function riskGateApply(node, ctx, runtime, specArgs) {
        if (!runtime) return null;
        var mode = runtime.activation || "normal";
        var level = runtime.level || "none";
        tracer.trace("riskGateApply", function() { return { nodeId: node?.id, mode: mode, level: level }; });
        var level = runtime.level || "none";
        var upstreamAllowed = runtime.allowed !== undefined ? runtime.allowed : true;

        var blockLevels = specArgs && specArgs.blockLevels || [];
        if (blockLevels.length > 0 && blockLevels.indexOf(level) >= 0) {
            return {
                decision: { allowed: false, mode: "blocked" },
                reasons: [{ code: "blocked_level", text: "risk-gate: blocked risk level " + level }]
            };
        }

        switch (mode) {
        case "blocked":
            return {
                decision: { allowed: false, mode: "blocked" },
                reasons: [{ code: "blocked", text: "risk-gate: execution blocked by policy" }]
            };
        case "confirm":
            return {
                decision: { allowed: upstreamAllowed === false ? false : undefined, mode: "confirm" },
                reasons: [{ code: "confirm_required", text: "risk-gate: confirmation required" }]
            };
        case "confirm-and-explicit-prefix":
            return {
                decision: { allowed: upstreamAllowed === false ? false : undefined, mode: "confirm-and-explicit-prefix" },
                reasons: [{ code: "confirm_and_prefix_required", text: "risk-gate: confirmation and explicit prefix required" }]
            };
        case "explicit-prefix":
        case "explicit-prefix-only":
            return {
                decision: { allowed: upstreamAllowed === false ? false : undefined, mode: mode },
                reasons: [{ code: "prefix_required", text: "risk-gate: explicit prefix required" }]
            };
        default:
            return {
                decision: { allowed: undefined, mode: "normal" },
                reasons: [{ code: "normal_activation", text: "risk-gate: normal activation" }]
            };
        }
    }

    Component.onCompleted: {
        Launcher.PolicyRegistry.registerRiskGate("risk-gate", riskGateApply);
        Launcher.PolicyRegistry.registerRiskGate("risk-gate-confirm", function(node, ctx, runtime, specArgs) {
            return {
                decision: { allowed: runtime && runtime.allowed === false ? false : undefined, mode: "confirm" },
                reasons: [{ code: "confirm_required", text: "risk-gate: confirm required" }]
            };
        });
        Launcher.PolicyRegistry.registerRiskGate("risk-gate-block", function(node, ctx, runtime, specArgs) {
            return {
                decision: { allowed: false, mode: "blocked" },
                reasons: [{ code: "blocked", text: "risk-gate: blocked" }]
            };
        });
    }
}
