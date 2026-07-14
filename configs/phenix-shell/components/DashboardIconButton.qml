import QtQuick
import qs.services

ActionButton {
    id: root

    property string iconName: "dialog-warning"
    property string fallbackIconName: iconName
    property color iconColor: Config.styling.text0

    implicitWidth: 28
    implicitHeight: 28

    contentItem: Icon {
        anchors.centerIn: parent
        iconName: root.iconName
        fallbackIconName: root.fallbackIconName
        color: root.iconColor
        implicitSize: 16
    }
}
