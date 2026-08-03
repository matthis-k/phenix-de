pragma ComponentBehavior: Bound

import QtQuick
import QtQml
import QtQml.Models
import qs.components

QtObject {
    id: root

    property var controller: null
    property var coordinator: null

    readonly property int projectionRevision: resultProjection.revision
    readonly property var snapshotChanges: resultProjection.changes
    readonly property var snapshotChangeSummary: resultProjection.changeSummary

    SnapshotProjection {
        id: resultProjection
        keyOf: function(item) { return item ? item.key || "" : ""; }
        equals: function(previous, next) {
            if (previous === next)
                return true;
            if (!previous || !next)
                return false;
            return previous.payload === next.payload
                && previous.animationRole === next.animationRole
                && previous.estimatedHeight === next.estimatedHeight;
        }
    }

    function keyForResult(result) {
        if (!result)
            return "";
        if (result.key)
            return String(result.key);
        if (result.id)
            return String(result.id);
        if (result.nodeId)
            return String(result.nodeId);
        if (result.metadata && result.metadata.nodeId)
            return String(result.metadata.nodeId);
        return "";
    }

    function adaptResults(results) {
        const items = [];
        const seen = ({});

        for (let i = 0; i < results.length; i += 1) {
            const result = results[i];
            const key = keyForResult(result);

            if (!key) {
                console.warn("[LauncherCoordinatorAdapter] result missing stable key at rank", i);
                continue;
            }

            if (seen[key]) {
                console.warn("[LauncherCoordinatorAdapter] duplicate result key:", key);
                continue;
            }

            seen[key] = true;
            items.push({
                key: key,
                payload: result,
                rank: i,
                animationRole: result.animationRole || "",
                estimatedHeight: 56
            });
        }

        return items;
    }

    function applySnapshot(context) {
        if (!root.controller || !root.coordinator)
            return;

        const ctx = Object.assign({}, context || {}, {
            queryRevision: root.controller.queryRevision,
            generation: root.controller.generation
        });
        const items = adaptResults(root.controller.results || []);
        const committed = resultProjection.apply(items, ctx.reason || "query");

        ctx.projectionRevision = resultProjection.revision;
        if (committed) {
            ctx.changeSet = resultProjection.changes;
            ctx.changeSummary = resultProjection.changeSummary;
        }

        root.coordinator.applySnapshot(resultProjection.snapshot || [], ctx);
    }

    function resetTransientState() {
        if (root.coordinator)
            root.coordinator.resetTransientState();
    }

    function resetModel() {
        resultProjection.reset([]);
        if (root.coordinator)
            root.coordinator.resetModel();
    }

    function debugState(extra) {
        var state = root.coordinator ? root.coordinator.debugState(extra) : {};
        state.projection = {
            revision: resultProjection.revision,
            ready: resultProjection.ready,
            changes: resultProjection.changeSummary
        };
        return state;
    }
}
