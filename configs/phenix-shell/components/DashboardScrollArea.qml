import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import qs.services

ScrollView {
    id: root

    property int contentSpacing: Config.spacing.xs
    property bool forwardHorizontalWheel: true
    property var tabSwipeTarget: null
    default property alias content: contentColumn.data

    function forwardTabSwipe(event) {
        return tabSwipeTarget && tabSwipeTarget.queueTabSwipeFromWheelEvent
            ? tabSwipeTarget.queueTabSwipeFromWheelEvent(event)
            : false;
    }

    clip: true
    contentWidth: availableWidth
    Layout.fillWidth: true
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

    background: Rectangle {
        color: "transparent"
    }

    WheelHandler {
        enabled: root.forwardHorizontalWheel
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        orientation: Qt.Horizontal
        blocking: false
        target: null

        onWheel: event => event.accepted = root.forwardTabSwipe(event)
    }

    ColumnLayout {
        id: contentColumn
        width: root.availableWidth
        spacing: root.contentSpacing
    }
}
