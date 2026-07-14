import QtQml
import qs.services

QtObject {
    id: root

    readonly property var tracer: Logger.scope("bluetooth.operationState", { category: "bluetooth" })
    readonly property var prof: Profiler.scope("bluetooth.operationState", { category: "bluetooth" })

    property string currentOperationKind: ""
    property string currentOperationTarget: ""
    property bool currentOperationRunning: false
    property string currentOperationLastError: ""

    readonly property var operation: ({
        kind: currentOperationKind,
        target: currentOperationTarget,
        running: currentOperationRunning,
        lastError: currentOperationLastError
    })
    readonly property bool busy: currentOperationRunning

    function beginOperation(kind, target) {
        currentOperationKind = kind || "";
        currentOperationTarget = target || "";
        currentOperationRunning = true;
        currentOperationLastError = "";
        root.tracer.trace("beginOperation", function() { return { kind: kind, target: target } });
    }

    function finishOperation(success, message) {
        currentOperationRunning = false;
        currentOperationLastError = success ? "" : (message || `${currentOperationKind || "operation"} failed`);
        root.tracer.debug("operationFinished", function() { return { kind: currentOperationKind, target: currentOperationTarget, success: success, error: currentOperationLastError } });
    }

    function executeWithOperation(kind, target, fn) {
        root.beginOperation(kind, target);
        fn();
    }
}
