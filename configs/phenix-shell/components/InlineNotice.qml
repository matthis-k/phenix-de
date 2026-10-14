import QtQuick
import QtQuick.Layouts
import qs.services

// Semantic inline feedback (not a notification center or an alert dialog).
Rectangle {
    id: root

    property string title: ""
    property string message: ""
    property string severity: "info" // info, success, warning, error
    property Component action: null
    readonly property color tone: severity === "error" ? Config.styling.critical
        : severity === "warning" ? Config.styling.warning
        : severity === "success" ? Config.styling.good
        : Config.styling.info
    readonly property string toneIcon: severity === "error" ? "material:error"
        : severity === "warning" ? "material:warning"
        : severity === "success" ? "material:check_circle"
        : "material:info"

    color: Config.styling.bg2
    radius: Config.shape.square
    border.width: 1
    border.color: tone
    implicitHeight: noticeRow.implicitHeight + Config.spacing.sm * 2
    implicitWidth: noticeRow.implicitWidth + Config.spacing.sm * 2
    Layout.fillWidth: true

    Accessible.role: Accessible.StaticText
    Accessible.name: root.title + (root.message !== "" ? ": " + root.message : "")

    RowLayout {
        id: noticeRow
        anchors.fill: parent
        anchors.margins: Config.spacing.sm
        spacing: Config.spacing.sm

        Icon {
            iconName: root.toneIcon
            color: root.tone
            implicitSize: Config.iconSizes.control
            Layout.alignment: Qt.AlignTop
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Config.spacing.xxs

            Text {
                visible: text !== ""
                text: root.title
                Layout.fillWidth: true
                color: root.tone
                font.bold: true
                font.pixelSize: Config.typography.label
                font.family: Config.typography.mono
                wrapMode: Text.WordWrap
            }

            Text {
                visible: text !== ""
                text: root.message
                Layout.fillWidth: true
                color: Config.styling.text0
                font.pixelSize: Config.typography.secondary
                wrapMode: Text.WordWrap
            }
        }

        Loader {
            active: root.action !== null
            sourceComponent: root.action
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: item ? item.implicitWidth : 0
            Layout.preferredHeight: item ? item.implicitHeight : 0
        }
    }
}
