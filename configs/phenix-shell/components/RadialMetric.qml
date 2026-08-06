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
    property bool compact: false
    property real gaugeSize: root.compact ? 46 : 64

    implicitWidth: root.compact ? 76 : 108
    implicitHeight: root.compact
        ? 88
        : (root.detail !== "" ? 140 : 122)
    color: Config.styling.bg2
    radius: Config.styling.radius
    border.width: emphasized ? 2 : 1
    border.color: emphasized ? accentColor : Config.styling.bg3

    Accessible.name: root.label
    Accessible.description: root.detail

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.compact ? Config.spacing.xs : Config.spacing.sm
        spacing: root.compact ? 2 : 4

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 18

            Icon {
                visible: root.iconName !== ""
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                iconName: root.iconName
                fallbackIconName: root.iconName
                color: root.accentColor
                implicitSize: root.compact ? 14 : 16
            }

            Text {
                anchors.fill: parent
                anchors.leftMargin: root.iconName !== "" ? 16 : 0
                anchors.rightMargin: root.iconName !== "" ? 16 : 0
                text: root.label
                color: root.accentColor
                font.pixelSize: root.compact ? 11 : 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
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
                trackColor: Config.colorWithOpacity(root.accentColor, 0.2)
                strokeWidth: root.compact
                    ? Math.max(6, width * 0.13)
                    : Math.max(7, width * 0.11)
            }

            Text {
                anchors.fill: parent
                text: root.valueText
                color: root.accentColor
                font.pixelSize: root.compact
                    ? (root.valueText.length > 5 ? 8 : 10)
                    : (root.valueText.length > 5 ? 11 : 13)
                font.bold: true
                font.family: "monospace"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
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
