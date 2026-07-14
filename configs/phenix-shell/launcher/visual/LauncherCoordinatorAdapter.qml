pragma ComponentBehavior: Bound

import QtQuick
import QtQml
import QtQml.Models

QtObject {
    id: root

    property var controller: null
    property var coordinator: null

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

        const items = adaptResults(root.controller.results || []);

        const ctx = Object.assign({}, context || {}, {
            queryRevision: root.controller.queryRevision,
            generation: root.controller.generation
        });

        root.coordinator.applySnapshot(items, ctx);
    }

    function resetTransientState() {
        if (root.coordinator)
            root.coordinator.resetTransientState();
    }

    function resetModel() {
        if (root.coordinator)
            root.coordinator.resetModel();
    }

    function debugState(extra) {
        return root.coordinator ? root.coordinator.debugState(extra) : {};
    }
}
