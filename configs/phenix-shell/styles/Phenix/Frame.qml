import QtQuick
import QtQuick.Templates as T
import "." as Ph

T.Frame {
    padding: 12

    background: Rectangle {
        radius: 0
        color: Ph.Theme.surface
        border.color: Ph.Theme.border
        border.width: 1
    }
}
