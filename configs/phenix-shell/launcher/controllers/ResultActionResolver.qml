import QtQml
import qs.services
import "../logic/"

QtObject {
    readonly property var tracer: Logger.scope("launcher.resultAction", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.resultAction", { category: "launcher" })
    id: root

    property var controller: null
    property var actionController: null
    property var controlHandler: null

    function _activateResultAction(result, actionId) {
        if (!result) {
            tracer.debug("activateResultAction", function() { return { reason: "no result", actionId: actionId || "" }; });
            return false;
        }

        var actions = result.actions || [];
        tracer.info("activateResultAction", function() { return { resultId: result.id || result.nodeId || "", title: result.title || "", actionId: actionId || "", actionIds: actions.map(function(a) { return a ? a.id || "" : ""; }), hasSwitchActions: !!result.switchActions, switchState: result.switchState }; });

        for (var i = 0; i < actions.length; i += 1) {
            if (actions[i] && actions[i].id === actionId) {
                var confirmTarget = Object.assign({}, result, { risk: actions[i].risk || result.risk, dangerous: !!(actions[i].dangerous || result.dangerous) });
                var recipeResult = root.actionController
                    ? { success: root.actionController.activateWithConfirmation(confirmTarget, function() { return ActionRegistry.executeRecipe([["run-action", { action: actionId }]], result, root.controller).success; }) }
                    : ActionRegistry.executeRecipe([["run-action", { action: actionId }]], result, root.controller);
                if (recipeResult.success && result.switchActions && root.controlHandler)
                    root.controlHandler.refreshSwitchResult(result, actions[i]);
                return recipeResult.success;
            }
        }

        if (result.switchActions && result.switchActions[actionId]) {
            var switchAction = result.switchActions[actionId];
            var switchConfirmTarget = Object.assign({}, result, { risk: switchAction.risk || result.risk, dangerous: !!(switchAction.dangerous || result.dangerous) });
            var switchResult = root.actionController
                ? { success: root.actionController.activateWithConfirmation(switchConfirmTarget, function() { return ActionRegistry.executeRecipe([["run-action", { action: actionId }]], result, root.controller).success; }) }
                : ActionRegistry.executeRecipe([["run-action", { action: actionId }]], result, root.controller);
            if (switchResult.success && root.controlHandler)
                root.controlHandler.refreshSwitchResult(result, result.switchActions[actionId]);
            return switchResult.success;
        }

        tracer.debug("activateResultAction", function() { return { resultId: result.id || result.nodeId || "", actionId: actionId || "", reason: "no matching action" }; });
        return false;
    }

    readonly property var activateResultAction: prof.fn("activateResultAction", _activateResultAction)
}
