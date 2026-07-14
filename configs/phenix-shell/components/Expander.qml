import QtQuick
import qs.animations as Animations
import qs.services

Item {
    id: root

    property bool expanded: false
    property bool animationEnabled: true
    property bool animationSettled: false
    property bool scaleContentHeight: true
    property int duration: Config.motion.medium
    property int slideDistance: Config.spacing.sm
    property real progress: expanded ? 1 : 0
    readonly property var primaryContent: contentContainer.children.length > 0 ? contentContainer.children[0] : null
    readonly property real contentHeight: primaryContent ? primaryContent.implicitHeight : contentContainer.childrenRect.height
    property alias contentItem: contentContainer
    default property alias content: contentContainer.data

    implicitWidth: primaryContent ? primaryContent.implicitWidth : contentContainer.childrenRect.width
    implicitHeight: scaleContentHeight ? contentHeight * progress : contentHeight
    visible: expanded || implicitHeight > 0
    clip: true

    Animations.LayoutBehavior on implicitHeight {
        enabled: root.scaleContentHeight && root.animationEnabled && root.animationSettled
        duration: root.duration
    }

    Component.onCompleted: Qt.callLater(function() {
        root.animationSettled = true;
    })

    Animations.LayoutBehavior on progress {
        enabled: root.animationEnabled && root.animationSettled
        duration: root.duration
    }

    Item {
        id: contentContainer

        width: root.width
        height: root.contentHeight
        y: -root.slideDistance * (1 - root.progress)
    }
}
