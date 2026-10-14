import QtQuick
import QtQuick.Templates as T
import "." as Ph

T.Slider {
    id: control

    implicitWidth: 180
    implicitHeight: 30
    padding: 8
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus

    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + (control.availableHeight - height) / 2
        width: control.availableWidth
        height: 4
        radius: 0
        color: Ph.Theme.hover

        Rectangle {
            width: control.visualPosition * parent.width
            height: parent.height
            radius: 0
            color: Ph.Theme.accent
        }
    }

    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + (control.availableHeight - height) / 2
        width: 16
        height: 16
        radius: width / 2
        color: control.pressed ? Ph.Theme.accent : Ph.Theme.surface
        border.width: control.visualFocus ? 2 : 1
        border.color: Ph.Theme.accent
    }
}
