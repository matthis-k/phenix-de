import QtQuick
import QtQuick.Layouts
import qs.services

// Layout-only wrapper: keeps native TextField, ComboBox, SpinBox, etc.
// and their focus, validation, and accessible state intact.
ColumnLayout {
    id: root

    property string label: ""
    property string description: ""
    property string error: ""
    property bool mandatory: false
    property int fieldSpacing: Config.spacing.xxs
    default property alias content: fieldSlot.data

    spacing: fieldSpacing
    Layout.fillWidth: true

    RowLayout {
        spacing: Config.spacing.xxs
        Layout.fillWidth: true

        Text {
            text: root.label
            font.pixelSize: Config.typography.label
            font.family: Config.typography.mono
            font.bold: true
            color: Config.styling.text0
        }

        Text {
            visible: root.mandatory
            text: "*"
            color: Config.styling.critical
            font.bold: true
            Accessible.ignored: true
        }
    }

    Text {
        visible: text !== ""
        Layout.fillWidth: true
        text: root.description
        wrapMode: Text.WordWrap
        font.pixelSize: Config.typography.secondary
        color: Config.styling.text1
    }

    ColumnLayout {
        id: fieldSlot
        Layout.fillWidth: true
        spacing: 0
    }

    Text {
        visible: text !== ""
        Layout.fillWidth: true
        text: root.error
        wrapMode: Text.WordWrap
        color: Config.styling.critical
        font.pixelSize: Config.typography.secondary
        Accessible.role: Accessible.StaticText
        Accessible.name: root.error
    }
}
