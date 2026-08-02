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
    required property var commandExecutor

    function _activateResultAction(result, actionId) {
        if (!result) {
            tracer.debug("activateResultAction", function() { return { reason: "no result", actionId: actionId || "" }; });
            return false;
        }

        var action = actionFor(result, actionId);
        if (!action) {
            tracer.debug("activateResultAction", function() {
                return { resultId: result.id || result.nodeId || "", actionId: actionId || "", reason: "no matching action" };
            });
            return false;
        }

        tracer.info("activateResultAction", function() {
            return {
                resultId: result.id || result.nodeId || "",
                title: result.title || "",
                actionId: actionId || "",
                hasSwitchActions: !!result.switchActions,
                switchState: result.switchState
            };
        });

        var confirmationTarget = Object.assign({}, result, {
            risk: action.risk || result.risk,
            dangerous: !!(action.dangerous || result.dangerous)
        });
        var execute = function() {
            return root.commandExecutor.executeRecipe([
                { kind: "activate", args: { action: actionId } }
            ], result).success;
        };
        var success = root.actionController
            ? root.actionController.activateWithConfirmation(confirmationTarget, execute)
            : execute();

        if (success && result.switchActions && root.controlHandler)
            root.controlHandler.refreshSwitchResult(result, action);
        return success;
    }

    readonly property var activateResultAction: prof.fn("activateResultAction", _activateResultAction)

    function actionFor(result, actionId) {
        if (result.switchActions && result.switchActions[actionId])
            return result.switchActions[actionId];
        var actions = result.actions || [];
        for (var i = 0; i < actions.length; i += 1) {
            if (actions[i] && actions[i].id === actionId)
                return actions[i];
        }
        return null;
    }
}
