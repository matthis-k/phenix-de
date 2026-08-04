import QtQuick
import QtQuick.Layouts
import qs.services

ColumnLayout {
    id: root

    property string title: ""
    property string subtitle: ""
    property Component accessory: null
    property bool showDivider: title !== "" || subtitle !== "" || accessory !== null

    spacing: Config.spacing.xs

    RowLayout {
        Layout.fillWidth: true
        visible: root.title !== "" || root.subtitle !== "" || root.accessory !== null
        spacing: Config.spacing.sm

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Config.spacing.xxs

            Text {
                id: titleLabel
                Layout.fillWidth: true
                visible: root.title !== ""
                text: root.title
                color: Config.styling.text0
                font.pixelSize: 22
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: root.subtitle !== ""
                text: root.subtitle
                color: Config.styling.text2
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }

        Loader {
            id: accessoryLoader
            active: root.accessory !== null
            sourceComponent: root.accessory
            Layout.preferredWidth: item ? item.implicitWidth : 0
            Layout.preferredHeight: item ? item.implicitHeight : 0
            Layout.alignment: Qt.AlignTop
        }
    }

    Rectangle {
        visible: root.showDivider
        Layout.fillWidth: true
        implicitHeight: 1
        color: Config.styling.bg3
    }
}
