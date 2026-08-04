import QtQuick
import QtQuick.Layouts

import qs.services

ColumnLayout {
    id: root

    property int level: 1
    property string title: ""
    property string subtitle: ""
    property string iconName: ""
    property color iconColor: Config.styling.text1
    property color titleColor: Config.styling.text0
    property color subtitleColor: Config.styling.text2
    property bool titleBold: true
    property bool subtitleBold: false

    readonly property int titlePixelSize: level === 1 ? 22 : 16

    spacing: 0
    Accessible.description: root.subtitle

    RowLayout {
        visible: root.title !== "" || root.iconName !== ""
        Layout.fillWidth: true
        spacing: Config.spacing.xs

        Icon {
            visible: root.iconName !== ""
            iconName: root.iconName
            fallbackIconName: root.iconName
            color: root.iconColor
            implicitSize: root.level === 1 ? 22 : 18
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            Layout.fillWidth: true
            visible: root.title !== ""
            text: root.title
            color: root.titleColor
            font.pixelSize: root.titlePixelSize
            font.bold: root.titleBold
            elide: Text.ElideRight
        }
    }
}
