import QtQuick
import QtQuick.Templates as T
import "." as Ph

T.RadioButton {
    id: control

    implicitWidth: contentItem.implicitWidth + leftPadding + rightPadding
    implicitHeight: Math.max(Ph.Theme.controlHeight, indicator.implicitHeight, contentItem.implicitHeight) + topPadding + bottomPadding
    padding: 4
    spacing: 8
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    font.family: Ph.Theme.mono
    font.pixelSize: Ph.Theme.fontSize

    indicator: Rectangle {
        implicitWidth: 18
        implicitHeight: 18
        x: control.leftPadding
        y: control.topPadding + (control.availableHeight - height) / 2
        radius: width / 2
        color: Ph.Theme.surface
        border.width: control.visualFocus ? 2 : 1
        border.color: control.checked || control.visualFocus ? Ph.Theme.accent : Ph.Theme.border

        Rectangle {
            anchors.centerIn: parent
            width: 8
            height: 8
            radius: width / 2
            visible: control.checked
            color: Ph.Theme.accent
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
