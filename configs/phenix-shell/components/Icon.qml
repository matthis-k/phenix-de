import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    property string iconName: "dialog-warning"
    property string fallbackIconName: "dialog-warning"
    // Must be `var` with `undefined` sentinel — typed `color`/`url` can't be
    // undefined, breaking the presence check for ColorOverlay visibility
    property var color: undefined
    property real implicitSize: -1
    property var source: undefined

    readonly property bool hasImplicitSize: implicitSize >= 0
    readonly property bool hasIconName: iconName !== "" || fallbackIconName !== ""
    readonly property var iconPath: hasIconName ? Quickshell.iconPath(iconName, fallbackIconName) : undefined
    readonly property var resolvedSource: root.source !== undefined ? root.source : root.iconPath

    property alias smooth: icon.smooth
    property alias mipmap: icon.mipmap

    implicitWidth: hasImplicitSize ? implicitSize : Math.max(16, parent ? parent.height : icon.implicitWidth)
    implicitHeight: hasImplicitSize ? implicitSize : Math.max(16, parent ? parent.height : icon.implicitHeight)

    IconImage {
        id: icon
        anchors.fill: parent
        visible: root.resolvedSource !== undefined && root.resolvedSource !== ""
        source: root.resolvedSource
        scale: root.hasImplicitSize ? root.implicitSize / Math.max(parent.width, parent.height, 1) : 1.0
    }

    ColorOverlay {
        visible: root.color !== undefined && root.color !== null
        anchors.fill: icon
        color: root.color !== undefined && root.color !== null ? root.color : "transparent"
        source: icon
        scale: icon.scale
    }
}
