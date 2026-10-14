import QtQuick
import QtQuick.Layouts
import qs.services

// Form-specific grouping; no custom editor, model or validation pipeline.
ColumnLayout {
    id: root

    property string title: ""
    property string description: ""
    property Component accessory: null
    property bool showDivider: true
    property int fieldSpacing: Config.spacing.sm
    default property alias content: fields.data

    spacing: Config.spacing.sm
    Layout.fillWidth: true

    RowLayout {
        Layout.fillWidth: true
        spacing: Config.spacing.sm

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Config.spacing.xxs

            Text {
                visible: root.title !== ""
                Layout.fillWidth: true
                text: root.title
                color: Config.styling.text0
                font.family: Config.typography.mono
                font.pixelSize: Config.typography.heading
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                visible: root.description !== ""
                Layout.fillWidth: true
                text: root.description
                color: Config.styling.text1
                font.pixelSize: Config.typography.secondary
                wrapMode: Text.WordWrap
            }
        }

        Loader {
            active: root.accessory !== null
            sourceComponent: root.accessory
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: item ? item.implicitWidth : 0
            Layout.preferredHeight: item ? item.implicitHeight : 0
        }
    }

    Rectangle {
        visible: root.showDivider
        Layout.fillWidth: true
        implicitHeight: 1
        color: Config.styling.bg3
    }

    ColumnLayout {
        id: fields
        Layout.fillWidth: true
        spacing: root.fieldSpacing
    }
}
