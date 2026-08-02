pragma Singleton
import QtQml
import Quickshell
import qs.services
import "logic/PolicyCatalog.js" as PolicyCatalog

Singleton {
    readonly property var tracer: Logger.scope("launcher.policyRegistry", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.policyRegistry", { category: "launcher" })

    readonly property var catalog: ({
        resolve: function(kind, name) { return PolicyCatalog.resolve(kind, name); },
        list: function(kind) { return PolicyCatalog.list(kind); },
        toDto: function() { return PolicyCatalog.toDto(); }
    })

    function registerEvidence(id, group, matchFn) {
        tracer.trace("registerEvidence", function() { return { id: id, group: group }; });
        PolicyCatalog.register("evidence", id, {
            name: id,
            phase: "evidence",
            group: group || "own",
            match: matchFn
        });
    }

    function _register(kind, id, applyFn) {
        PolicyCatalog.register(kind, id, {
            name: id,
            phase: kind,
            apply: applyFn
        });
    }

    function registerBoost(id, fn) { _register("boost", id, fn); }
    function registerChildVisible(id, fn) { _register("childVisible", id, fn); }
    function registerTokenFlow(id, fn) { _register("tokenFlow", id, fn); }
    function registerTakeoverRequest(id, fn) { _register("takeoverRequest", id, fn); }
    function registerTakeoverAccept(id, fn) { _register("takeoverAccept", id, fn); }
    function registerExpand(id, fn) { _register("expand", id, fn); }
    function registerRetainParent(id, fn) { _register("retainParent", id, fn); }
    function registerDefaultAction(id, fn) { _register("defaultAction", id, fn); }
    function registerRiskGate(id, fn) { _register("riskGate", id, fn); }
    function registerNesting(id, fn) { _register("nesting", id, fn); }
    function registerChildBypass(id, fn) { _register("childBypass", id, fn); }

    function catalogDto() { return PolicyCatalog.toDto(); }
}
