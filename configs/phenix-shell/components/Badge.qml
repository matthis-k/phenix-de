import QtQuick
import qs.services

Rectangle {
    id: root

    property string text: ""
    property color textColor: Config.styling.textOnAccent
    property color badgeColor: Config.styling.primaryAccent
    property int horizontalPadding: Config.spacing.xxs
    property int verticalPadding: 2

    visible: text !== ""
    color: badgeColor
    radius: height / 2
    implicitWidth: Math.max(height, label.implicitWidth + horizontalPadding * 2)
    implicitHeight: label.implicitHeight + verticalPadding * 2

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.textColor
        font.pixelSize: 10
        font.bold: true
    }
}
