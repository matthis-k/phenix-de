import QtQuick
import QtQuick.Templates as T
import "." as Ph

T.Switch {
    id: control

    implicitWidth: contentItem.implicitWidth + leftPadding + rightPadding
    implicitHeight: Math.max(Ph.Theme.controlHeight, indicator.implicitHeight, contentItem.implicitHeight) + topPadding + bottomPadding
    spacing: 8
    padding: 4
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    font.family: Ph.Theme.mono
    font.pixelSize: Ph.Theme.fontSize

    indicator: Rectangle {
        implicitWidth: 44
        implicitHeight: 24
        x: control.leftPadding
        y: control.topPadding + (control.availableHeight - height) / 2
        radius: 0
        color: control.checked ? Ph.Theme.accent : Ph.Theme.hover
        border.width: control.visualFocus ? 2 : 0
        border.color: Ph.Theme.accent

        Rectangle {
            width: 18
            height: 18
            radius: 3
            y: 3
            x: 3 + (parent.width - width - 6) * control.visualPosition
            color: control.enabled ? Ph.Theme.onAccent : Ph.Theme.disabled
        }
    }

    contentItem: Text {
        leftPadding: control.indicator.width + control.spacing
        text: control.text
        font: control.font
        color: control.enabled ? Ph.Theme.text : Ph.Theme.disabled
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}
