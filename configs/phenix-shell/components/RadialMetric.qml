import QtQuick
import QtQuick.Layouts
import qs.services

Rectangle {
    id: root

    property string label: ""
    property string valueText: `${Math.round(Number(percent || 0))}%`
    property string detail: ""
    property string iconName: ""
    property real percent: 0
    property color accentColor: Config.styling.primaryAccent
    property bool emphasized: false
    property real gaugeSize: 64

    implicitWidth: 108
    implicitHeight: root.detail !== "" ? 136 : 116
    color: Config.styling.bg2
    radius: Config.styling.radius
    border.width: emphasized ? 2 : 1
    border.color: emphasized ? accentColor : Config.styling.bg3

    Accessible.name: root.label
    Accessible.description: root.detail

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Config.spacing.xs
        spacing: 3

        RowLayout {
            Layout.fillWidth: true
            spacing: 5

            Icon {
                visible: root.iconName !== ""
                iconName: root.iconName
                fallbackIconName: root.iconName
                color: root.accentColor
                implicitSize: 16
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                Layout.fillWidth: true
                text: root.label
                color: root.accentColor
                font.pixelSize: 12
                font.bold: true
                elide: Text.ElideRight
            }
        }

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: root.gaugeSize
            Layout.preferredHeight: root.gaugeSize

            UsageArc {
                anchors.fill: parent
                percent: root.percent
                accentColor: root.accentColor
                trackColor: Config.styling.bg4
                strokeWidth: Math.max(5, width * 0.09)
            }

            Text {
                anchors.centerIn: parent
                text: root.valueText
                color: root.accentColor
                font.pixelSize: root.valueText.length > 5 ? 13 : 16
                font.bold: true
                font.family: "monospace"
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.detail !== ""
            text: root.detail
            color: Config.styling.text2
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }
}
