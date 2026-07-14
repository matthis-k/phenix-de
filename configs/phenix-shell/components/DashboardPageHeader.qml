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
        visible: root.title !== "" || root.accessory !== null
        spacing: Config.spacing.sm

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

        Loader {
            id: accessoryLoader
            active: root.accessory !== null
            sourceComponent: root.accessory
            Layout.preferredWidth: item ? item.implicitWidth : 0
            Layout.preferredHeight: item ? item.implicitHeight : 0
            Layout.alignment: Qt.AlignTop
        }
    }

    Text {
        visible: root.subtitle !== ""
        text: root.subtitle
        Layout.fillWidth: true
        color: Config.styling.text2
        font.pixelSize: 13
        wrapMode: Text.WordWrap
    }

    Rectangle {
        visible: root.showDivider
        Layout.fillWidth: true
        implicitHeight: 1
        color: Config.styling.bg3
    }
}
