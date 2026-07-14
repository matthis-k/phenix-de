pragma ComponentBehavior: Bound

import QtQuick
import QtQml
import QtQml.Models
import qs.services
import qs.animations as Animations

QtObject {
    readonly property var tracer: Logger.scope("launcher.visualCoordinator", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.visualCoordinator", { category: "launcher" })
    id: root

    enum AnimationMode {
        None,
        Light,
        Full
    }

    property Animations.TransitionListCoordinator coordinator: Animations.TransitionListCoordinator {}
    readonly property var model: coordinator.model
    property alias animationMode: coordinator.animationMode
    property alias recentlyRemovedTtl: coordinator.recentlyRemovedTtl
    property alias debugEnabled: coordinator.debugEnabled
    property alias snapshotSerial: coordinator.snapshotSerial
    property alias lastOperations: coordinator.lastOperations
    property alias hasActiveItems: coordinator.hasActiveItems

    signal snapshotApplied()

    Connections {
        target: coordinator
        function onSnapshotApplied() { root.snapshotApplied(); }
    }

    function applySnapshot(results, mode) {
        tracer.info("applySnapshot", function() { return { resultCount: (results || []).length, mode: mode, reason: mode === VisualResultCoordinator.AnimationMode.None ? "reset" : "query" }; });
        coordinator.applySnapshot(adaptResults(results || []), { reason: mode === VisualResultCoordinator.AnimationMode.None ? "reset" : "query" });
    }

    function adaptResults(results) {
        const items = [];
        for (let i = 0; i < results.length; i += 1) {
            const result = results[i];
            const key = keyForResult(result);
            if (key)
                items.push({ key: key, payload: result, animationRole: result.animationRole || "" });
        }
        return items;
    }

    function keyForResult(row) {
        if (!row) return "";
        if (row.key) return String(row.key);
        if (row.id) return String(row.id);
        if (row.nodeId) return String(row.nodeId);
        if (row.metadata && row.metadata.nodeId) return String(row.metadata.nodeId);
        return "";
    }

    function animationModeForSnapshot(query, contextKey) {
        tracer.trace("animationModeForSnapshot", function() { return { queryLen: (query || "").length, contextKey: contextKey || "" }; });
        return coordinator.policy.modeForSnapshot({
            inputText: query || "",
            previousInputText: coordinator._lastInputText,
            contextKey: contextKey || "",
            previousContextKey: coordinator._lastContextKey,
            previousItemCount: coordinator.model.count,
            activeItemCount: coordinator.model.count,
            timeSinceLastSnapshot: coordinator.timeSinceLastSnapshot()
        });
    }

    function resetTransientState() { coordinator.resetTransientState(); }
    function resetModel() { coordinator.resetModel(); }
    function debugState(extra) { return coordinator.debugState(extra); }
}
