import QtQuick
import QtQuick.Templates as T
import "." as Ph

T.TextArea {
    id: control

    implicitWidth: 240
    implicitHeight: 100
    padding: 10
    wrapMode: TextEdit.Wrap
    selectByMouse: true
    color: enabled ? Ph.Theme.text : Ph.Theme.disabled
    placeholderTextColor: Ph.Theme.placeholder
    selectionColor: Ph.Theme.accent
    selectedTextColor: Ph.Theme.onAccent
    font.family: Ph.Theme.mono
    font.pixelSize: Ph.Theme.fontSize

    background: Rectangle {
        radius: 0
        color: control.enabled ? Ph.Theme.surface : Ph.Theme.background
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? Ph.Theme.accent : Ph.Theme.border
    }
}
