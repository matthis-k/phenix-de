import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell

import qs.services
import qs.components
import "network"

DashboardPage {
    id: root

    title: qsTr("Networking")
    subtitle: root.detailed
        ? qsTr("Interfaces, link metadata, throughput, VPN, and connection controls")
        : qsTr("Select and manage the active connection")
    fillHeight: true
    headerAccessory: Component {
        DashboardToggleSwitch {
            Accessible.name: qsTr("Networking")
            checked: NetworkService.networkingEnabled
            onToggled: NetworkService.setNetworkingEnabled(checked)
        }
    }

    readonly property int contentWidth: width > 0 ? width : 320
    readonly property int itemSpacing: 3
    readonly property int rowHeight: 36
    readonly property int iconSlotWidth: 28
    readonly property int iconSize: 20
    readonly property int itemIconSize: 22
    readonly property int itemTextSize: 16
    readonly property int itemSubtextSize: 12
    readonly property int iconTextGap: 10
    readonly property int horizontalPadding: 8
    readonly property int verticalPadding: 4
    readonly property var connectedWifi: NetworkService.connectedNetwork
    readonly property var activeInterface: {
        const _ = NetworkInterfaces.revision;
        return NetworkInterfaces.activeInterface();
    }

    NetworkInteractionState {
        id: interactionState
        networks: NetworkService.networks
        networkKeyFn: NetworkService.networkKey
    }

    readonly property var displayedNetworks: interactionState.displayedNetworks(NetworkService.networks)
    readonly property var connectedNetworks: displayedNetworks.filter(network => network.connected)
    readonly property var disconnectedNetworks: displayedNetworks.filter(network => !network.connected)

    Connections {
        target: interactionState
        function onInteractiveNetworkKeyChanged() {
            if (interactionState.interactiveNetworkKey
                    && !NetworkService.networks.some(network => interactionState.networkKey(network) === interactionState.interactiveNetworkKey))
                interactionState.unlockInteraction();
        }
    }

    WifiSection {
        Layout.fillWidth: true
        interactionState: interactionState
        networks: NetworkService.networks
        connectedNetworks: root.connectedNetworks
        disconnectedNetworks: root.disconnectedNetworks
        contentWidth: root.contentWidth
        itemSpacing: root.itemSpacing
        rowHeight: root.rowHeight
        iconSlotWidth: root.iconSlotWidth
        itemIconSize: root.itemIconSize
        itemTextSize: root.itemTextSize
        itemSubtextSize: root.itemSubtextSize
        iconTextGap: root.iconTextGap
        horizontalPadding: root.horizontalPadding
        verticalPadding: root.verticalPadding
        tabSwipeTarget: root.tabSwipeTarget
    }

    DashboardSection {
        id: connectionDetails
        Layout.fillWidth: true
        title: qsTr("Interface diagnostics")
        visible: NetworkService.connected
        showDetailToggle: true
        summary: Component {
            Text {
                width: Math.min(implicitWidth, 190)
                text: NetworkService.hasWiredConnection
                    ? NetworkService.wiredDeviceName
                    : NetworkService.connectedSsid
                color: Config.styling.good
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
        headerAccessory: Component {
            SmallButton {
                visible: NetworkService.hasWiredConnection
                text: qsTr("Disconnect")
                accessibleName: qsTr("Disconnect wired connection")
                onClicked: NetworkService.disconnectWired()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: connectionDetails.detailed
            spacing: Config.spacing.xs

            InfoRow {
                Layout.fillWidth: true
                iconName: NetworkService.hasWiredConnection
                    ? "network-wired-symbolic"
                    : "network-wireless-symbolic"
                label: qsTr("Interface")
                value: root.activeInterface
                    ? root.activeInterface.name
                    : (NetworkService.hasWiredConnection
                        ? NetworkService.wiredDeviceName
                        : NetworkService.wifiDeviceName)
            }

            InfoRow {
                Layout.fillWidth: true
                visible: !!root.activeInterface && root.activeInterface.mac !== ""
                iconName: "network-server-symbolic"
                label: qsTr("Interface MAC")
                value: root.activeInterface ? root.activeInterface.mac : ""
            }

            InfoRow {
                Layout.fillWidth: true
                visible: !!root.activeInterface
                iconName: "network-server-symbolic"
                label: qsTr("IPv4")
                value: root.activeInterface
                    ? NetworkInterfaces.formatAddresses(root.activeInterface.ipv4)
                    : qsTr("Unavailable")
            }

            InfoRow {
                Layout.fillWidth: true
                visible: !!root.activeInterface && root.activeInterface.ipv6.length > 0
                iconName: "network-server-symbolic"
                label: qsTr("IPv6")
                value: root.activeInterface
                    ? NetworkInterfaces.formatAddresses(root.activeInterface.ipv6)
                    : qsTr("Unavailable")
            }

            InfoRow {
                Layout.fillWidth: true
                visible: !!root.activeInterface
                iconName: "dialog-information-symbolic"
                label: qsTr("Link state / MTU")
                value: root.activeInterface
                    ? `${root.activeInterface.state} · ${root.activeInterface.mtu}`
                    : ""
            }

            InfoRow {
                Layout.fillWidth: true
                visible: !NetworkService.hasWiredConnection && NetworkService.connectedAddress !== ""
                iconName: "network-wireless-symbolic"
                label: qsTr("Access point BSSID")
                value: NetworkService.connectedAddress
            }

            InfoRow {
                Layout.fillWidth: true
                visible: !!root.connectedWifi
                iconName: "dialog-information-symbolic"
                label: qsTr("Radio link")
                value: root.connectedWifi
                    ? NetworkService.primaryNetworkInfo(root.connectedWifi)
                    : ""
            }

            InfoRow {
                Layout.fillWidth: true
                visible: !!root.connectedWifi
                iconName: "changes-prevent-symbolic"
                label: qsTr("Security")
                value: root.connectedWifi
                    ? NetworkService.securityLabel(root.connectedWifi)
                    : ""
            }

            InfoRow {
                Layout.fillWidth: true
                visible: !!root.connectedWifi
                iconName: "network-wireless-signal-excellent-symbolic"
                label: qsTr("Signal")
                value: root.connectedWifi
                    ? `${Math.round(Number(root.connectedWifi.signalStrength || 0) * 100)}%`
                    : ""
            }

            InfoRow {
                Layout.fillWidth: true
                iconName: "network-transmit-receive-symbolic"
                label: qsTr("Connectivity")
                value: NetworkService.connectivity
            }

            InfoRow {
                Layout.fillWidth: true
                iconName: "go-down-symbolic"
                label: qsTr("Download")
                value: Stats.formatRate(Stats.rxBytesPerSecond)
            }

            InfoRow {
                Layout.fillWidth: true
                iconName: "go-up-symbolic"
                label: qsTr("Upload")
                value: Stats.formatRate(Stats.txBytesPerSecond)
            }

            InfoRow {
                Layout.fillWidth: true
                visible: NetworkInterfaces.lastError !== ""
                iconName: "dialog-warning-symbolic"
                label: qsTr("Diagnostics")
                value: NetworkInterfaces.lastError
                valueColor: Config.styling.warning
            }
        }
    }

    DashboardSection {
        id: vpnDetails
        Layout.fillWidth: true
        title: qsTr("NordVPN")
        visible: VpnService.available || VpnService.connected || VpnService.connecting
        showDetailToggle: true
        summary: Component {
            Text {
                width: Math.min(implicitWidth, 220)
                text: VpnService.connected
                    ? `${VpnService.country} • ${VpnService.server}`
                    : VpnService.statusText
                color: VpnService.connected ? Config.styling.good : Config.styling.text1
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        VpnSection {
            Layout.fillWidth: true
            visible: vpnDetails.detailed || VpnService.connected || VpnService.connecting
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
    }
}
