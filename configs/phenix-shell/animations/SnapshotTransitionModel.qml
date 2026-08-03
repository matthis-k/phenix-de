import QtQml
import qs.components

// Composes snapshot projection with phase-based animated reconciliation.
// Consumers render `model` through TransitionListRow.
QtObject {
    id: root

    property var items: []
    property var keyOf: function(item) {
        if (!item)
            return "";
        return item.key || item.id || item.nodeId || "";
    }
    property var equals: null
    property var context: ({})
    property int sourceRevision: 0
    property bool coalesce: true
    property int estimatedRowHeight: 56
    property bool hardReplaceSnapshots: false
    property bool debugEnabled: false

    readonly property var model: transitionCoordinator.model
    readonly property var coordinator: transitionCoordinator
    readonly property int revision: projection.revision
    readonly property var snapshot: projection.snapshot
    readonly property var changes: projection.changes
    readonly property var changeSummary: projection.changeSummary
    readonly property real contentHeight: transitionCoordinator.contentHeight
    readonly property bool hasActiveItems: transitionCoordinator.hasActiveItems
    readonly property int animationMode: transitionCoordinator.animationMode

    signal snapshotApplied(var changes)

    ChangeBatch {
        id: invalidations
        onCommitted: function(revision, reasons) {
            root.applyNow(reasons);
        }
    }

    SnapshotProjection {
        id: projection
        keyOf: root.keyOf
        equals: root.equals
    }

    TransitionListCoordinator {
        id: transitionCoordinator
        estimatedRowHeight: root.estimatedRowHeight
        hardReplaceSnapshots: root.hardReplaceSnapshots
        debugEnabled: root.debugEnabled
    }

    onItemsChanged: root.scheduleApply("items")
    onKeyOfChanged: root.scheduleApply("key-selector")
    onContextChanged: root.scheduleApply("context")
    onSourceRevisionChanged: root.scheduleApply("source-revision")

    Component.onCompleted: root.scheduleApply("initial")

    function scheduleApply(reason) {
        if (!root.coalesce) {
            root.applyNow([reason || "items"]);
            return;
        }
        invalidations.invalidate(reason || "items");
    }

    function applyNow(reasons) {
        const committed = projection.apply(root.items || [], reasons || ["items"]);
        const ctx = Object.assign({}, root.context || {});
        ctx.projectionRevision = projection.revision;

        if (committed) {
            ctx.changeSet = projection.changes;
            ctx.changeSummary = projection.changeSummary;
        }

        if (!ctx.reason)
            ctx.reason = root.primaryReason(reasons);

        transitionCoordinator.applySnapshot(projection.snapshot || [], ctx);
        root.snapshotApplied(committed ? projection.changes : transitionCoordinator.lastChangeSet);
    }

    function primaryReason(reasons) {
        if (!Array.isArray(reasons) || reasons.length === 0)
            return "snapshot";
        if (reasons.indexOf("initial") >= 0)
            return "open";
        if (reasons.indexOf("context") >= 0)
            return "contextSwitch";
        return String(reasons[0]);
    }

    function updateMeasuredHeight(key, measuredHeight) {
        transitionCoordinator.updateMeasuredHeight(key, measuredHeight);
    }

    function reset() {
        invalidations.reset();
        projection.reset([]);
        transitionCoordinator.resetModel();
    }

    function debugState(extra) {
        const state = transitionCoordinator.debugState(extra);
        state.projection = {
            revision: projection.revision,
            ready: projection.ready,
            changes: projection.changeSummary
        };
        return state;
    }
}
