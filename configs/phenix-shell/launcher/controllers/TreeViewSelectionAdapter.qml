import QtQuick
import QtQml
import QtQml.Models
import qs.services

QtObject {
    readonly property var tracer: Logger.scope("launcher.treeAdapter", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.treeAdapter", { category: "launcher" })
    id: root

    property var controller: null
    property var resultTreeViews: ({})
    property var resultView: null
    property var currentTreeView: null
    property string currentTreeKey: ""
    property int treeVisualRow: -1

    readonly property bool inTree: currentTreeView !== null && treeVisualRow >= 0

    function registerTreeView(index, treeView) {
        if (index < 0 || !treeView) return;
        tracer.debug("registerTreeView", function() { return { index: index, rows: treeView.rows, currentKey: currentTreeKey }; });
        resultTreeViews[index] = treeView;
        if (index === (root.controller ? root.controller.selectedIndex : -1) && currentTreeKey)
            root.syncSelection(index, currentTreeKey);
    }

    function resolveTreeViewAtIndex(index) {
        if (resultTreeViews[index]) {
            tracer.debug("resolveTreeView", function() { return { index: index, cache: "hit", rows: resultTreeViews[index].rows }; });
            return resultTreeViews[index];
        }
        if (!resultView || index < 0) {
            tracer.debug("resolveTreeView", function() { return { index: index, cache: "miss", resultView: !!resultView }; });
            return null;
        }
        var loader = resultView.itemAt(index);
        if (loader && loader.item && loader.item.treeView) {
            resultTreeViews[index] = loader.item.treeView;
            tracer.debug("resolveTreeView", function() { return { index: index, cache: "resolved", rows: loader.item.treeView.rows }; });
            return loader.item.treeView;
        }
        return null;
    }

    function _syncSelection(parentIndex, key) {
        currentTreeView = resolveTreeViewAtIndex(parentIndex);
        currentTreeKey = key;
        treeVisualRow = currentTreeView ? root.findVisualRow(currentTreeView, key) : -1;
        tracer.trace("syncSelection", function() { return { parentIndex: parentIndex, key: key, hasTreeView: !!currentTreeView, visualRow: treeVisualRow }; });
        if (!currentTreeView || treeVisualRow < 0)
            return false;
        var idx = currentTreeView.index(treeVisualRow, 0);
        if (idx.valid) {
            currentTreeView.selectionModel.setCurrentIndex(idx, ItemSelectionModel.SelectCurrent);
            return true;
        }
        return false;
    }

    readonly property var syncSelection: prof.fn("syncSelection", _syncSelection)

    function findVisualRow(treeView, key) {
        if (!treeView || !treeView.model || !key) return -1;
        for (var row = 0; row < treeView.rows; row += 1) {
            var idx = treeView.index(row, 9);
            if (idx.valid && treeView.model.data(idx, "display") === key)
                return row;
        }
        return -1;
    }

    function clear() {
        if (currentTreeView && currentTreeView.selectionModel)
            currentTreeView.selectionModel.clearCurrentIndex();
        currentTreeView = null;
        currentTreeKey = "";
        treeVisualRow = -1;
    }

    function enterTree(result, treeView) {
        if (!result || !treeView || treeView.rows <= 0) return false;
        currentTreeView = treeView;
        treeVisualRow = 0;
        var idx = treeView.index(0, 0);
        if (!idx.valid)
            return false;
        treeView.selectionModel.setCurrentIndex(idx, ItemSelectionModel.SelectCurrent);
        return true;
    }

    function moveInTree(delta) {
        if (!currentTreeView) return false;
        var newRow = treeVisualRow + delta;
        if (newRow < 0) {
            root.clear();
            return false;
        }
        if (newRow >= currentTreeView.rows) {
            root.clear();
            if (root.controller && root.controller.results && root.controller.results.length > 0)
                root.controller.selectedIndex = (root.controller.selectedIndex + 1) % root.controller.results.length;
            if (root.controller)
                root.controller.selectedActionIndex = 0;
            return false;
        }
        treeVisualRow = newRow;
        var idx = currentTreeView.index(newRow, 0);
        if (!idx.valid) {
            root.clear();
            return false;
        }
        currentTreeView.selectionModel.setCurrentIndex(idx, ItemSelectionModel.SelectCurrent);
        return true;
    }

    function _treeCollapseSelected() {
        if (!currentTreeView) {
            tracer.debug("treeCollapseSelected", function() { return { reason: "no tree" }; });
            return false;
        }
        if (treeVisualRow >= 0) {
            if (currentTreeView.isExpanded(treeVisualRow)) {
                if (typeof currentTreeView.collapseAnimated === "function")
                    currentTreeView.collapseAnimated(treeVisualRow);
                else
                    currentTreeView.collapse(treeVisualRow);
                tracer.trace("treeCollapseSelected", function() { return { action: "collapseCurrent", row: treeVisualRow, key: currentTreeKey }; });
                return true;
            }
            var idx = currentTreeView.index(treeVisualRow, 0);
            if (!idx.valid)
                return false;
            var parentIdx = currentTreeView.model.parent(idx);
            if (parentIdx.valid) {
                if (typeof currentTreeView.collapseAnimated === "function")
                    currentTreeView.collapseAnimated(parentIdx.row);
                else
                    currentTreeView.collapse(parentIdx.row);
                currentTreeView.selectionModel.setCurrentIndex(parentIdx, ItemSelectionModel.SelectCurrent);
                treeVisualRow = parentIdx.row;
                var keyIdx = currentTreeView.index(parentIdx.row, 9);
                currentTreeKey = keyIdx.valid ? currentTreeView.model.data(keyIdx, "display") : "";
                tracer.trace("treeCollapseSelected", function() { return { action: "collapseParent", row: treeVisualRow, key: currentTreeKey }; });
                return true;
            }
        }
        tracer.debug("treeCollapseSelected", function() { return { action: "notHandled", row: treeVisualRow, key: currentTreeKey }; });
        return false;
    }

    readonly property var treeCollapseSelected: prof.fn("treeCollapseSelected", _treeCollapseSelected)

    function _treeExpandSelected() {
        if (!currentTreeView || treeVisualRow < 0) {
            tracer.debug("treeExpandSelected", function() { return { reason: "no row", row: treeVisualRow, key: currentTreeKey }; });
            return false;
        }
        var idx = currentTreeView.index(treeVisualRow, 0);
        var hasChildren = typeof currentTreeView.model.hasChildren === "function"
            ? currentTreeView.model.hasChildren(idx)
            : false;
        if (!hasChildren) {
            tracer.debug("treeExpandSelected", function() { return { reason: "leaf", row: treeVisualRow, key: currentTreeKey }; });
            return false;
        }
        if (typeof currentTreeView.expandAnimated === "function")
            currentTreeView.expandAnimated(treeVisualRow);
        else
            currentTreeView.expand(treeVisualRow);
        tracer.trace("treeExpandSelected", function() { return { action: "expanded", row: treeVisualRow, key: currentTreeKey }; });
        return true;
    }

    readonly property var treeExpandSelected: prof.fn("treeExpandSelected", _treeExpandSelected)

    function treeToggleSelected() {
        if (!currentTreeView || treeVisualRow < 0) return false;
        if (currentTreeView.isExpanded(treeVisualRow))
            return root.treeCollapseSelected();
        else
            return root.treeExpandSelected();
    }
}
