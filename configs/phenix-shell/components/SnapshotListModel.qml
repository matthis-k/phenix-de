import QtQuick
import QtQml

// Reconciles keyed snapshots into a stable ListModel. Delegates receive `key`
// and `payload` roles and keep their identity across inserts, removals and moves.
QtObject {
    id: root

    property var items: []
    property var keyOf: function(item) {
        if (!item)
            return "";
        return item.key || item.id || item.nodeId || "";
    }
    property var equals: null
    property int sourceRevision: 0
    property bool coalesce: true

    property ListModel model: ListModel {
        id: listModel
        dynamicRoles: true
    }

    readonly property int revision: projection.revision
    readonly property var changes: projection.changes
    readonly property var changeSummary: projection.changeSummary

    signal snapshotApplied(var changes)

    ChangeBatch {
        id: invalidations
        onCommitted: root.applyNow()
    }

    SnapshotProjection {
        id: projection
        keyOf: root.keyOf
        equals: root.equals
    }

    onItemsChanged: root.scheduleApply("items")
    onKeyOfChanged: root.scheduleApply("key-selector")
    onSourceRevisionChanged: root.scheduleApply("source-revision")

    Component.onCompleted: root.scheduleApply("initial")

    function scheduleApply(reason) {
        if (!root.coalesce) {
            root.applyNow();
            return;
        }
        invalidations.invalidate(reason || "items");
    }

    function applyNow() {
        var committed = projection.apply(root.items || [], "items");
        if (!committed)
            return;
        root.reconcile(projection.snapshot || [], projection.changes);
        root.snapshotApplied(projection.changes);
    }

    function reconcile(nextItems, changeSet) {
        var changes = changeSet || { removed: [], updated: [] };
        var updatedKeys = {};
        var i;

        for (i = 0; i < changes.updated.length; i += 1)
            updatedKeys[String(changes.updated[i].key)] = true;

        for (i = 0; i < changes.removed.length; i += 1) {
            var removedIndex = root.indexOfKey(changes.removed[i].key);
            if (removedIndex >= 0)
                listModel.remove(removedIndex);
        }

        for (i = 0; i < nextItems.length; i += 1) {
            var item = nextItems[i];
            var key = String(root.keyOf(item, i));
            var existingIndex = root.indexOfKey(key);

            if (existingIndex < 0) {
                listModel.insert(i, { key: key, payload: item });
                continue;
            }

            if (updatedKeys[key] || listModel.get(existingIndex).payload !== item)
                listModel.setProperty(existingIndex, "payload", item);
            if (existingIndex !== i)
                listModel.move(existingIndex, i, 1);
        }
    }

    function indexOfKey(key) {
        for (var i = 0; i < listModel.count; i += 1) {
            if (String(listModel.get(i).key) === String(key))
                return i;
        }
        return -1;
    }

    function reset() {
        invalidations.reset();
        listModel.clear();
        projection.reset([]);
    }
}
