import QtQml
import "SnapshotDiff.js" as SnapshotDiff

// Materializes a detached UI-facing snapshot and its change set. Producers may
// either push a snapshot through apply() or provide capture() and invalidate it.
QtObject {
    id: root

    property var capture: null
    property var materialize: null
    property var differ: null
    property var keyOf: null
    property var equals: null
    property int sourceRevision: 0
    property bool refreshOnCompleted: false
    property bool coalesceInvalidations: true

    readonly property bool ready: _ready
    readonly property int revision: _revision
    readonly property var snapshot: _snapshot
    readonly property var previousSnapshot: _previousSnapshot
    readonly property var changes: _changes
    readonly property var changeSummary: _changes.summary

    property bool _ready: false
    property int _revision: 0
    property var _snapshot: null
    property var _previousSnapshot: null
    property var _changes: SnapshotDiff.empty()
    property bool _completed: false
    property bool _scheduled: false
    property var _pendingReasons: []

    signal committed(var snapshot, var changes, int revision, var reasons)

    onSourceRevisionChanged: {
        if (root._completed && root.capture)
            root.invalidate("source-revision");
    }

    Component.onCompleted: {
        root._completed = true;
        if (root.refreshOnCompleted && root.capture)
            root.invalidate("initial");
    }

    function apply(nextSnapshot, reason) {
        return root.commit(nextSnapshot, root.normalizeReasons(reason));
    }

    function refresh(reason) {
        if (typeof root.capture !== "function")
            throw new Error("SnapshotProjection.refresh requires capture()");
        return root.commit(root.capture(), root.normalizeReasons(reason));
    }

    function invalidate(reason) {
        root.addReason(reason || "invalidated");
        if (!root.coalesceInvalidations)
            return root.flush();
        if (root._scheduled)
            return false;
        root._scheduled = true;
        Qt.callLater(function() {
            if (!root)
                return;
            root.flush();
        });
        return true;
    }

    function flush() {
        root._scheduled = false;
        if (root._pendingReasons.length === 0)
            return false;
        var reasons = root._pendingReasons.slice();
        root._pendingReasons = [];
        return root.refresh(reasons);
    }

    function commit(nextSnapshot, reasons) {
        if (nextSnapshot === undefined)
            throw new Error("SnapshotProjection cannot commit undefined");

        var materialized = root.materializeSnapshot(nextSnapshot);
        var previous = root._ready ? root._snapshot : root.emptyLike(materialized);
        var changeSet = root.diff(previous, materialized);
        if (root._ready && !changeSet.changed) {
            root._changes = changeSet;
            return false;
        }

        root._previousSnapshot = root._ready ? root._snapshot : null;
        root._snapshot = materialized;
        root._changes = changeSet;
        root._revision += 1;
        root._ready = true;
        root.committed(root._snapshot, root._changes, root._revision, reasons || []);
        return true;
    }

    function materializeSnapshot(value) {
        if (typeof root.materialize === "function")
            return root.materialize(value);
        if (Array.isArray(value))
            return value.slice();
        if (value && typeof value === "object") {
            var copy = {};
            for (var key in value) {
                if (Object.prototype.hasOwnProperty.call(value, key))
                    copy[key] = value[key];
            }
            return copy;
        }
        return value;
    }

    function diff(previous, next) {
        if (typeof root.differ === "function")
            return root.differ(previous, next);
        if (Array.isArray(next) || Array.isArray(previous)) {
            if (typeof root.keyOf !== "function")
                throw new Error("Array SnapshotProjection requires keyOf(item, index) or differ(previous, next)");
            return SnapshotDiff.keyed(previous || [], next || [], root.keyOf, root.equals);
        }
        return SnapshotDiff.fields(previous || {}, next || {}, root.equals);
    }

    function reset(initialSnapshot) {
        var hasInitial = initialSnapshot !== undefined;
        root._scheduled = false;
        root._pendingReasons = [];
        root._ready = hasInitial;
        root._revision = 0;
        root._snapshot = hasInitial ? root.materializeSnapshot(initialSnapshot) : null;
        root._previousSnapshot = null;
        root._changes = SnapshotDiff.empty();
    }

    function emptyLike(value) {
        return Array.isArray(value) ? [] : {};
    }

    function addReason(reason) {
        var text = String(reason || "invalidated");
        if (root._pendingReasons.indexOf(text) < 0)
            root._pendingReasons = root._pendingReasons.concat([text]);
    }

    function normalizeReasons(reason) {
        if (Array.isArray(reason))
            return reason.slice();
        if (reason === null || reason === undefined || reason === "")
            return [];
        return [String(reason)];
    }
}
