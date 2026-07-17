pragma Singleton
pragma ComponentBehavior: Bound

import QtQml
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    readonly property var tracer: Logger.scope("session.controller", { category: "session" })
    readonly property var prof: Profiler.scope("session.controller", { category: "session" })

    property bool busy: false
    property string pendingOperation: ""
    property string lastError: ""
    property string _stderr: ""

    signal operationFinished(string operation, bool success, string message)

    function commandFor(operation) {
        switch (String(operation || "")) {
        case "lock":
            return ["loginctl", "lock-session"];
        case "logout":
            return ["uwsm", "stop"];
        case "shutdown":
            return ["systemctl", "poweroff"];
        case "reboot":
            return ["systemctl", "reboot"];
        case "hibernate":
            return ["systemctl", "hibernate"];
        default:
            return [];
        }
    }

    function execute(operation) {
        const normalized = String(operation || "");
        const command = root.commandFor(normalized);

        if (root.busy || command.length === 0) {
            if (command.length === 0)
                root.lastError = qsTr("Unknown session action: %1").arg(normalized);
            return false;
        }

        root.pendingOperation = normalized;
        root.lastError = "";
        root._stderr = "";
        root.busy = true;
        root.tracer.info("execute", function() { return { operation: normalized }; });

        if (TestMode.isActive) {
            root.busy = false;
            root.pendingOperation = "";
            root.operationFinished(normalized, true, "");
            return true;
        }

        runner.exec({ command: command });
        return true;
    }

    function executePayload(payload) {
        if (!payload || !payload.op)
            return false;
        return root.execute(payload.op);
    }

    Process {
        id: runner

        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: root._stderr = String(text || "").trim()
        }

        function onExited(exitCode) {
            const operation = root.pendingOperation;
            const success = exitCode === 0;
            const message = success
                ? ""
                : (root._stderr || qsTr("%1 failed with exit code %2").arg(operation).arg(exitCode));

            root.busy = false;
            root.pendingOperation = "";
            root.lastError = message;
            root.tracer.info("finished", function() {
                return { operation: operation, success: success, exitCode: exitCode };
            });
            root.operationFinished(operation, success, message);
        }
    }
}
