import QtQuick
import QtQuick.Controls.Basic

import qs.animations as Animations
import qs.services

Switch {
    id: root

    property color accentColor: Config.styling.primaryAccent
    property color knobColor: Config.styling.textOnAccent
    property real switchProgress: checked ? 1 : 0

    implicitWidth: 58
    implicitHeight: 28
    hoverEnabled: true
    spacing: 0
    padding: 0
    text: ""

    function syncProgress() {
        switchProgress = checked ? 1 : 0;
    }

    onCheckedChanged: syncProgress()

    Component.onCompleted: {
        syncProgress();
    }

    Animations.SettledShiftBehavior on switchProgress {
    }

    indicator: Item {
        implicitWidth: root.implicitWidth
        implicitHeight: root.implicitHeight

        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            radius: height / 2
            color: Config.colorWithOpacity(root.accentColor, 0.18)
            opacity: root.hovered && root.enabled ? 1 : 0

            Animations.RevealBehavior on opacity {
                duration: Config.motion.micro
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: !root.enabled
                ? Config.styling.bg4
                : root.checked
                    ? root.accentColor
                    : Config.styling.bg5

            Animations.SettledStateColorBehavior on color {
            }
        }

        Rectangle {
            width: parent.height - 4
            height: parent.height - 4
            x: 2 + root.switchProgress * (parent.width - width - 4)
            y: 2
            radius: width / 2
            color: root.knobColor
        }
    }

    contentItem: Item {
        implicitWidth: 0
        implicitHeight: 0
    }
}
