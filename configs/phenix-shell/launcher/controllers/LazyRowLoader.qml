import QtQml
import qs.services

QtObject {
    readonly property var tracer: Logger.scope("launcher.lazyLoader", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.lazyLoader", { category: "launcher" })
    id: root

    property var controller: null
    property var navigationTargets: null
    property var expandedNodeIds: ({})

    function loadLazyChildren(key) {
        if (!root.controller || !root.navigationTargets) {
            tracer.debug("loadLazyChildren", function() { return { key: key, reason: "no controller/targets" }; });
            return;
        }
        var treeRow = root.navigationTargets.findRowByKey(root.controller.results, key);
        if (!treeRow || !treeRow.lazy) {
            tracer.debug("loadLazyChildren", function() { return { key: key, reason: !treeRow ? "not found" : "not lazy" }; });
            return;
        }
        var parentResult = root.navigationTargets.findParentResultByKey(root.controller.results, key);
        if (!parentResult) return;
        var sourceId = treeRow.source || parentResult.source || parentResult.backendId || "";
        var backend = null;
        for (var i = 0; i < (root.controller.backends || []).length; i += 1) {
            if (root.controller.backends[i] && root.controller.backendId(root.controller.backends[i]) === sourceId) {
                backend = root.controller.backends[i];
                break;
            }
        }
        if (!backend || typeof backend.scanDirectory !== "function") {
            tracer.debug("loadLazyChildren", function() { return { key: key, reason: "no backend or scanDirectory" }; });
            return;
        }
        var path = (treeRow.meta && treeRow.meta.path) || "";
        if (!path && treeRow.id && treeRow.id.indexOf("file:") === 0)
            path = treeRow.id.slice(5);
        if (!path) {
            tracer.debug("loadLazyChildren", function() { return { key: key, reason: "no path" }; });
            return;
        }
        tracer.info("loadLazyChildren", function() { return { key: key, path: path, sourceId: sourceId }; });
        backend.scanDirectory(path, function(children) {
            tracer.trace("loadLazyChildren", function() { return { key: key, childrenLoaded: (children || []).length }; });
            treeRow.children = children;
            treeRow.lazy = false;
            root.expandedNodeIds[treeRow.nodeId || treeRow.id] = true;
            if (root.controller && typeof root.controller.searchRequested === "function")
                root.controller.searchRequested(root.controller.query, root.controller.generation);
        });
    }
}
