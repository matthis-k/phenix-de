import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell

import qs.services
import qs.components
import qs.animations as Animations

ColumnLayout {
    id: root

    property var tabSwipeTarget: null
    property int itemSpacing: 3
    property int rowHeight: 36
    property int itemIconSize: 22
    property int itemTextSize: 16
    property int itemSubtextSize: 12
    property int iconTextGap: 10
    property int horizontalPadding: 8
    property int verticalPadding: 4

    spacing: Config.spacing.xs

    RowLayout {
        Layout.fillWidth: true
        spacing: root.itemSpacing

        Icon {
            Layout.preferredWidth: root.itemIconSize
            Layout.preferredHeight: root.itemIconSize
            iconName: VpnService.connected ? "network-vpn-symbolic" : "network-vpn-disconnected-symbolic"
            color: VpnService.connected ? Config.styling.good : Config.styling.text1
            implicitSize: root.itemIconSize
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text: VpnService.connecting ? "Connecting" : VpnService.connected ? "Connected" : "Disconnected"
                color: VpnService.connected ? Config.styling.good : Config.styling.text0
                font.pixelSize: root.itemTextSize
                font.bold: true
            }

            Text {
                Layout.fillWidth: true
                visible: VpnService.connected
                text: VpnService.location
                color: Config.styling.text2
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        SmallButton {
            enabled: !VpnService.connecting
            text: VpnService.connecting ? "Connecting" : VpnService.connected ? "Disconnect" : "Connect"
            onClicked: VpnService.connected ? VpnService.disconnect() : VpnService.connect(null)
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Config.styling.bg3
    }

    VpnDestinationList {
        id: vpnDestinations
        Layout.fillWidth: true
        tabSwipeTarget: root.tabSwipeTarget
        itemSpacing: root.itemSpacing
        rowHeight: root.rowHeight
        itemIconSize: root.itemIconSize
        itemTextSize: root.itemTextSize
        itemSubtextSize: root.itemSubtextSize
        iconTextGap: root.iconTextGap
        horizontalPadding: root.horizontalPadding
        verticalPadding: root.verticalPadding
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Config.styling.bg3
    }

    InfoRow {
        Layout.fillWidth: true
        label: "Server"
        value: VpnService.server
    }

    InfoRow {
        Layout.fillWidth: true
        label: "Hostname"
        value: VpnService.hostname
    }

    InfoRow {
        Layout.fillWidth: true
        label: "IP"
        value: VpnService.ip
    }

    InfoRow {
        Layout.fillWidth: true
        label: "Technology"
        value: VpnService.technology
    }

    InfoRow {
        Layout.fillWidth: true
        label: "Protocol"
        value: VpnService.protocol
    }
}
