import QtQml
import qs.services
import "../logic/"

QtObject {
    readonly property var tracer: Logger.scope("launcher.controlInteraction", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.controlInteraction", { category: "launcher" })
    id: root

    property var controller: null
    property var targetResolver: null
    required property var commandExecutor

    function synchronizeTreeSwitchState(result) {
        if (!result || !result.switchActions || !root.controller)
            return;
        if (!root.controller.isInTree() || !root.controller.currentTreeKey || root.controller.selectedIndex < 0)
            return;

        var treeRow = root.controller.findTreeRowData(root.controller.currentTreeKey);
        if (!treeRow)
            return;

        treeRow.switchState = result.switchState;
        if (typeof root.controller.treeSwitchRefreshRequested === "function")
            root.controller.treeSwitchRefreshRequested(root.controller.selectedIndex);
    }

    function _adjustSelectedValue(delta) {
        var result = root.targetResolver ? root.targetResolver.selectedActionTarget() : null;
        if (!result) {
            tracer.debug("adjustSelectedValue", function() { return { reason: "no target", delta: delta }; });
            return false;
        }

        if (result.control) {
            var controlResult = root.commandExecutor.execute({
                kind: "adjust-control",
                args: { delta: delta }
            }, result);
            if (controlResult.success) {
                tracer.trace("adjustSelectedValue", function() { return { delta: delta, action: "control", success: true }; });
                return true;
            }
        }

        var preferredIds = delta < 0
            ? ["off", "decrease", "decrement", "left"]
            : ["on", "increase", "increment", "right"];
        tracer.info("adjustSelectedValue", function() { return { delta: delta, targetId: result.id || result.nodeId || "", title: result.title || "", preferredIds: preferredIds, switchActions: !!result.switchActions, switchState: result.switchState }; });
        for (var i = 0; i < preferredIds.length; i += 1) {
            if (root.controller && root.controller.activateResultAction(result, preferredIds[i])) {
                root.synchronizeTreeSwitchState(result);
                return true;
            }
        }
        tracer.debug("adjustSelectedValue", function() { return { reason: "no action activated", delta: delta, targetId: result.id || result.nodeId || "" }; });
        return false;
    }

    readonly property var adjustSelectedValue: prof.fn("adjustSelectedValue", _adjustSelectedValue)

    function toggleSelectedSwitch() {
        var result = root.targetResolver ? root.targetResolver.selectedActionTarget() : null;
        if (!result) {
            tracer.debug("toggleSelectedSwitch", function() { return { reason: "no target" }; });
            return false;
        }
        if (!result.switchActions) {
            tracer.debug("toggleSelectedSwitch", function() { return { reason: "no switch actions", targetId: result.id || result.nodeId || "" }; });
            return false;
        }

        var toggleResult = root.commandExecutor.execute({
            kind: "toggle-control",
            args: {}
        }, result);
        if (toggleResult.success)
            root.synchronizeTreeSwitchState(result);
        tracer.info("toggleSelectedSwitch", function() {
            return {
                targetId: result.id || result.nodeId || "",
                success: !!toggleResult.success
            };
        });
        return !!toggleResult.success;
    }

    function toggleSelectedMute() {
        return root.toggleSelectedSwitch();
    }

    function _refreshSwitchResult(result, action) {
        var payload = action && action.payload || {};
        var state = action && action.state !== undefined ? action.state : payload.state;
        var previous = result ? result.switchState : undefined;
        if (state === true || state === false) {
            result.switchState = state;
        } else if (state === null) {
            result.switchState = result.switchState === true ? false : true;
        }
        tracer.info("refreshSwitchResult", function() { return { resultId: result ? result.id || result.nodeId || "" : "", actionId: action ? action.id || "" : "", payloadState: state, previousState: previous, nextState: result ? result.switchState : undefined }; });
        if (root.controller)
            root.controller.resultsRefreshRequested();
        Qt.callLater(function() {
            if (root.controller && typeof root.controller.searchRequested === "function")
                root.controller.searchRequested(root.controller.query, root.controller.generation);
        });
    }

    readonly property var refreshSwitchResult: prof.fn("refreshSwitchResult", _refreshSwitchResult)
}
