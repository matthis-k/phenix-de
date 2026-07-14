import QtQuick
import QtQml
import QtQml.Models
import qs.services
Item {
    readonly property var tracer: Logger.scope("launcher.navState", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.navState", { category: "launcher" })
    id: root

    property var controller: null
    property var results: []
    property string resultsQuery: ""
    property int selectedIndex: 0
    property int selectedActionIndex: 0
    property var lastQuery: null
    property var lastDirective: null
    property var lastEvaluatedRoot: null

    readonly property var expandedNodeIds: collapseState.expandedNodeIds
    readonly property var collapsedResultIndices: collapseState.collapsedResultIndices
    readonly property var currentTreeView: treeAdapter.currentTreeView
    readonly property string currentTreeKey: treeAdapter.currentTreeKey
    readonly property int treeVisualRow: treeAdapter.treeVisualRow
    readonly property bool inTree: treeAdapter.inTree
    property var resultTreeViews: ({})
    property var resultView: null
    property string activeNodeKey: ""

    NavigationTargets {
        id: targets
        controller: root.controller
    }

    TreeViewSelectionAdapter {
        id: treeAdapter
        controller: root.controller
        property alias resultTreeViews: root.resultTreeViews
        property alias resultView: root.resultView
    }

    CollapseState {
        id: collapseState
        controller: root.controller
    }

    LazyRowLoader {
        id: lazyLoader
        controller: root.controller
        navigationTargets: targets
        expandedNodeIds: collapseState.expandedNodeIds
    }

    function rowKey(row) {
        return targets.rowKey(row);
    }

    function walkRows(rows, visitor) {
        targets.walkRows(rows, visitor);
    }

    function findRowByKey(rows, key) {
        return targets.findRowByKey(rows, key);
    }

    function findParentResultByKey(key) {
        return targets.findParentResultByKey(results, key);
    }

    function findInChildren(row, key) {
        return targets.findInChildren(row, key);
    }

    function hasActivation(row) {
        if (!row)
            return false;

        if (row.selectable === false)
            return false;

        return !!((row.actions && row.actions.length > 0)
            || row.hasAction
            || row.canExecuteNow
            || row.executable
            || row.switchActions
            || row.control
            || row.lazy
            || row.filterable);
    }

    function isSelectable(row) {
        if (!root.hasActivation(row))
            return false;

        if (root.queryIsEmptyForSelection())
            return true;

        return (row.ownScore || 0) > 0
            || !!row.ownVisible
            || row.explicitBrowseChild === true;
    }

    function isRowSelectable(row) {
        return root.isSelectable(row);
    }

    function selectedResult() {
        return selectedIndex >= 0 ? results[selectedIndex] : null;
    }

    function clearSearchOutputState() {
        lastQuery = null;
        lastDirective = null;
        lastEvaluatedRoot = null;
    }

    function clearResults() {
        tracer.info("clearResults", function() { return { prevCount: results.length }; });
        results = [];
        resultsQuery = "";
        resetSelection();
    }

    function refreshResults() {
        results = results.slice();
    }

    function resetSelection() {
        tracer.trace("resetSelection", function() { return {}; });
        selectedIndex = -1;
        selectedActionIndex = 0;
        treeAdapter.clear();
    }

    function resetTreeNavigation() {
        treeAdapter.clear();
        activeNodeKey = "";
    }

    function queryIsEmptyForSelection() {
        if (lastQuery && lastQuery.isEmpty !== undefined)
            return !!lastQuery.isEmpty;
        return !controller || !controller.query || controller.query.trim().length === 0;
    }

    function _setResults(newResults, sourceQuery) {
        tracer.info("setResults", function() { return { count: (newResults || []).length, query: sourceQuery, prevCount: results.length, sameQuery: (sourceQuery || "") === (resultsQuery || "") }; });
        var sameQuery = (sourceQuery || "") === (resultsQuery || "");
        var previousActiveKey = sameQuery ? activeNodeKey : "";
        var oldResults = results;

        for (var previousIndex = 0; previousIndex < oldResults.length; previousIndex += 1) {
            var previousKey = targets.rowKey(oldResults[previousIndex]);
            if (!previousActiveKey && sameQuery && previousIndex === selectedIndex)
                previousActiveKey = previousKey;
        }

        resultTreeViews = {};
        results = newResults || [];
        resultsQuery = sourceQuery || "";
        selectedActionIndex = 0;
        treeAdapter.clear();
        collapseState.collapsedResultIndices = collapseState.preserveCollapsedState(
            oldResults, results, function(r) { return targets.rowKey(r); }
        );

        var flatTargets = targets.flatten(results, collapseState.collapsedResultIndices, root.isRowSelectable);
        var selectedTarget = previousActiveKey
            ? flatTargets.find(function(t) { return t.key === previousActiveKey; })
            : null;
        tracer.debug("setResults", function() { return { flatTargets: flatTargets.length, selectedKey: (selectedTarget || flatTargets[0] || {}).key, prevActiveKey: previousActiveKey }; });
        root.applyNavigationTarget(selectedTarget || (flatTargets.length > 0 ? flatTargets[0] : null));
    }

    readonly property var setResults: prof.fn("setResults", _setResults)

    function registerResultTreeView(index, treeView) {
        treeAdapter.registerTreeView(index, treeView);
    }

    function _moveSelection(delta) {
        tracer.trace("moveSelection", function() { return { delta: delta, activeNodeKey: activeNodeKey, results: results.length }; });
        var flatTargets = targets.flatten(results, collapseState.collapsedResultIndices, root.isRowSelectable);
        var nextTarget = targets.stepTarget(flatTargets, activeNodeKey, delta);
        if (!nextTarget) {
            tracer.debug("moveSelection", function() { return { action: "clear", reason: "no targets", delta: delta }; });
            root.applyNavigationTarget(null);
            return;
        }
        root.applyNavigationTarget(nextTarget);
    }

    readonly property var moveSelection: prof.fn("moveSelection", _moveSelection)

    function navigationTargets() {
        return targets.flatten(results, collapseState.collapsedResultIndices, root.isRowSelectable);
    }

    function resolveTreeViewAtIndex(index) {
        return treeAdapter.resolveTreeViewAtIndex(index);
    }

    function _applyNavigationTarget(target) {
        if (!target) {
            tracer.debug("applyNavigationTarget", function() { return { action: "clear", reason: "null target" }; });
            selectedIndex = -1;
            activeNodeKey = "";
            treeAdapter.clear();
            return;
        }
        var isTree = target.isTreeChild || target.depth > 0 || target.treeDepth > 0;
        tracer.trace("applyNavigationTarget", function() { return { key: target.key, parentIndex: target.parentIndex, depth: target.depth || target.treeDepth, isTree: isTree }; });
        selectedIndex = target.parentIndex;
        selectedActionIndex = 0;
        activeNodeKey = target.key;
        if (isTree) {
            treeAdapter.syncSelection(target.parentIndex, target.key);
        } else {
            treeAdapter.clear();
        }
    }

    readonly property var applyNavigationTarget: prof.fn("applyNavigationTarget", _applyNavigationTarget)

    function syncTreeSelection(parentIndex, key) {
        return treeAdapter.syncSelection(parentIndex, key);
    }

    function findTreeVisualRow(treeView, key) {
        return treeAdapter.findVisualRow(treeView, key);
    }

    function enterTree(result, treeView) {
        return treeAdapter.enterTree(result, treeView);
    }

    function exitTree() {
        treeAdapter.clear();
    }

    function isInTree() {
        return treeAdapter.inTree;
    }

    function moveInTree(delta) {
        treeAdapter.moveInTree(delta);
    }

    function treeCollapseSelected() {
        if (root.isInTree()) {
            return treeAdapter.treeCollapseSelected();
        } else {
            return collapseState.toggleCollapseResultTree(selectedIndex);
        }
    }

    function treeExpandSelected() {
        if (root.isInTree()) {
            return treeAdapter.treeExpandSelected();
        } else {
            return collapseState.toggleExpandResultTree(selectedIndex);
        }
    }

    function toggleCollapseResultTree() {
        return root.treeCollapseSelected();
    }

    function toggleExpandResultTree() {
        return root.treeExpandSelected();
    }

    function treeToggleSelected() {
        return treeAdapter.treeToggleSelected();
    }

    function findTreeRowData(key) {
        return key ? targets.findRowByKey(results, key) : null;
    }

    function loadLazyChildren(key) {
        lazyLoader.loadLazyChildren(key);
    }
}
