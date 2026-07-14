pragma Singleton
import QtQml
import Quickshell
import qs.services

Singleton {
    readonly property var tracer: Logger.scope("launcher.policySpec", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.policySpec", { category: "launcher" })

    function normalize(spec) {
        if (typeof spec === "string") return normalizeString(spec);
        if (Array.isArray(spec)) return normalizeArray(spec);
        if (typeof spec === "object" && spec !== null) return normalizeObject(spec);
        tracer.trace("normalize", function() { return { specType: typeof spec, result: null }; });
        return null;
    }

    function normalizeString(str) {
        if (str.indexOf(":") >= 0) {
            throw new Error("PolicySpec: colon-encoded policy spec is no longer supported: '" + str + "'. Use array spec like ['" + str.split(":")[0] + "', { ... }] instead.");
        }
        return {
            name: str,
            kind: classifyBase(str),
            args: {},
            priority: 0
        };
    }

    function normalizeArray(arr) {
        if (arr.length < 1) return null;
        var name = String(arr[0]);
        var args = (arr.length >= 2 && typeof arr[1] === "object" && arr[1] !== null && !Array.isArray(arr[1]))
            ? shallowClone(arr[1]) : {};
        var priority = arr.length >= 3 ? Number(arr[2]) || 0 : 0;
        return {
            name: name,
            kind: classifyBase(name),
            args: args,
            priority: priority
        };
    }

    function normalizeObject(obj) {
        var name = String(obj.name || "");
        if (!name) return null;
        return {
            name: name,
            kind: obj.kind || classifyBase(name),
            args: obj.args ? shallowClone(obj.args) : {},
            priority: obj.priority || 0
        };
    }

    function classifyBase(baseName) {
        switch (baseName) {
        case "field-match": return "evidence";
        case "switch-action": return "evidence";
        case "semantic": return "evidence";
        case "token-claim": return "evidence";
        case "usage": return "evidence";
        case "recency": return "evidence";
        case "descendant-boost": return "boost";
        case "visible-flag": return "childVisible";
        case "switch-aliases": return "boost";
        case "pass-all":
        case "consume-own-pass-rest":
        case "claim-context-pass-all":
        case "consume-namespace-pass-rest":
        case "consume-action-token":
        case "consume-switch-pass-rest":
        case "consume-path-segment":
            return "tokenFlow";
        case "explicit-child-token":
        case "child-own-match-parent-no-own-match":
        case "child-covers-passed-tokens":
        case "own-score-dominates-takeover":
        case "exact-action-token-takeover":
            return "takeoverRequest";
        case "accept-all-claims":
        case "accept-explicit-claims":
        case "accept-dominated-claims":
            return "takeoverAccept";
        case "expand-when":
        case "expand-on-own-match":
        case "expand-on-trailing-space":
        case "expand-on-explicit-parent-token":
        case "expand-on-child-match":
        case "expand-on-own-match-or-trailing-space":
        case "expand-all":
        case "expand-none":
            return "expand";
        case "retain-parent-when":
        case "retain-always":
        case "retain-never":
            return "retainParent";
        case "default-action-owner":
        case "default-action-expand":
            return "defaultAction";
        case "risk-gate":
        case "risk-gate-confirm":
        case "risk-gate-block":
            return "riskGate";
        default: return "custom";
        }
    }

    function shallowClone(obj) {
        var out = {};
        for (var k in obj) {
            if (Object.prototype.hasOwnProperty.call(obj, k))
                out[k] = obj[k];
        }
        return out;
    }
}
