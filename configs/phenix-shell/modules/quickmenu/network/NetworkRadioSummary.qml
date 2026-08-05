import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.services

RowLayout {
    id: root

    required property var network
    readonly property string frequency: network
        ? String(network.frequency || "")
        : ""

    Layout.fillWidth: true
    spacing: Config.spacing.xs

    RadioMetric {
        label: qsTr("Frequency")
        value: root.frequency !== ""
            ? `${root.frequency} MHz`
            : qsTr("Unknown")
    }

    RadioMetric {
        label: qsTr("Channel")
        value: String(NetworkService.wifiChannel(root.frequency))
    }

    RadioMetric {
        label: qsTr("Band")
        value: NetworkService.wifiBand(root.frequency)
    }

    component RadioMetric: ColumnLayout {
        id: radioMetric

        required property string label
        required property string value

        Layout.fillWidth: true
        Layout.minimumWidth: 64
        spacing: 0

        Text {
            Layout.fillWidth: true
            text: radioMetric.label
            color: Config.styling.text2
            font.pixelSize: 10
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            Layout.fillWidth: true
            text: radioMetric.value
            color: Config.styling.text0
            font.pixelSize: 12
            font.bold: true
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
