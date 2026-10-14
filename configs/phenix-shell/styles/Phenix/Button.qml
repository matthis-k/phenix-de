import QtQuick
import QtQuick.Templates as T
import "." as Ph

T.Button {
    id: control

    implicitWidth: Math.max(80, contentItem.implicitWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(Ph.Theme.controlHeight, contentItem.implicitHeight + topPadding + bottomPadding)
    padding: 8
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    font.family: Ph.Theme.mono
    font.pixelSize: Ph.Theme.fontSize

    contentItem: Text {
        text: control.text
        font: control.font
        color: !control.enabled ? Ph.Theme.disabled
            : control.highlighted ? Ph.Theme.onAccent : Ph.Theme.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: 0
        color: !control.enabled ? Ph.Theme.surface
            : control.down ? Ph.Theme.hover
            : control.highlighted ? Ph.Theme.accent
            : control.hovered ? Ph.Theme.raised : Ph.Theme.surface
        border.width: control.visualFocus ? 2 : 1
        border.color: control.visualFocus ? Ph.Theme.accent : Ph.Theme.border
    }
}
