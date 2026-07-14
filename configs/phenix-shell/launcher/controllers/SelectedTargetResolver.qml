import QtQml
import qs.services

QtObject {
    readonly property var tracer: Logger.scope("launcher.targetResolver", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.targetResolver", { category: "launcher" })
    id: root

    property var controller: null

    function selectedActionTarget() {
        if (!root.controller) {
            tracer.trace("selectedActionTarget", function() { return { reason: "no controller" }; });
            return null;
        }

        if (root.controller.isInTree() && root.controller.currentTreeKey) {
            var treeRow = root.controller.findTreeRowData(root.controller.currentTreeKey);
            if (treeRow) {
                var parent = root.controller.results ? root.controller.results[root.controller.selectedIndex] : null;
                return Object.assign({}, treeRow, {
                    source: treeRow.source || (parent ? parent.source || parent.backendId : ""),
                    category: treeRow.category || (parent ? parent.category : "")
                });
            }
        }
        return root.controller.selectedResult();
    }

    function _activateTreeRowByKey(key, actionId) {
        if (!root.controller) {
            tracer.debug("activateTreeRowByKey", function() { return { key: key, reason: "no controller" }; });
            return false;
        }
        var row = root.controller.findTreeRowData(key);
        if (!row) return false;
        var parent = root.controller.findParentResultByKey(key);
        var target = Object.assign({}, row, {
            source: row.source || (parent ? parent.source || parent.backendId : ""),
            category: row.category || (parent ? parent.category : "")
        });
        if (actionId) {
            var activated = root.controller.activateResultAction(target, actionId);
            if (activated && target.switchActions && root.controller.selectedIndex >= 0) {
                row.switchState = target.switchState;
                if (typeof root.controller.treeSwitchRefreshRequested === "function")
                    root.controller.treeSwitchRefreshRequested(root.controller.selectedIndex);
            }
            return activated;
        }
        if (root.controller.actions && typeof root.controller.actions.activateWithConfirmation === "function") {
            return root.controller.actions.activateWithConfirmation(target, function() {
                return root.controller.applyIntent(target, target.enter);
            });
        }
        return root.controller.applyIntent(target, target.enter);
    }

    readonly property var activateTreeRowByKey: prof.fn("activateTreeRowByKey", _activateTreeRowByKey)

    function treeActivateCurrent() {
        if (root.controller && root.controller.currentTreeKey)
            return root.activateTreeRowByKey(root.controller.currentTreeKey, null);
        return false;
    }
}
