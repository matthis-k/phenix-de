import QtQuick
import QtQuick.Controls.Basic

import qs.animations as Animations
import qs.services

Slider {
    id: root

    property color accentColor: Config.colors.blue
    property color grooveColor: Config.styling.bg5
    property color inactiveHandleColor: Config.styling.bg3
    property color inactiveHandleBorderColor: Config.styling.bg5
    property real grooveHeight: 4
    property real grooveRadius: grooveHeight / 2
    property real handleSize: 16

    implicitHeight: 28
    hoverEnabled: true
    focusPolicy: Qt.TabFocus | Qt.ClickFocus

    background: Item {
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: root.availableWidth
        height: Math.max(root.grooveHeight, 12)

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: root.grooveHeight
            radius: root.grooveRadius
            color: root.grooveColor
            border.width: root.visualFocus ? 2 : (root.hovered ? 1 : 0)
            border.color: root.visualFocus
                ? Config.styling.primaryAccent
                : Config.styling.bg7

            Animations.StateColorBehavior on border.color {
                duration: Config.motion.micro
            }

            Rectangle {
                width: root.visualPosition * parent.width
                height: parent.height
                radius: parent.radius
                color: root.accentColor
            }
        }
    }

    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: root.handleSize + (root.pressed ? 2 : 0)
        height: width
        radius: width / 2
        color: root.pressed || root.visualFocus
            ? root.accentColor
            : root.inactiveHandleColor
        border.width: root.pressed ? 0 : (root.visualFocus ? 2 : 1)
        border.color: root.visualFocus
            ? Config.styling.primaryAccent
            : (root.hovered ? root.accentColor : root.inactiveHandleBorderColor)

        Animations.StateColorBehavior on color {
            duration: Config.motion.micro
        }

        Animations.StateColorBehavior on border.color {
            duration: Config.motion.micro
        }

        Behavior on width {
            Animations.NumberBehavior {
                kind: Animations.TransitionPolicy.Kind.Micro
            }
        }
    }
}
