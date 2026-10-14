import QtQuick
import QtQuick.Controls as Controls

// Retain the native SplitView API: orientation, attached pane constraints,
// handle drag gestures, focus, and saveState()/restoreState().
Controls.SplitView {
    id: root

    implicitWidth: 480
    implicitHeight: 320
    orientation: Qt.Horizontal

    handle: Item {
        id: grip
        implicitWidth: root.orientation === Qt.Horizontal ? 8 : 1
        implicitHeight: root.orientation === Qt.Vertical ? 8 : 1

        readonly property bool isHovered: Controls.SplitHandle.hovered
        readonly property bool isPressed: Controls.SplitHandle.pressed

        Rectangle {
            anchors.centerIn: parent
            width: root.orientation === Qt.Horizontal ? 1 : grip.width
            height: root.orientation === Qt.Vertical ? 1 : grip.height
            color: grip.isPressed ? root.palette.highlight
                : grip.isHovered ? root.palette.mid : root.palette.dark
        }
    }
}
