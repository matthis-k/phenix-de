pragma Singleton
import QtQml
import Quickshell
import qs.services
import "PolicySpec.qml"

Singleton {
    readonly property var prof: Profiler.scope("launcher.policyChain", { category: "launcher" })
    readonly property var tracer: Logger.scope("launcher.policyChain", { category: "launcher" })
    readonly property var defaultModes: ({
        evidence: "accumulate",
        boost: "best-wins",
        childVisible: "all-and"
    })

    function lookupPolicy(registry, spec) {
        if (!registry || !spec) return null;
        return spec.name ? registry.get(spec.name) : null;
    }

    function nowMs() {
        var d = new Date();
        return d.getTime();
    }

    function normalizeReasons(raw) {
        if (!raw) return [];
        if (Array.isArray(raw)) return raw.slice();
        if (typeof raw === "string") return [{ code: "reason", text: raw }];
        if (raw && raw.code && raw.text) return [raw];
        return [{ code: "reason", text: String(raw) }];
    }

    function normalizePolicyResult(raw, spec) {
        if (raw === null || raw === undefined)
            return null;

        var isObj = typeof raw === "object" && !Array.isArray(raw);

        var decision;
        if (isObj && Object.prototype.hasOwnProperty.call(raw, "decision"))
            decision = raw.decision;
        else if (isObj && Object.prototype.hasOwnProperty.call(raw, "value"))
            decision = raw.value;
        else
            decision = raw;

        var priority = 0;
        if (isObj && raw.priority !== undefined)
            priority = Number(raw.priority) || 0;
        else if (spec && spec.priority !== undefined)
            priority = Number(spec.priority) || 0;

        var reasons = [];
        if (isObj) {
            if (raw.reasons && Array.isArray(raw.reasons))
                reasons = raw.reasons.slice();
            else if (raw.reason)
                reasons = normalizeReasons(raw.reason);
        }

        return {
            decision: decision,
            // Compatibility only. Structural decision call sites must use .decision.
            // Remove after all structural policy consumers no longer read .value.
            value: decision,
            priority: priority,
            reasons: reasons,
            policy: spec && spec.name || "",
            kind: spec && spec.kind || ""
        };
    }

    function normalize(raw) {
        return normalizePolicyResult(raw, null);
    }

    function _run(names, call, modeOrPhase, tracePerPolicy, timings) {
        var mode = defaultModes[modeOrPhase] || modeOrPhase;
        tracer.trace("run", function() { return { names: (names || []).length, mode: modeOrPhase || "unknown", resolvedMode: mode }; });
        if (!mode)
            return { value: null, decision: null, priority: 0 };

        var results = [];
        for (var i = 0; i < names.length; i += 1) {
            var spec = PolicySpec.normalize(names[i]);
            if (!spec)
                continue;

            var pStart = timings ? nowMs() : 0;
            var raw = call(spec.name, spec);
            if (timings) {
                var elapsed = nowMs() - pStart;
                timings[spec.name] = (timings[spec.name] || 0) + elapsed;
            }

            if (raw === null || raw === undefined)
                continue;
            var r = normalizePolicyResult(raw, spec);

            // Trace each policy at the real execution site
            if (typeof tracePerPolicy === "function") {
                var effect = "no-op";
                var modeEffect = "";
                if (mode === "first-wins")
                    modeEffect = "selected";
                else if (mode === "best-wins")
                    modeEffect = "considered";
                else if (mode === "accumulate" || mode === "accumulate-votes")
                    modeEffect = "accumulated";
                else if (mode === "all-and" || mode === "all-or")
                    modeEffect = "evaluated";
                var hasDecision = r.decision !== null && r.decision !== undefined;
                if (hasDecision) {
                    if (mode === "first-wins" && results.length === 0)
                        effect = "selected";
                    else if (mode !== "first-wins")
                        effect = modeEffect;
                    else
                        effect = "ignored";
                }
                tracePerPolicy({
                    name: spec.name,
                    priority: r.priority,
                    enabled: true,
                    args: spec.args || null,
                    returned: r,
                    effect: effect
                });
            }

            results.push(r);
            if (mode === "first-wins") {
                if (typeof tracePerPolicy === "function") {
                    for (var j = i + 1; j < names.length; j += 1) {
                        var remainingSpec = PolicySpec.normalize(names[j]);
                        if (!remainingSpec)
                            continue;
                        tracePerPolicy({
                            name: remainingSpec.name,
                            priority: remainingSpec.priority || 0,
                            enabled: true,
                            args: remainingSpec.args || null,
                            returned: null,
                            effect: "not-evaluated",
                            reasons: [{
                                code: "first_wins_short_circuit",
                                text: "Policy was not evaluated because an earlier first-wins policy already selected a result."
                            }]
                        });
                    }
                }
                break;
            }
            if (mode === "all-and" && !r.decision)
                return { value: false, decision: false, priority: 0 };
            if (mode === "all-or" && r.decision)
                return { value: true, decision: true, priority: 0 };
        }
        return combine(results, mode);
    }

    readonly property var run: prof.fn("run", _run)

    function combine(results, mode) {
        if (!results.length) {
            switch (mode) {
            case "all-and":  return { value: true, decision: true };
            case "all-or":   return { value: false, decision: false };
            case "accumulate":
            case "accumulate-votes": return { value: [], decision: [] };
            default:                return { value: null, decision: null };
            }
        }
        switch (mode) {
        case "accumulate": {
            var acc = [];
            for (var i = 0; i < results.length; i += 1) {
                var v = results[i].value;
                if (Array.isArray(v))
                    acc = acc.concat(v);
                else
                    acc.push(v);
            }
            return { value: acc, decision: acc };
        }
        case "accumulate-votes": {
            return {
                value: results,
                decision: results,
                priority: 0
            };
        }
        case "all-and":
            return { value: results.every(function(r) { return r.value; }), decision: results.every(function(r) { return r.value; }) };
        case "all-or":
            return { value: results.some(function(r) { return r.value; }), decision: results.some(function(r) { return r.value; }) };
        case "first-wins":
            return results[0];
        case "best-wins": {
            var best = results[0];
            for (var i = 1; i < results.length; i += 1) {
                var ri = results[i];
                var riNum = typeof ri.decision === "number";
                var bestNum = typeof best.decision === "number";
                if (riNum && bestNum) {
                    if (ri.priority > best.priority ||
                        (ri.priority === best.priority && ri.decision > best.decision))
                        best = ri;
                } else {
                    if (ri.priority > best.priority)
                        best = ri;
                }
            }
            return best;
        }
        default:
            return results[0] || { value: null, decision: null, priority: 0 };
        }
    }
}
