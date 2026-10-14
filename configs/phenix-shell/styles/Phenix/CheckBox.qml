import QtQuick
import QtQuick.Templates as T
import "." as Ph

T.CheckBox {
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
        implicitWidth: 18
        implicitHeight: 18
        x: control.leftPadding
        y: control.topPadding + (control.availableHeight - height) / 2
        radius: 0
        color: control.checked ? Ph.Theme.accent : Ph.Theme.surface
        border.width: control.visualFocus ? 2 : 1
        border.color: control.visualFocus ? Ph.Theme.accent : Ph.Theme.border

        Text {
            anchors.centerIn: parent
            text: control.checkState === Qt.PartiallyChecked ? "−" : "✓"
            visible: control.checkState !== Qt.Unchecked
            color: Ph.Theme.onAccent
            font.bold: true
            font.pixelSize: 14
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
