pragma Singleton
import Quickshell
import qs.services

Singleton {
    readonly property var tracer: Logger.scope("launcher.interactionResolver", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.interactionResolver", { category: "launcher" })

    function resolve(target, options) {
        tracer.trace("resolve", function() { return { targetId: target?.id || target?.nodeId || "" }; });
        return RecipeResolver.effectiveInteractions(target, options);
    }

    function hasInteraction(target, key) {
        if (!target) return false;
        var interactions = RecipeResolver.effectiveInteractions(target);
        return interactions && interactions[key] !== undefined;
    }

    function recipeFor(target, key) {
        if (!target) return null;
        var interactions = RecipeResolver.effectiveInteractions(target);
        if (!interactions || !interactions[key])
            return null;
        return interactions[key].recipe || null;
    }

    function labelFor(target, key) {
        if (!target) return "";
        var interactions = RecipeResolver.effectiveInteractions(target);
        if (!interactions || !interactions[key])
            return "";
        return interactions[key].label || "";
    }

    function availableKeys(target) {
        if (!target) return [];
        var interactions = RecipeResolver.effectiveInteractions(target);
        if (!interactions) return [];
        return Object.keys(interactions);
    }
}
