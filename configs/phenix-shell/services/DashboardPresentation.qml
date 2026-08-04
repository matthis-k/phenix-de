pragma Singleton

import QtQml
import Quickshell

Singleton {
    id: root

    readonly property string overviewMode: "overview"
    readonly property string detailedMode: "detailed"
    readonly property var tabOrder: [
        "wifi",
        "bluetooth",
        "audio",
        "notifications",
        "energy",
        "stats",
        "overview"
    ]

    property string mode: overviewMode
    readonly property bool detailed: mode === detailedMode

    function normalizeMode(value) {
        return String(value || "").toLowerCase() === root.detailedMode
            ? root.detailedMode
            : root.overviewMode;
    }

    function setMode(value) {
        root.mode = root.normalizeMode(value);
    }

    function toggle() {
        root.mode = root.detailed ? root.overviewMode : root.detailedMode;
    }
}
