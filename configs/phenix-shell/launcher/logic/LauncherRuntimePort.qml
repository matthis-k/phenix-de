import QtQml

// Narrow adapter over LauncherController for command execution. The executor no
// longer receives the full controller surface or its compatibility facade.
QtObject {
    id: root

    required property var controller

    readonly property string query: controller ? controller.query || "" : ""
    readonly property bool confirmationSatisfied: !!(controller && controller.confirmationSatisfied)

    function activationContext() {
        return {
            policyResolver: controller ? controller.policyResolver : null,
            directive: controller ? controller.lastDirective : null,
            lastDirective: controller ? controller.lastDirective : null,
            route: null
        };
    }

    function replaceQuery(text) {
        if (!controller || typeof controller.queryReplacementRequested !== "function")
            return false;
        controller.queryReplacementRequested(text);
        return true;
    }

    function backendFor(id) {
        var backends = controller && controller.backends || [];
        for (var i = 0; i < backends.length; i += 1) {
            var backend = backends[i];
            var backendId = controller && typeof controller.backendId === "function"
                ? controller.backendId(backend)
                : backend && backend.backendId || "";
            if (backend && backendId === id)
                return BackendContract.adapt(backend, i);
        }
        return null;
    }

    function refreshSwitchResult(target, action) {
        if (!controller || !controller.actions)
            return false;
        controller.actions.refreshSwitchResult(target, action);
        return true;
    }

    function refreshControlResult(target, value) {
        if (!controller || !target || !target.control)
            return false;

        target.control = Object.assign({}, target.control, { value: Number(value) });

        if (controller.isInTree() && controller.currentTreeKey && controller.selectedIndex >= 0) {
            var treeRow = controller.findTreeRowData(controller.currentTreeKey);
            if (treeRow && treeRow.control) {
                treeRow.control = Object.assign({}, treeRow.control, { value: Number(value) });
                if (typeof controller.treeSwitchRefreshRequested === "function")
                    controller.treeSwitchRefreshRequested(controller.selectedIndex);
            }
        }

        controller.resultsRefreshRequested();
        Qt.callLater(function() {
            if (controller && typeof controller.searchRequested === "function")
                controller.searchRequested(controller.query, controller.generation);
        });
        return true;
    }
}
