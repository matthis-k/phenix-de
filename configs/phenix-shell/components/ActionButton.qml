import QtQuick

import qs.animations as Animations
import qs.services

InteractiveButton {
    id: control

    property bool active: false
    property bool fillOnHover: true
    property bool indicatorOnHover: true
    property color accentColor: Config.styling.activeIndicator
    property color backgroundColor: Config.styling.bg3
    property color pressedBackgroundColor: Config.styling.bg5
    property color borderColor: "transparent"
    property color focusBorderColor: Config.styling.primaryAccent
    property int borderWidth: 0

    property int highlightSide: ActiveIndicator.Side.Top
    property int highlightAnimationMode: ActiveIndicator.AnimationMode.GrowAll
    property real highlightThickness: (highlightSide === ActiveIndicator.Side.Top || highlightSide === ActiveIndicator.Side.Bottom)
        ? height * 0.1
        : width * 0.1
    property real fillOpacity: Config.behaviour.hoverBgOpacity

    padding: 0
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0

    Rectangle {
        anchors.fill: parent
        z: -1
        clip: true
        color: control.down ? control.pressedBackgroundColor : control.backgroundColor
        border.width: control.visualFocus ? Math.max(2, control.borderWidth) : control.borderWidth
        border.color: control.visualFocus ? control.focusBorderColor : control.borderColor
        radius: Config.styling.radius

        Animations.StateColorBehavior on color {
            duration: Config.motion.micro
        }

        Animations.StateColorBehavior on border.color {
            duration: Config.motion.micro
        }

        ActiveIndicator {
            anchors.fill: parent
            side: control.highlightSide
            animationMode: control.highlightAnimationMode
            duration: Config.motion.micro
            thickness: control.highlightThickness
            color: control.accentColor
            bgOpacity: control.fillOpacity
            bgActive: control.down
                || (control.fillOnHover && control.hovered)
                || control.visualFocus
                || control.active
            active: control.down
                || control.active
                || control.visualFocus
                || (control.indicatorOnHover && control.hovered)
        }
    }
}
