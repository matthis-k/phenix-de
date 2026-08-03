import QtQml

// Coalesces a burst of invalidations into one revision commit. Services can use
// it as a shared revision clock for several projections without inheritance.
QtObject {
    id: root

    property int revision: 0
    property bool pending: false
    property int batchDepth: 0
    property var pendingReasons: []
    property int maxReasons: 32
    property bool _scheduled: false

    signal committed(int revision, var reasons)

    function invalidate(reason) {
        root.addReason(reason || "changed");
        root.pending = true;
        if (root.batchDepth === 0)
            root.schedule();
    }

    function beginBatch() {
        root.batchDepth += 1;
    }

    function endBatch() {
        if (root.batchDepth <= 0)
            throw new Error("ChangeBatch.endBatch without beginBatch");
        root.batchDepth -= 1;
        if (root.batchDepth === 0 && root.pending)
            root.schedule();
    }

    function transaction(reason, fn) {
        if (typeof fn !== "function")
            throw new Error("ChangeBatch.transaction requires a function");
        root.beginBatch();
        try {
            return fn();
        } finally {
            root.invalidate(reason || "transaction");
            root.endBatch();
        }
    }

    function schedule() {
        if (root._scheduled || root.batchDepth > 0)
            return;
        root._scheduled = true;
        Qt.callLater(function() {
            if (!root)
                return;
            root.flush();
        });
    }

    function flush() {
        root._scheduled = false;
        if (!root.pending || root.batchDepth > 0)
            return false;
        var reasons = root.pendingReasons.slice();
        root.pendingReasons = [];
        root.pending = false;
        root.revision += 1;
        root.committed(root.revision, reasons);
        return true;
    }

    function reset() {
        root._scheduled = false;
        root.pending = false;
        root.batchDepth = 0;
        root.pendingReasons = [];
        root.revision = 0;
    }

    function addReason(reason) {
        var text = String(reason || "changed");
        if (root.pendingReasons.indexOf(text) >= 0)
            return;
        if (root.pendingReasons.length >= root.maxReasons)
            return;
        root.pendingReasons = root.pendingReasons.concat([text]);
    }
}
