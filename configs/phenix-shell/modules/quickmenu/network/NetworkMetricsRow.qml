import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.services
import qs.components

Item {
    id: root

    property real downloadRate: 0
    property real uploadRate: 0
    property real signalStrength: 0
    property bool showSignal: false
    property color accentColor: Config.colors.blue
    property int metricMinimumWidth: 82
    property int metricPreferredWidth: 96
    readonly property int visibleMetricCount: showSignal ? 3 : 2

    Layout.fillWidth: true
    implicitHeight: metrics.implicitHeight

    RowLayout {
        id: metrics

        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(
            root.width,
            root.visibleMetricCount * root.metricPreferredWidth
                + (root.visibleMetricCount - 1) * spacing)
        spacing: Config.spacing.xs

        Metric {
            iconName: "go-up-symbolic"
            value: Stats.formatRate(root.uploadRate)
            accessibleLabel: qsTr("Upload")
        }

        Metric {
            iconName: "go-down-symbolic"
            value: Stats.formatRate(root.downloadRate)
            accessibleLabel: qsTr("Download")
        }

        Metric {
            visible: root.showSignal
            iconName: "network-wireless-signal-excellent-symbolic"
            value: `${Math.round(root.signalStrength * 100)}%`
            accessibleLabel: qsTr("Signal strength")
        }
    }

    component Metric: Item {
        id: metric

        required property string iconName
        required property string value
        required property string accessibleLabel

        Layout.fillWidth: true
        Layout.minimumWidth: root.metricMinimumWidth
        Layout.preferredWidth: root.metricPreferredWidth
        implicitHeight: metricContent.implicitHeight

        RowLayout {
            id: metricContent
            anchors.centerIn: parent
            spacing: Config.spacing.xxs

            Icon {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                iconName: metric.iconName
                color: root.accentColor
                implicitSize: 16
            }

            Text {
                text: metric.value
                color: Config.styling.text0
                font.pixelSize: 12
                font.bold: true
                Accessible.name: metric.accessibleLabel
            }
        }
    }
}
