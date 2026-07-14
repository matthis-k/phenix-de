import QtQuick
import qs.services

InteractiveButton {
    id: control

    property bool active: false
    property bool fillOnHover: true
    property bool indicatorOnHover: true
    property color accentColor: Config.styling.activeIndicator
    property color backgroundColor: Config.styling.bg3
    property color borderColor: "transparent"
    property int borderWidth: 0

    property int highlightSide: ActiveIndicator.Side.Top
    property int highlightAnimationMode: ActiveIndicator.AnimationMode.GrowAll
    property real highlightThickness: (highlightSide === ActiveIndicator.Side.Top || highlightSide === ActiveIndicator.Side.Bottom) ? height * 0.1 : width * 0.1
    property real fillOpacity: Config.behaviour.hoverBgOpacity
    property int scaleAnimationDuration: Config.motion.micro

    padding: 0
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0

    Rectangle {
        anchors.fill: parent
        z: -1
        clip: true
        color: control.backgroundColor
        border.width: control.borderWidth
        border.color: control.borderColor
        radius: Config.styling.radius

        ActiveIndicator {
            anchors.fill: parent
            side: control.highlightSide
            animationMode: control.highlightAnimationMode
            duration: control.scaleAnimationDuration
            thickness: control.highlightThickness
            color: control.accentColor
            bgOpacity: control.fillOpacity
            bgActive: (control.fillOnHover && control.hovered) || control.visualFocus || control.active
            active: control.active || control.visualFocus || (control.indicatorOnHover && control.hovered)
        }
    }
}
