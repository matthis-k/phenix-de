import QtQuick
import qs.animations as Animations
import qs.services
import qs.components

ActionButton {
    id: root
    property var screenState
    property string tabName: ""
    property string label: ""
    property string iconName: "dialog-warning"
    property string fallbackIconName: "dialog-warning"
    property color iconColor: Config.styling.text0
    property string badgeText: ""
    property color badgeColor: Config.styling.primaryAccent
    property alias smooth: statusIcon.smooth
    property alias mipmap: statusIcon.mipmap
    property string overlayIconName: ""
    property color overlayIconColor: Config.styling.text0
    property real overlayIconScale: 0.68

    readonly property bool expanded: !!screenState && screenState.barExpandedForDashboard
    readonly property int transitionMs: screenState
        ? screenState.dashboardTransitionMs
        : Config.motion.short

    implicitWidth: parent ? parent.height : 24
    implicitHeight: parent ? parent.height : 24

    accessibleName: root.label || root.tabName
    accessibleDescription: root.label === "" ? "" : qsTr("Open %1").arg(root.label)
    toolTipText: root.label

    active: screenState ? screenState.isIndicatorActive(tabName) : false
    scaleIcon: true
    iconScaleTarget: statusIcon
    hoveredScale: 1.0
    unhoveredScale: active ? 1.0 : 0.92

    contentItem: Item {
        implicitWidth: root.implicitWidth
        implicitHeight: root.implicitHeight

        Icon {
            id: statusIcon
            anchors.centerIn: parent
            iconName: root.iconName
            fallbackIconName: root.fallbackIconName
            color: root.iconColor
            implicitSize: (parent ? parent.height : root.implicitHeight) * 0.7

            Animations.ScaleBehavior on scale {
                duration: root.transitionMs > 0 ? Config.motion.micro : 0
            }
        }

        Badge {
            anchors.top: statusIcon.top
            anchors.right: statusIcon.right
            anchors.topMargin: -Config.spacing.xxs
            anchors.rightMargin: -Config.spacing.xxs
            text: root.badgeText
            badgeColor: root.badgeColor
        }

        Icon {
            anchors.bottom: statusIcon.bottom
            anchors.right: statusIcon.right
            anchors.bottomMargin: -3
            anchors.rightMargin: -6
            iconName: root.overlayIconName
            color: root.overlayIconColor
            implicitSize: statusIcon.implicitSize * root.overlayIconScale
            visible: root.overlayIconName !== ""
        }
    }

    Animations.ShiftBehavior on x {
        duration: root.transitionMs
    }

    Animations.ShiftBehavior on width {
        duration: root.transitionMs
    }

    onClicked: {
        if (!screenState || tabName === "")
            return;

        screenState.toggleDashboard(tabName);
    }
}
