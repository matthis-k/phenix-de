pragma Singleton
import QtQml
import Quickshell
import qs.services
import "Tokenize.qml"
import "Evidence.qml"
import "ActivationGate.qml"

Singleton {
    readonly property var tracer: Logger.scope("launcher.resultSemantics", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.resultSemantics", { category: "launcher" })
    function build(ev, decision, placement, ctx) {
        tracer.trace("build", function() { return { nodeId: ev?.node?.id, placement: placement }; });
        var node = ev.node;
        if (!node) return empty();

        return {
            participation: buildParticipation(ev, ctx),
            tokenFlow: buildTokenFlow(ev),
            scoring: buildScoring(ev, ctx),
            takeover: decision && decision.takeover ? buildTakeover(decision.takeover, ev, ctx) : null,
            representation: buildRepresentation(decision, placement),
            action: buildAction(ev, decision, ctx),
            activation: buildActivation(node, ctx)
        };
    }

    function empty() {
        return {
            participation: null,
            tokenFlow: null,
            scoring: null,
            takeover: null,
            representation: null,
            action: null,
            activation: null
        };
    }

    function buildParticipation(ev, ctx) {
        var node = ev && ev.node;
        if (!node) return null;

        var mode = "shared";
        if (ctx && ctx.route && ctx.route.combine === "exclusive")
            mode = "exclusive";
        else if (ctx && ctx.directive && ctx.directive.active)
            mode = "fallback";

        return {
            backendId: node.backendId || "",
            route: (ctx && ctx.route && ctx.route.pattern) || (ctx && ctx.directive && ctx.directive.prefix) || "",
            mode: mode,
            reason: ev.allowed
                ? "node participated via " + node.backendId + " backend"
                : "node gated by directive"
        };
    }

    function buildTokenFlow(ev) {
        var tf = ev && ev.tokenFlow;
        if (!tf) return null;

        return {
            consumed: (tf.consumed || []).map(function(c) {
                return {
                    tokenId: c.tokenId || "",
                    tokenText: c.tokenText || "",
                    field: c.field || "",
                    strength: c.strength || 0,
                    mode: c.mode || "hard",
                    reason: c.reason || ""
                };
            }),
            passed: (tf.passed || []).map(function(t) {
                return { raw: t.raw || "", normalized: t.normalized || "" };
            }),
            inherited: (tf.inherited || []).map(function(i) {
                return {
                    tokenId: i.tokenId || "",
                    tokenText: i.tokenText || "",
                    field: i.field || "",
                    strength: i.strength || 0,
                    mode: i.mode || "context",
                    reason: i.reason || ""
                };
            }),
            strategy: tf.reason ? tf.reason.split(":")[0] : "pass-all",
            reason: tf.reason || ""
        };
    }

    function buildTakeover(takeover, ev, ctx) {
        if (!takeover) return null;
        var claims = takeover.claims || [];
        var decision = takeover.decision;

        return {
            claims: claims.map(function(c) {
                return {
                    claimantId: c.claimantId || "",
                    targetId: c.targetId || "",
                    kind: c.kind || "selection",
                    strength: c.strength || 0,
                    reason: c.reason || ""
                };
            }),
            decision: decision ? {
                accepted: !!decision.accepted,
                ownerId: decision.ownerId || "",
                representation: decision.representation || "keep-parent",
                retainParent: decision.retainParent !== false,
                suppressParentActions: !!decision.suppressParentActions,
                selectedOwnerId: decision.selectedOwnerId || "",
                defaultActionOwnerId: decision.defaultActionOwnerId || "",
                activation: decision.activation || "normal",
                reason: decision.reason || ""
            } : null,
            reason: decision ? decision.reason : "no claims evaluated"
        };
    }

    function buildScoring(ev, ctx) {
        if (!ev) return null;

        var evidenceSummary = (ev.ownEvidence || []).slice(0, 3).map(function(e) {
            return {
                field: e.field || "",
                kind: e.kind || "",
                effective: e.effective || 0,
                reason: e.reason || ""
            };
        });

        return {
            ownScore: ev.ownScore || 0,
            contextScore: ev.inheritedScore || 0,
            coverageScore: ev.descendantScore || 0,
            finalScore: ev.score || 0,
            primaryEvidence: evidenceSummary
        };
    }

    function buildRepresentation(decision, placement) {
        if (!decision) {
            return {
                mode: placement || "standalone",
                retainParent: placement !== "flattened" && placement !== "promoted-child",
                suppressParentActions: false,
                reason: "direct placement"
            };
        }

        var mode = decision.mode || "normal";
        var reprMode = "standalone";
        var retainParent = decision.showParent !== false;
        var suppressActions = !!decision.suppressParentActions;
        var reason = "";

        var takeoverDecision = decision.takeover && decision.takeover.decision;
        if (takeoverDecision && takeoverDecision.accepted) {
            retainParent = takeoverDecision.retainParent !== false;
            suppressActions = !!takeoverDecision.suppressParentActions;
            reprMode = takeoverDecision.representation || "keep-parent";
            reason = "takeover: " + (takeoverDecision.reason || "accepted");
            return {
                mode: reprMode,
                retainParent: retainParent,
                suppressParentActions: suppressActions,
                reason: reason
            };
        }

        switch (mode) {
        case "flatten-all-children":
            reprMode = "flatten-children";
            retainParent = false;
            reason = "all children visible, parent hidden";
            break;
        case "flatten-children":
            reprMode = "promote-child";
            retainParent = false;
            reason = "child promoted to standalone";
            break;
        case "nested-group":
            reprMode = "nested-child";
            retainParent = true;
            if (suppressActions) reason = "nested group with parent actions suppressed";
            else reason = "nested group with visible children";
            break;
        case "group":
            reprMode = "keep-parent";
            retainParent = true;
            reason = "group header, children hidden";
            break;
        case "normal":
            reprMode = "standalone";
            retainParent = true;
            reason = "standalone row";
            break;
        case "promoted-child":
            reprMode = "promoted";
            retainParent = true;
            reason = "child promoted to standalone row";
            break;
        case "flattened":
            reprMode = "flat";
            retainParent = true;
            reason = "flattened child row";
            break;
        default:
            reprMode = placement || mode;
            reason = "placement from decision";
        }

        if (decision._expandResult) {
            reason += " (expanded via policy)";
        }
        if (decision._suppressedRetain) {
            retainParent = false;
            reason += " (parent retention suppressed via policy)";
        }

        return {
            mode: reprMode,
            retainParent: retainParent,
            suppressParentActions: suppressActions,
            reason: reason
        };
    }

    function buildAction(ev, decision, ctx) {
        if (!ev || !ev.node) return null;

        var node = ev.node;
        var ownerId = node.id || "";
        var actionId = "";
        var reason = "node controls own action";

        var takeoverDecision = decision && decision.takeover && decision.takeover.decision;
        if (takeoverDecision && takeoverDecision.accepted) {
            ownerId = takeoverDecision.selectedOwnerId || ownerId;
            var daOwnerId = takeoverDecision.defaultActionOwnerId || ownerId;
            reason = "takeover: " + (takeoverDecision.reason || "accepted");
            var takeoverTarget = daOwnerId !== node.id ? daOwnerId : node.id;
            var hasSwitch = !!node.switchActions;
            var hasActionList = !!(node.actionList && node.actionList.length > 0);
            if (hasSwitch) {
                actionId = "switch-action";
                reason += " (switch, owner: " + daOwnerId + ")";
            } else if (hasActionList) {
                actionId = (node.actionList[0] && node.actionList[0].id) || "default-action";
                reason += " (action list, owner: " + daOwnerId + ")";
            }
            return {
                selectedOwnerId: ownerId,
                defaultActionOwnerId: daOwnerId,
                actionId: actionId,
                reason: reason
            };
        }

        if (decision && decision.mode === "flatten-children" && decision.children && decision.children.length === 1) {
            var child = decision.children[0];
            if (child && child.node) {
                ownerId = child.node.id || ownerId;
                reason = "child " + (child.node.label || "") + " owns action via flatten";
            }
        }

        var hasSwitch = !!node.switchActions;
        var hasActionList = !!(node.actionList && node.actionList.length > 0);
        if (hasSwitch) {
            actionId = "switch-action";
            reason += " (switch)";
        } else if (hasActionList) {
            actionId = (node.actionList[0] && node.actionList[0].id) || "default-action";
            reason += " (action list)";
        }

        return {
            selectedOwnerId: ownerId,
            defaultActionOwnerId: ownerId,
            actionId: actionId,
            reason: reason
        };
    }

    function buildActivation(node, ctx) {
        if (!node) return null;

        var activation = ActivationGate.resolveActivation(node, ctx, ctx && ctx.query && ctx.query.raw || "");
        var riskLevel = activation.riskLevel || "none";

        return {
            allowed: activation.allowed,
            mode: activation.mode || "normal",
            riskLevel: riskLevel,
            reason: activation.reason || "normal activation",
            policyReason: activation.policyReason || "",
            requiresConfirm: !!activation.requiresConfirm,
            requiresExplicitPrefix: !!activation.requiresExplicitPrefix
        };
    }

    function toDebug(sem) {
        if (!sem) return null;
        return {
            participation: sem.participation ? { backendId: sem.participation.backendId, mode: sem.participation.mode, reason: sem.participation.reason } : null,
            tokenFlow: sem.tokenFlow ? { consumed: sem.tokenFlow.consumed.length, passed: sem.tokenFlow.passed.length, inherited: sem.tokenFlow.inherited.length, reason: sem.tokenFlow.reason } : null,
            scoring: sem.scoring ? { ownScore: sem.scoring.ownScore, finalScore: sem.scoring.finalScore, evidence: sem.scoring.primaryEvidence.length } : null,
            takeover: sem.takeover ? {
                claims: sem.takeover.claims.length,
                accepted: sem.takeover.decision ? sem.takeover.decision.accepted : false,
                reason: sem.takeover.reason
            } : null,
            representation: sem.representation ? { mode: sem.representation.mode, retainParent: sem.representation.retainParent, reason: sem.representation.reason } : null,
            action: sem.action ? { ownerId: sem.action.selectedOwnerId, actionId: sem.action.actionId, reason: sem.action.reason } : null,
            activation: sem.activation ? { allowed: sem.activation.allowed, mode: sem.activation.mode, riskLevel: sem.activation.riskLevel, reason: sem.activation.reason, policyReason: sem.activation.policyReason, requiresConfirm: sem.activation.requiresConfirm, requiresExplicitPrefix: sem.activation.requiresExplicitPrefix } : null
        };
    }
}
