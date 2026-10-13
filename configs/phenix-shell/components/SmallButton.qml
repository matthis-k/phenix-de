import QtQuick
import qs.services

ActionButton {
    id: root

    implicitHeight: 28
    highlightSide: ActiveIndicator.Side.Left
    highlightAnimationMode: ActiveIndicator.AnimationMode.GrowAlong
    highlightThickness: Config.spacing.xxs

    contentItem: Item {
        implicitWidth: label.implicitWidth + Config.spacing.xs * 2
        implicitHeight: root.implicitHeight

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            color: Config.styling.text0
            font.pixelSize: Config.typography.label
            font.family: Config.typography.mono
            font.bold: true
        }
    }
}
