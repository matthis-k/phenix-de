pragma Singleton
import Quickshell
import qs.services

Singleton {
    readonly property var tracer: Logger.scope("launcher.actionSpec", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.actionSpec", { category: "launcher" })

    function normalize(step) {
        if (step === null || step === undefined) {
            tracer.trace("normalize", function() { return { step: null, result: "noop" }; });
            return { name: "noop", args: {}, priority: 0, source: "normalizer" };
        }

        if (typeof step === "string")
            return normalizeString(step);

        if (Array.isArray(step))
            return normalizeArray(step);

        if (typeof step === "object")
            return normalizeObject(step);

        return { name: "noop", args: {}, priority: 0, source: "normalizer" };
    }

    function normalizeString(str) {
        return {
            name: str,
            args: {},
            priority: 0,
            source: "string"
        };
    }

    function normalizeArray(arr) {
        if (arr.length < 1)
            return { name: "noop", args: {}, priority: 0, source: "normalizer" };

        var name = String(arr[0]);
        var args = (arr.length >= 2 && typeof arr[1] === "object" && arr[1] !== null && !Array.isArray(arr[1]))
            ? shallowClone(arr[1]) : {};
        var priority = arr.length >= 3 ? Number(arr[2]) || 0 : 0;

        return {
            name: name,
            args: args,
            priority: priority,
            source: "array"
        };
    }

    function normalizeObject(obj) {
        var name = String(obj.name || "noop");
        var args = obj.args ? shallowClone(obj.args) : {};
        var priority = obj.priority !== undefined ? Number(obj.priority) : 0;
        var source = obj.source || "object";

        return {
            name: name,
            args: args,
            priority: priority,
            source: source
        };
    }

    function normalizeRecipe(recipe) {
        if (!recipe || !Array.isArray(recipe))
            return [];

        return recipe.map(normalize);
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
