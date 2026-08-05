import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.services
import qs.components

RowLayout {
    id: root

    property real downloadRate: 0
    property real uploadRate: 0
    property real signalStrength: 0
    property bool showSignal: false
    property color accentColor: Config.colors.blue

    Layout.fillWidth: true
    spacing: Config.spacing.sm

    Metric {
        Layout.fillWidth: true
        iconName: "go-up-symbolic"
        value: Stats.formatRate(root.uploadRate)
        accessibleLabel: qsTr("Upload")
    }

    Metric {
        Layout.fillWidth: true
        iconName: "go-down-symbolic"
        value: Stats.formatRate(root.downloadRate)
        accessibleLabel: qsTr("Download")
    }

    Metric {
        Layout.fillWidth: true
        visible: root.showSignal
        iconName: "network-wireless-signal-excellent-symbolic"
        value: `${Math.round(root.signalStrength * 100)}%`
        accessibleLabel: qsTr("Signal strength")
    }

    component Metric: RowLayout {
        required property string iconName
        required property string value
        required property string accessibleLabel

        spacing: Config.spacing.xxs

        Icon {
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            iconName: parent.iconName
            color: root.accentColor
            implicitSize: 16
        }

        Text {
            Layout.fillWidth: true
            text: parent.value
            color: Config.styling.text0
            font.pixelSize: 12
            font.bold: true
            elide: Text.ElideRight
            Accessible.name: parent.accessibleLabel
        }
    }
}
