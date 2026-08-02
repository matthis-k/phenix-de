pragma Singleton
import QtQml
import Quickshell
import qs.services
import "PolicySpec.qml"

// Compiles transport-friendly policy specs into immutable normalized plans and
// memoizes runtime bindings for one search context. A new search context sees
// newly registered policies; a running search remains deterministic.
Singleton {
    readonly property var tracer: Logger.scope("launcher.policyPlan", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.policyPlan", { category: "launcher" })

    property var _normalizedPlans: ({})

    function compile(rawSpecs) {
        var input = rawSpecs || [];
        var key = stableKey(input);
        if (_normalizedPlans[key])
            return _normalizedPlans[key];

        var plan = [];
        for (var i = 0; i < input.length; i += 1) {
            var spec = PolicySpec.normalize(input[i]);
            if (spec)
                plan.push(Object.freeze(spec));
        }
        Object.freeze(plan);
        _normalizedPlans[key] = plan;
        tracer.trace("compiled", function() { return { specCount: plan.length }; });
        return plan;
    }

    function resolve(ctx, kind, spec) {
        var resolver = ctx && ctx.policyResolver;
        if (!resolver || typeof resolver.resolve !== "function")
            throw new Error("Launcher policyResolver dependency is required");
        if (!spec || !spec.name)
            return null;

        var cache = ctx._resolvedPolicyBindings;
        if (!cache) {
            cache = {};
            ctx._resolvedPolicyBindings = cache;
        }

        var key = String(kind || spec.kind || "custom") + ":" + spec.name;
        if (Object.prototype.hasOwnProperty.call(cache, key))
            return cache[key];

        var policy = resolver.resolve(kind, spec);
        cache[key] = policy || null;
        return cache[key];
    }

    function stableKey(specs) {
        try {
            return JSON.stringify(specs || []);
        } catch (error) {
            throw new Error("Launcher policy specs must be serializable: " + error);
        }
    }

    function clear() {
        _normalizedPlans = {};
    }
}
