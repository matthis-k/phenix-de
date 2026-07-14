pragma Singleton
import QtQml
import Quickshell
import qs.services

Singleton {
    readonly property var prof: Profiler.scope("launcher.decisionTrace", { category: "launcher" })
    readonly property var tracer: Logger.scope("launcher.decisionTrace", { category: "launcher" })

    function initPolicyTrace(ev, ctx) {
        if (!ev || !ev.node || !ev.node.id || !ctx._policyTrace) return;
        var nid = ev.node.id;
        tracer.trace("initPolicyTrace", function() { return { nodeId: nid }; });
        if (!ctx._policyTrace[nid]) ctx._policyTrace[nid] = {};
    }

    function ensureTrace(ev, ctx, kind) {
        if (!ev || !ev.node || !ev.node.id || !ctx._policyTrace) return null;
        var nid = ev.node.id;
        if (!ctx._policyTrace[nid]) ctx._policyTrace[nid] = {};
        if (!ctx._policyTrace[nid][kind]) {
            ctx._policyTrace[nid][kind] = {
                kind: kind,
                evaluated: [],
                aggregate: null,
                final: null
            };
        }
        return ctx._policyTrace[nid][kind];
    }

    function policy(ev, ctx, kind, voteOrName, returned, effect, reasons) {
        if (!ev || !ev.node || !ev.node.id || !ctx._policyTrace) return;
        var nid = ev.node.id;
        tracer.trace("policy", function() { return { nodeId: nid, kind: kind, voteType: typeof voteOrName, effect: effect }; });
        if (!ctx._policyTrace[nid]) ctx._policyTrace[nid] = {};
        if (!ctx._policyTrace[nid][kind]) {
            ctx._policyTrace[nid][kind] = {
                kind: kind,
                evaluated: [],
                aggregate: null,
                final: null
            };
        }

        // Normalize voteOrName: if it's an object with policy/priority, treat as normalized vote
        var name, priority;
        if (typeof voteOrName === "object" && voteOrName !== null && !Array.isArray(voteOrName) && voteOrName.policy !== undefined) {
            name = String(voteOrName.policy || kind);
            priority = Number(voteOrName.priority) || 0;
        } else if (typeof voteOrName === "object" && voteOrName !== null && voteOrName.name !== undefined) {
            // PolicyChain trace callback format
            name = String(voteOrName.name || kind);
            priority = Number(voteOrName.priority) || 0;
        } else {
            name = String(voteOrName || kind);
            priority = 0;
        }

        var returnedVal = returned !== undefined ? returned : null;
        var reasonsList = (reasons || []).slice();

        ctx._policyTrace[nid][kind].evaluated.push({
            name: name,
            priority: priority,
            enabled: true,
            returned: returnedVal,
            effect: String(effect || "no-op"),
            reasons: reasonsList
        });
    }

    function aggregate(ev, ctx, kind, strategy, result, reasons) {
        var trace = ensureTrace(ev, ctx, kind);
        if (!trace) return;
        trace.aggregate = {
            strategy: strategy || "unknown",
            inputCount: (trace.evaluated || []).length,
            result: result,
            reasons: (reasons || []).slice()
        };
    }

    function placement(ev, ctx, decision) {
        if (!ev || !ev.node || !ev.node.id || !ctx._decisionTrace) return;
        var nid = ev.node.id;
        tracer.trace("placement", function() { return { nodeId: nid, mode: decision.mode, placement: decision.placement || decision.mode }; });
        var expandFinal = ctx._policyTrace && ctx._policyTrace[nid] && ctx._policyTrace[nid].expand && ctx._policyTrace[nid].expand.final;
        var retainFinal = ctx._policyTrace && ctx._policyTrace[nid] && ctx._policyTrace[nid].retain && ctx._policyTrace[nid].retain.final;
        var takeoverFinal = ctx._policyTrace && ctx._policyTrace[nid] && ctx._policyTrace[nid].takeover && ctx._policyTrace[nid].takeover.final;
        ctx._decisionTrace[nid] = {
            nodeId: nid,
            visibility: { value: { visible: ev.visible }, reasons: [{ code: "visibility", text: "visible=" + ev.visible + " ownVisible=" + ev.ownVisible }] },
            placement: { value: decision.placement || decision.mode || "unknown", reasons: [{ code: "placement", text: "mode=" + (decision.mode || "normal") + " showParent=" + (decision.showParent !== false) + " placement=" + (decision.placement || decision.mode || "unknown") }] },
            flattening: { value: { flatten: decision.mode === "flatten-children" || decision.mode === "flatten-all-children", mode: decision.mode || "normal" }, reasons: [{ code: "flattening", text: "mode=" + (decision.mode || "normal") }] },
            breadcrumbs: null,
            defaultAction: null,
            childVisibility: null,
            _expand: expandFinal || null,
            _retain: retainFinal || null,
            _takeover: takeoverFinal || null
        };
        final(ev, ctx, "placement", { placement: decision.placement || decision.mode || "unknown", mode: decision.mode || "normal", showParent: decision.showParent !== false }, [{ code: "placement_decided", text: "final placement=" + (decision.placement || decision.mode || "unknown") + " mode=" + (decision.mode || "normal") }]);
    }

    function policyVote(ev, ctx, kind, vote, effect) {
        if (!ev || !ev.node || !ev.node.id || !ctx._policyTrace) return;
        var nid = ev.node.id;
        tracer.trace("policyVote", function() { return { nodeId: nid, kind: kind, policy: vote && vote.policy, priority: vote && vote.priority }; });
        if (!ctx._policyTrace[nid]) ctx._policyTrace[nid] = {};
        if (!ctx._policyTrace[nid][kind]) {
            ctx._policyTrace[nid][kind] = {
                kind: kind,
                evaluated: [],
                aggregate: null,
                final: null
            };
        }

        ctx._policyTrace[nid][kind].evaluated.push({
            name: (vote && vote.policy) || "",
            priority: (vote && vote.priority) || 0,
            enabled: true,
            returned: vote || null,
            effect: String(effect || "no-op"),
            reasons: (vote && vote.reasons || []).slice()
        });
    }

    function final(ev, ctx, kind, value, reasons) {
        var trace = ensureTrace(ev, ctx, kind);
        if (!trace) return;
        tracer.trace("final", function() { return { nodeId: ev.node.id, kind: kind }; });
        trace.final = {
            value: value,
            decision: value,
            reasons: (reasons || []).slice()
        };
    }
}
