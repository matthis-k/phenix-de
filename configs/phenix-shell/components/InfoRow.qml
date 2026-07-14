import QtQuick
import QtQuick.Layouts
import qs.services

Item {
    id: root

    property string label: ""
    property string value: ""
    property string iconName: ""
    property color iconColor: Config.styling.text1
    property color labelColor: Config.styling.text1
    property color valueColor: Config.styling.text0

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: Config.spacing.xs

        Icon {
            visible: root.iconName !== ""
            iconName: root.iconName
            color: root.iconColor
            implicitSize: 16
        }

        Text {
            text: root.label
            color: root.labelColor
            font.pixelSize: 13
        }

        Item {
            Layout.fillWidth: true
        }

        Text {
            Layout.fillWidth: true
            text: root.value
            color: root.valueColor
            font.pixelSize: 13
            font.bold: true
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }
    }
}
