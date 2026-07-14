import QtQuick
import QtQml
import qs.services
import "../logic/"

Item {
    readonly property var tracer: Logger.scope("launcher.actions", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.actions", { category: "launcher" })
    id: root

    property var controller: null

    ActivationConfirmation {
        id: confirmHandler
        controller: root.controller
    }

    property alias pendingConfirmId: confirmHandler.pendingConfirmId
    property alias pendingConfirmTimeoutMs: confirmHandler.pendingConfirmTimeoutMs

    SelectedTargetResolver {
        id: targetResolver
        controller: root.controller
    }

    ControlInteractionController {
        id: controlHandler
        controller: root.controller
        targetResolver: targetResolver
    }

    LegacyIntentExecutor {
        id: legacyIntentExecutor
        controller: root.controller
        actionController: root
    }

    ResultActionResolver {
        id: resultActionResolver
        controller: root.controller
        actionController: root
        controlHandler: controlHandler
    }

    function _activateSelected(shiftPressed) {
        tracer.info("activateSelected", function() { return { shiftPressed: shiftPressed, inTree: root.controller ? root.controller.isInTree() : false }; });
        if (root.controller && root.controller.isInTree()) {
            if (root.controller.currentTreeKey)
                return targetResolver.activateTreeRowByKey(root.controller.currentTreeKey, null);
            return false;
        }

        var result = root.controller ? root.controller.selectedResult() : null;
        if (!result)
            return false;

        return root.activateWithConfirmation(result, function() {
            return root.executeRecipeSlot(result, shiftPressed ? "complete" : "activate");
        });
    }

    readonly property var activateSelected: prof.fn("activateSelected", _activateSelected)

    function _activateWithConfirmation(target, activationFn) {
        if (!target || typeof activationFn !== "function") {
            tracer.debug("activateWithConfirmation", function() { return { reason: !target ? "no target" : "activationFn not function" }; });
            return false;
        }
        var check = confirmHandler.checkActivation(target);
        if (!check.confirmed) {
            tracer.debug("activateWithConfirmation", function() { return { action: "needsConfirm", targetId: target.id || target.nodeId || "" }; });
            return false;
        }

        tracer.info("activateWithConfirmation", function() { return { targetId: target.id || target.nodeId || "" }; });

        if (root.controller)
            root.controller.confirmationSatisfied = true;
        try {
            return activationFn();
        } finally {
            if (root.controller)
                root.controller.confirmationSatisfied = false;
        }
    }

    readonly property var activateWithConfirmation: prof.fn("activateWithConfirmation", _activateWithConfirmation)

    function requiresConfirm(activation) {
        return confirmHandler.requiresConfirm(activation);
    }

    function completeSelected() {
        var result = root.controller ? root.controller.selectedResult() : null;
        if (!result) {
            tracer.debug("completeSelected", function() { return { reason: "no result" }; });
            return false;
        }
        tracer.info("completeSelected", function() { return { title: result.title, source: result.source || result.backendId }; });
        return root.executeRecipeSlot(result, "complete");
    }

    function _activateResult(result, action) {
        if (!result || !action) {
            tracer.debug("activateResult", function() { return { reason: !result ? "no result" : "no action" }; });
            return false;
        }

        tracer.info("activateResult", function() { return { resultId: result.id || result.nodeId || "", actionId: action.id || "" }; });
        if (result.metadata && result.metadata.replaceQuery) {
            var editResult = ActionRegistry.executeRecipe([["edit-query", { from: "metadata.replaceQuery" }]], result, root.controller);
            return !!editResult.success;
        }
        var confirmationTarget = Object.assign({}, result, { risk: action.risk || result.risk, dangerous: !!(action.dangerous || result.dangerous) });
        return root.activateWithConfirmation(confirmationTarget, function() {
            var recipeResult = ActionRegistry.executeRecipe([["run-action", { action: action.id || "default" }]], result, root.controller);
            return !!recipeResult.success;
        });
    }

    readonly property var activateResult: prof.fn("activateResult", _activateResult)

    function _executeRecipeSlot(target, slotName) {
        if (!target) {
            tracer.debug("executeRecipeSlot", function() { return { reason: "no target" }; });
            return { close: false };
        }
        var recipe = RecipeResolver.effectiveRecipe(target, slotName || "activate", {});
        var recipeResult = ActionRegistry.executeRecipe(recipe, target, root.controller);
        tracer.trace("executeRecipeSlot", function() { return { slot: slotName, targetId: target.id || target.nodeId || "", close: !!recipeResult.close, success: recipeResult.success }; });
        return { close: !!recipeResult.close, success: recipeResult.success };
    }

    readonly property var executeRecipeSlot: prof.fn("executeRecipeSlot", _executeRecipeSlot)

    function applyIntent(result, intent) {
        return legacyIntentExecutor.applyIntent(result, intent);
    }

    function activateResultAction(result, actionId) {
        return resultActionResolver.activateResultAction(result, actionId);
    }

    function adjustSelectedValue(delta) {
        return controlHandler.adjustSelectedValue(delta);
    }

    function toggleSelectedMute() {
        return controlHandler.toggleSelectedMute();
    }

    function refreshSwitchResult(result, action) {
        controlHandler.refreshSwitchResult(result, action);
    }

    function activateTreeRowByKey(key, actionId) {
        return targetResolver.activateTreeRowByKey(key, actionId);
    }

    function treeActivateCurrent() {
        return targetResolver.treeActivateCurrent();
    }

    function runRecipe(recipe, target) {
        if (!recipe || !target) {
            tracer.debug("runRecipe", function() { return { reason: !recipe ? "no recipe" : "no target" }; });
            return { close: false };
        }
        tracer.trace("runRecipe", function() { return { recipeLen: recipe.length, targetId: target.id || target.nodeId || "" }; });
        return ActionRegistry.executeRecipe(recipe, target, root.controller);
    }

    function runRecipeSlot(slotName) {
        var target = root.selectedActionTarget();
        if (!target)
            return { close: false };

        var recipe = root.effectiveRecipeForTarget(target, slotName);
        if (!recipe || recipe.length === 0)
            return { close: false };

        return root.runRecipe(recipe, target);
    }

    function runInteractionForKey(keyName) {
        var target = root.selectedActionTarget();
        if (!target) {
            tracer.debug("runInteractionForKey", function() { return { key: keyName, reason: "no target" }; });
            return { close: false, success: false };
        }

        var interactions = root.effectiveInteractionsForTarget(target);
        if (!interactions || !interactions[keyName]) {
            tracer.debug("runInteractionForKey", function() { return { key: keyName, reason: "no matching interaction" }; });
            return { close: false, success: false };
        }

        tracer.info("runInteractionForKey", function() { return { key: keyName, targetId: target.id || target.nodeId || "" }; });
        return root.runRecipe(interactions[keyName].recipe, target);
    }

    function effectiveRecipeForTarget(target, slotName) {
        return RecipeResolver.effectiveRecipe(target, slotName, {
            parentInteractions: target.interactions || {}
        });
    }

    function effectiveInteractionsForTarget(target) {
        return RecipeResolver.effectiveInteractions(target, {
            parentInteractions: null
        });
    }

    function _legacyApplyIntent(result, intent) {
        return root.applyIntent(result, intent);
    }

    function activateSelectedFromInteraction(shiftPressed) {
        if (shiftPressed && root.controller && root.controller.navigation && root.controller.navigation.isInTree())
            return { close: root.controller.navigation.treeToggleSelected(), closeRequested: false };
        return root._handleActivationWithConfirm();
    }

    function _handleActivationWithConfirm() {
        tracer.info("_handleActivationWithConfirm", function() { return {}; });
        if (root.controller && root.controller.isInTree()) {
            if (root.controller.currentTreeKey)
                return { close: targetResolver.activateTreeRowByKey(root.controller.currentTreeKey, null), closeRequested: false };
            return { close: false };
        }

        var result = root.controller ? root.controller.selectedResult() : null;
        if (!result)
            return { close: false };

        var activationResult = root.activateWithConfirmation(result, function() {
            var recipeResult = root.runRecipeSlot("activate");
            return { close: recipeResult.close, closeRequested: recipeResult.close };
        });
        return activationResult || { close: false, closeRequested: false };
    }

    function selectedActionTarget() {
        return targetResolver.selectedActionTarget();
    }
}
