import QtQuick
import QtQuick.Controls.Basic
import qs.services

Slider {
    id: root

    property color accentColor: Config.colors.blue
    property color grooveColor: Config.styling.bg5
    property color inactiveHandleColor: Config.styling.bg3
    property color inactiveHandleBorderColor: Config.styling.bg5
    property real grooveHeight: 4
    property real grooveRadius: grooveHeight / 2
    property real handleSize: 14

    implicitHeight: handleSize

    background: Rectangle {
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: root.availableWidth
        height: root.grooveHeight
        radius: root.grooveRadius
        color: root.grooveColor

        Rectangle {
            width: root.visualPosition * parent.width
            height: parent.height
            radius: parent.radius
            color: root.accentColor
        }
    }

    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: root.handleSize
        height: root.handleSize
        radius: width / 2
        color: root.pressed ? root.accentColor : root.inactiveHandleColor
        border.width: root.pressed ? 0 : 1
        border.color: root.inactiveHandleBorderColor
    }
}
