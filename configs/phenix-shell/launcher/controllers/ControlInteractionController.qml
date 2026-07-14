import QtQml
import qs.services
import "../logic/"

QtObject {
    readonly property var tracer: Logger.scope("launcher.controlInteraction", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.controlInteraction", { category: "launcher" })
    id: root

    property var controller: null
    property var targetResolver: null

    function _adjustSelectedValue(delta) {
        var result = root.targetResolver ? root.targetResolver.selectedActionTarget() : null;
        if (!result) {
            tracer.debug("adjustSelectedValue", function() { return { reason: "no target", delta: delta }; });
            return false;
        }

        if (result.control) {
            var controlResult = ActionRegistry.executeRecipe([["adjust-control", { delta: delta }]], result, root.controller);
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
                if (root.controller && root.controller.isInTree() && root.controller.currentTreeKey && result.switchActions && root.controller.selectedIndex >= 0) {
                    var treeRow = root.controller.findTreeRowData(root.controller.currentTreeKey);
                    if (treeRow)
                        treeRow.switchState = result.switchState;
                    if (typeof root.controller.treeSwitchRefreshRequested === "function")
                        root.controller.treeSwitchRefreshRequested(root.controller.selectedIndex);
                }
                return true;
            }
        }
        tracer.debug("adjustSelectedValue", function() { return { reason: "no action activated", delta: delta, targetId: result.id || result.nodeId || "" }; });
        return false;
    }

    readonly property var adjustSelectedValue: prof.fn("adjustSelectedValue", _adjustSelectedValue)

    function toggleSelectedMute() {
        var result = root.targetResolver ? root.targetResolver.selectedActionTarget() : null;
        if (!result) {
            tracer.debug("toggleSelectedMute", function() { return { reason: "no target" }; });
            return false;
        }
        if (result.switchActions && (result.switchActions.toggle || result.switchActions.on || result.switchActions.off)) {
            var toggleResult = ActionRegistry.executeRecipe([["toggle"]], result, root.controller);
            tracer.info("toggleSelectedMute", function() { return { targetId: result.id || result.nodeId || "", success: !!toggleResult.success }; });
            return !!toggleResult.success;
        }
        tracer.debug("toggleSelectedMute", function() { return { reason: "no switch actions", targetId: result.id || result.nodeId || "" }; });
        return false;
    }

    function _refreshSwitchResult(result, action) {
        var payload = action && action.payload || {};
        // Check action.state first, then fall back to payload.state
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
