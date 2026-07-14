import QtQuick
import QtQml
import Quickshell.Io
import qs.services

QtObject {
    id: root

    readonly property var tracer: Logger.scope("network.monitor", { category: "network" })
    readonly property var prof: Profiler.scope("network.monitor", { category: "network" })

    signal refreshRequested()

    property int debounceInterval: 300
    property int restartInterval: 2000
    property int initDelay: 100

    property Timer initTimer: Timer {
        interval: root.initDelay
        onTriggered: {
            root.refreshRequested();
            root.monitorProcess.exec({
                command: ["nmcli", "monitor"]
            });
        }
    }

    property Timer monitorDebounce: Timer {
        interval: root.debounceInterval
        onTriggered: root.refreshRequested()
    }

    property Timer monitorRestartTimer: Timer {
        interval: root.restartInterval
        onTriggered: {
            root.monitorProcess.exec({
                command: ["nmcli", "monitor"]
            });
        }
    }

    property Process monitorProcess: Process {
        stdout: SplitParser {
            onRead: root.monitorDebounce.restart()
        }
        function onExited(exitCode, exitStatus) {
            root.monitorRestartTimer.start();
        }
    }

    function start() {
        root.tracer.info("monitorStarted");
        root.initTimer.start();
    }

    function restart() {
        root.tracer.info("monitorRestarting");
        root.monitorProcess.exec({
            command: ["nmcli", "monitor"]
        });
    }
}
