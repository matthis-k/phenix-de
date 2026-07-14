pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    readonly property var tracer: Logger.scope("brightness", { category: "brightness" })
    readonly property var prof: Profiler.scope("brightness", { category: "brightness" })

    readonly property var backend: root

    property bool available: false
    property int currentValue: 0
    property int maxValue: 100
    property int step: 5
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

    readonly property int percent: available && maxValue > 0 ? Math.round((currentValue / maxValue) * 100) : 0
    readonly property string iconName: {
        if (!available)
            return "display-brightness-off-symbolic";
        if (percent <= 0)
            return "display-brightness-off-symbolic";
        if (percent < 34)
            return "display-brightness-low-symbolic";
        if (percent < 67)
            return "display-brightness-medium-symbolic";
        return "display-brightness-high-symbolic";
    }

    readonly property color iconColor: available ? Config.styling.primaryAccent : Config.styling.text2

    readonly property string state: {
        if (!available) return "unavailable";
        if (percent <= 0) return "off";
        if (percent < 34) return "low";
        if (percent < 67) return "medium";
        return "high";
    }

    readonly property string label: "Brightness"
    readonly property string statusText: available ? `${percent}%` : "Unavailable"

    readonly property var presentation: {
        return {
            icon: root.iconName,
            color: root.iconColor,
            label: root.label,
            status: root.statusText,
            state: root.state,
            available: root.available
        };
    }

    readonly property var control: {
        if (!root.available)
            return null;
        return {
            kind: "slider",
            target: "brightness",
            from: 0,
            to: 100,
            step: root.step,
            value: root.percent
        };
    }

    function beginOperation(kind, target) {
        currentOperationKind = kind || "";
        currentOperationTarget = target || "";
        currentOperationRunning = true;
        currentOperationLastError = "";
    }

    function finishOperation(success, message) {
        currentOperationRunning = false;
        currentOperationLastError = success ? "" : (message || `${currentOperationKind || "operation"} failed`);
    }

    function applyProbe(text) {
        const parts = (text || "").trim().split(/\s+/);
        if (parts.length < 2) {
            available = false;
            root.tracer.warn("applyProbe.invalidOutput", function() { return { text: text } });
            return;
        }

        const current = parseInt(parts[0], 10);
        const max = parseInt(parts[1], 10);
        if (isNaN(current) || isNaN(max) || max <= 0) {
            available = false;
            root.tracer.warn("applyProbe.parseFailed", function() { return { current: current, max: max } });
            return;
        }

        currentValue = current;
        maxValue = max;
        available = true;
        root.tracer.debug("brightnessProbed", function() { return { current: current, max: max, percent: root.percent } });
    }

    function refresh() {
        root.tracer.trace("refresh");
        probe.exec({
            command: [
                "sh",
                "-c",
                "cur=$(brightnessctl -q -c backlight g 2>/dev/null) || exit 1; max=$(brightnessctl -q -c backlight m 2>/dev/null) || exit 1; printf '%s %s\\n' \"$cur\" \"$max\""
            ]
        });
    }

    function setPercent(targetPercent) {
        if (!available) {
            root.tracer.warn("setPercent.unavailable");
            return;
        }

        const clamped = Math.max(0, Math.min(100, Math.round(targetPercent)));
        root.tracer.info("setPercent", function() { return { target: clamped } });
        beginOperation("set-brightness", `${clamped}%`);
        setter.exec({
            command: ["brightnessctl", "-q", "-n2", "-c", "backlight", "set", `${clamped}%`]
        });
        refreshDelay.restart();
    }

    function adjust(delta) {
        root.tracer.debug("adjustBrightness", function() { return { delta: delta, current: root.percent } });
        setPercent(root.percent + delta);
    }

    function executePayload(payload) {
        if (!payload || payload.service !== "brightness") {
            if (payload) root.tracer.warn("executePayload.wrongService", function() { return { service: payload.service } });
            return false;
        }

        root.tracer.debug("executePayload", function() { return { op: payload.op } });
        switch (payload.op) {
        case "set":
            root.setPercent(Number(payload.value || 0));
            return true;
        case "adjust":
            root.adjust(Number(payload.delta || 0));
            return true;
        default:
            root.tracer.warn("executePayload.unknownOp", function() { return { op: payload.op } });
            return false;
        }
    }

    Process {
        id: probe
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.applyProbe(text)
        }
        function onExited(exitCode) {
            if (exitCode !== 0)
                root.available = false;
        }
    }

    Process {
        id: setter
        function onExited(exitCode) {
            root.finishOperation(exitCode === 0, `set brightness failed (${exitCode})`);
            refreshDelay.restart();
        }
    }

    Timer {
        id: pollTimer
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        id: refreshDelay
        interval: 200
        onTriggered: root.refresh()
    }
}
