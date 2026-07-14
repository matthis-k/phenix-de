pragma Singleton
import QtQuick
import Quickshell
import qs.services

Singleton {
    id: root
    readonly property var tracer: Logger.scope("time", { category: "time" })
    readonly property var prof: Profiler.scope("time", { category: "time" })
    readonly property string time: Qt.formatDateTime(clock.date, "HH:mm:ss")

    function formatted(format: string): string {
        return Qt.formatDateTime(clock.date, format);
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
}
