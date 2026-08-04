import QtQuick

import qs.services

ConfirmActionButton {
    id: root

    property string confirmText: qsTr("Confirm")

    implicitHeight: 32
    highlightSide: ActiveIndicator.Side.Left
    highlightAnimationMode: ActiveIndicator.AnimationMode.GrowAlong
    highlightThickness: Config.spacing.xxs
    accentColor: root.confirming ? Config.styling.critical : Config.styling.warning
    accessibleName: root.confirming ? root.confirmText : root.text

    contentItem: Item {
        implicitWidth: label.implicitWidth + Config.spacing.xs * 2
        implicitHeight: root.implicitHeight

        Text {
            id: label
            anchors.centerIn: parent
            text: root.confirming ? root.confirmText : root.text
            color: root.confirming ? Config.styling.critical : Config.styling.text0
            font.pixelSize: 13
            font.bold: true
        }
    }
}
