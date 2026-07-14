pragma Singleton
import Quickshell
import qs.services

Singleton {
    readonly property var tracer: Logger.scope("launcher.recipeResolver", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.recipeResolver", { category: "launcher" })

    function effectiveRecipe(target, slotName, options) {
        options = options || {};

        if (!target) {
            tracer.trace("effectiveRecipe", function() { return { slotName: slotName, hasTarget: false }; });
            return [];
        }
        tracer.trace("effectiveRecipe", function() { return { targetId: target.id || target.nodeId || "", slotName: slotName }; });

        if (slotName === "activate")
            return resolveActivate(target, options);
        if (slotName === "complete")
            return resolveComplete(target, options);

        return [];
    }

    function effectiveInteractions(target, options) {
        options = options || {};

        if (!target) {
            tracer.trace("effectiveInteractions", function() { return { hasTarget: false }; });
            return {};
        }
        tracer.trace("effectiveInteractions", function() { return { targetId: target.id || target.nodeId || "" }; });

        var merged = {};
        var builtins = buildDefaultInteractions(target, options);
        mergeInteractions(merged, builtins);

        var parentOverrides = options.parentInteractions || {};
        mergeInteractions(merged, parentOverrides);

        var nodeOverrides = target.interactions || target.interactions;
        if (nodeOverrides && typeof nodeOverrides === "object")
            mergeInteractions(merged, nodeOverrides);

        return merged;
    }

    function resolveActivate(target, options) {
        if (target.recipes && target.recipes.activate)
            return normalizeRecipeArray(target.recipes.activate);

        if (hasReplaceQuery(target))
            return [["edit-query", { mode: "replace", from: "metadata.replaceQuery" }]];

        if (hasDefaultExecutableAction(target))
            return [["run-action", { action: "default" }], ["close"]];

        return [["noop"]];
    }

    function resolveComplete(target, options) {
        if (target.recipes && target.recipes.complete)
            return normalizeRecipeArray(target.recipes.complete);

        if (hasReplaceQuery(target))
            return [["edit-query", { mode: "replace", from: "metadata.replaceQuery" }]];

        if (target.filterable)
            return [["edit-query", { mode: "replace", from: "metadata.replaceQuery" }]];

        return [];
    }

    function buildDefaultInteractions(target, options) {
        var out = {};

        if (target.control && target.control.kind === "slider") {
            out["h"] = { label: "Decrease", recipe: [["adjust-control", { delta: -1 }]] };
            out["l"] = { label: "Increase", recipe: [["adjust-control", { delta: 1 }]] };
        }

        if (target.switchActions) {
            out["h"] = {
                label: "Off",
                recipe: [["run-action", { prefer: ["off", "disable", "decrease", "left"] }]]
            };
            out["l"] = {
                label: "On",
                recipe: [["run-action", { prefer: ["on", "enable", "increase", "right"] }]]
            };
        }

        if (target.switchActions && target.switchActions.toggle) {
            out["m"] = {
                label: "Mute",
                recipe: [["run-action", { prefer: ["toggle", "mute", "toggle-mute"] }]]
            };
        }

        var actions = target.actions || [];
        for (var i = 0; i < actions.length; i += 1) {
            var action = actions[i];
            var id = action.id || "";

            if (id === "off" || id === "disable" || id === "decrease" || id === "left")
                out["h"] = { label: action.label || id, recipe: [["run-action", { action: id }]] };
            else if (id === "on" || id === "enable" || id === "increase" || id === "right")
                out["l"] = { label: action.label || id, recipe: [["run-action", { action: id }]] };
            else if (id === "toggle" || id === "mute" || id === "toggle-mute")
                out["m"] = { label: action.label || id, recipe: [["run-action", { action: id }]] };
        }

        return out;
    }

    function mergeInteractions(base, overrides) {
        if (!overrides) return;
        for (var key in overrides) {
            if (!Object.prototype.hasOwnProperty.call(overrides, key))
                continue;
            var val = overrides[key];
            if (val === false || val === null) {
                delete base[key];
            } else if (val && typeof val === "object") {
                base[key] = {
                    label: val.label || key.toUpperCase(),
                    recipe: normalizeRecipeArray(val.recipe || [])
                };
            }
        }
    }

    function normalizeRecipeArray(recipe) {
        if (!recipe || !Array.isArray(recipe))
            return [];
        return recipe.map(function(step) {
            return ActionSpec.normalize(step);
        });
    }

    function hasReplaceQuery(target) {
        return !!replaceQueryValue(target);
    }

    function replaceQueryValue(target) {
        if (!target) return "";
        if (target.metadata && target.metadata.replaceQuery) return target.metadata.replaceQuery;
        if (target.defaultAction && target.defaultAction.payload && target.defaultAction.payload.replaceQuery) return target.defaultAction.payload.replaceQuery;
        if (target.metadata && target.metadata.action && target.metadata.action.replaceQuery) return target.metadata.action.replaceQuery;
        if (target.metadata && target.metadata.action && target.metadata.action.payload && target.metadata.action.payload.replaceQuery) return target.metadata.action.payload.replaceQuery;
        var actions = target.actions || [];
        for (var i = 0; i < actions.length; i += 1) {
            if (actions[i] && actions[i].default && actions[i].payload && actions[i].payload.replaceQuery)
                return actions[i].payload.replaceQuery;
        }
        return "";
    }

    function hasDefaultExecutableAction(target) {
        if (target.canExecuteNow || target.executable)
            return true;
        var actions = target.actions || [];
        for (var i = 0; i < actions.length; i += 1) {
            if (actions[i].default) return true;
        }
        return actions.length > 0;
    }
}
