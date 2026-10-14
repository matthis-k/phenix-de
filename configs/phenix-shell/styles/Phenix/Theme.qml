pragma Singleton
import QtQml
import QtQuick

// Portable Qt Quick Controls palette. No Quickshell imports: the style can
// also be used by standalone Qt Quick applications. Keep visual roles aligned
// with Config.qml, which handles the live shell's palette and animations.
QtObject {
    readonly property color background: "#181825"
    readonly property color surface: "#1e1e2e"
    readonly property color raised: "#313244"
    readonly property color hover: "#45475a"
    readonly property color border: "#585b70"
    readonly property color text: "#cdd6f4"
    readonly property color secondary: "#a6adc8"
    readonly property color placeholder: "#7f849c"
    readonly property color accent: "#89b4fa"
    readonly property color textOnAccent: "#1e1e2e"
    readonly property color disabled: "#6c7086"
    readonly property string mono: "monospace"
    readonly property int fontSize: 13
    readonly property int controlHeight: 34
}
