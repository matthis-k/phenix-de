import QtQuick
import QtQuick.Templates as T
import "." as Ph

T.TextField {
    id: control

    implicitWidth: 160
    implicitHeight: Math.max(Ph.Theme.controlHeight, contentHeight + topPadding + bottomPadding)
    padding: 8
    selectByMouse: true
    color: enabled ? Ph.Theme.text : Ph.Theme.disabled
    placeholderTextColor: Ph.Theme.placeholder
    selectionColor: Ph.Theme.accent
    selectedTextColor: Ph.Theme.onAccent
    font.family: Ph.Theme.mono
    font.pixelSize: Ph.Theme.fontSize
    verticalAlignment: TextInput.AlignVCenter

    background: Rectangle {
        radius: 0
        color: control.enabled ? Ph.Theme.surface : Ph.Theme.background
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? Ph.Theme.accent : Ph.Theme.border
    }
}
