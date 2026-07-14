import qs.services

LauncherBackendBase {
    readonly property var tracer: Logger.scope("launcher.streamingBackend", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.streamingBackend", { category: "launcher" })
    id: root

    property string pendingCompositeQuery: ""
    property string compositeQuery: ""
    property var streamItemsById: ({})
    property var streamOrder: []
    readonly property var compositeResults: streamOrder.map(function(id) { return streamItemsById[id]; }).filter(Boolean)

    function resetStream(items) {
        tracer.trace("resetStream", function() { return { backendId: root.backendId, itemCount: (items || []).length }; });
        root.streamItemsById = {};
        root.streamOrder = [];
        root.addStreamItems(items || []);
    }

    function addStreamItems(items) {
        for (var i = 0; i < (items || []).length; i += 1)
            root.upsertStreamItem(items[i]);
    }

    function upsertStreamItem(item) {
        if (!item)
            return;
        var id = streamItemId(item);
        if (!id)
            return;
        var byId = Object.assign({}, root.streamItemsById);
        byId[id] = item;
        root.streamItemsById = byId;
        if (root.streamOrder.indexOf(id) < 0)
            root.streamOrder = root.streamOrder.concat([id]);
    }

    function _applyStreamUpdate(update) {
        if (!update) {
            tracer.debug("applyStreamUpdate", function() { return { reason: "no update" }; });
            return;
        }
        if (Array.isArray(update)) {
            tracer.trace("applyStreamUpdate", function() { return { op: "reset-array", count: update.length }; });
            root.resetStream(update);
            return;
        }
        tracer.trace("applyStreamUpdate", function() { return { op: update.op, backendId: root.backendId }; });
        if (update.op === "reset") {
            root.resetStream(update.items || []);
            return;
        }
        if (update.op === "clear")
            root.resetStream([]);
    }

    readonly property var applyStreamUpdate: prof.fn("applyStreamUpdate", _applyStreamUpdate)

    function streamItemId(item) {
        return item && (item.id || item.key || (item.metadata && item.metadata.path) || item.title) || "";
    }
}
