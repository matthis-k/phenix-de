import QtQuick
import QtQuick.Templates as T
import "." as Ph

T.TabButton {
    id: control

    implicitWidth: Math.max(80, contentItem.implicitWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(Ph.Theme.controlHeight, contentItem.implicitHeight + topPadding + bottomPadding)
    padding: 9
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    font.family: Ph.Theme.mono
    font.pixelSize: Ph.Theme.fontSize

    contentItem: Text {
        text: control.text
        font: control.font
        color: !control.enabled ? Ph.Theme.disabled
            : control.checked ? Ph.Theme.accent : Ph.Theme.secondary
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: 0
        color: control.down || control.hovered ? Ph.Theme.raised : Ph.Theme.surface
        border.width: control.visualFocus ? 2 : 0
        border.color: Ph.Theme.accent

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 2
            visible: control.checked
            color: Ph.Theme.accent
        }
    }
}
