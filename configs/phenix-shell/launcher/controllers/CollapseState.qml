import QtQml
import qs.services

QtObject {
    readonly property var tracer: Logger.scope("launcher.collapse", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.collapse", { category: "launcher" })
    id: root

    property var expandedNodeIds: ({})
    property var collapsedResultIndices: ({})
    property var controller: null

    function toggleCollapseResultTree(selectedIndex) {
        if (selectedIndex >= 0) {
            var collapseResult = (typeof controller !== "undefined" && controller && controller.results) ? controller.results[selectedIndex] : null;
            if (!collapseResult || !collapseResult.children || collapseResult.children.length === 0) {
                tracer.debug("toggleCollapse", function() { return { index: selectedIndex, reason: "no children" }; });
                return false;
            }
            collapsedResultIndices[selectedIndex] = true;
            tracer.trace("toggleCollapse", function() { return { index: selectedIndex, title: collapseResult.title, childCount: collapseResult.children.length }; });
            if (controller)
                controller.collapseResultExpanded(selectedIndex);
            return true;
        }
        return false;
    }

    function toggleExpandResultTree(selectedIndex) {
        if (selectedIndex >= 0) {
            var expandResult = (typeof controller !== "undefined" && controller && controller.results) ? controller.results[selectedIndex] : null;
            if (!expandResult || !expandResult.children || expandResult.children.length === 0) {
                tracer.debug("toggleExpand", function() { return { index: selectedIndex, reason: "no children" }; });
                return false;
            }
            delete collapsedResultIndices[selectedIndex];
            tracer.trace("toggleExpand", function() { return { index: selectedIndex, title: expandResult.title, childCount: expandResult.children.length }; });
            if (controller)
                controller.expandResultExpanded(selectedIndex);
            return true;
        }
        return false;
    }

    function preserveCollapsedState(oldResults, newResults, rowKeyFn) {
        var previousCollapsedByKey = {};
        for (var previousIndex = 0; previousIndex < oldResults.length; previousIndex += 1) {
            var previousKey = rowKeyFn(oldResults[previousIndex]);
            if (previousKey)
                previousCollapsedByKey[previousKey] = !!collapsedResultIndices[previousIndex];
        }
        var newCollapsed = {};
        for (var i = 0; i < newResults.length; i += 1) {
            var key = rowKeyFn(newResults[i]);
            if (newResults[i].alwaysExpanded !== false) {
            } else if (key && previousCollapsedByKey[key] !== undefined) {
                if (previousCollapsedByKey[key])
                    newCollapsed[i] = true;
            } else {
                newCollapsed[i] = true;
            }
        }
        return newCollapsed;
    }
}
