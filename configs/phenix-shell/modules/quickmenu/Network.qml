import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell

import qs.animations as Animations
import qs.services
import qs.components
import "network"

DashboardPage {
    id: root

    title: "Networking"
    subtitle: root.detailed
        ? qsTr("Interfaces, link metadata, throughput, VPN, and connection controls")
        : qsTr("Select and manage the active connection")
    fillHeight: true
    headerAccessory: Component {
        DashboardToggleSwitch {
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
    readonly property var connectedNetworks: displayedNetworks.filter(n => n.connected)
    readonly property var disconnectedNetworks: displayedNetworks.filter(n => !n.connected)

    Connections {
        target: interactionState
        function onInteractiveNetworkKeyChanged() {
            if (interactionState.interactiveNetworkKey && !NetworkService.networks.some(network => interactionState.networkKey(network) === interactionState.interactiveNetworkKey))
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
        Layout.fillWidth: true
        title: "Connection details"
        visible: root.detailed && NetworkService.connected
        collapsible: true
        collapsed: false
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

        InfoRow {
            Layout.fillWidth: true
            iconName: NetworkService.hasWiredConnection
                ? "network-wired-symbolic"
                : "network-wireless-symbolic"
            label: "Interface"
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
            label: "Interface MAC"
            value: root.activeInterface ? root.activeInterface.mac : ""
        }

        InfoRow {
            Layout.fillWidth: true
            visible: !!root.activeInterface
            iconName: "network-server-symbolic"
            label: "IPv4"
            value: root.activeInterface
                ? NetworkInterfaces.formatAddresses(root.activeInterface.ipv4)
                : qsTr("Unavailable")
        }

        InfoRow {
            Layout.fillWidth: true
            visible: !!root.activeInterface && root.activeInterface.ipv6.length > 0
            iconName: "network-server-symbolic"
            label: "IPv6"
            value: root.activeInterface
                ? NetworkInterfaces.formatAddresses(root.activeInterface.ipv6)
                : qsTr("Unavailable")
        }

        InfoRow {
            Layout.fillWidth: true
            visible: !!root.activeInterface
            iconName: "dialog-information-symbolic"
            label: "Link state / MTU"
            value: root.activeInterface
                ? `${root.activeInterface.state} · ${root.activeInterface.mtu}`
                : ""
        }

        InfoRow {
            Layout.fillWidth: true
            visible: !NetworkService.hasWiredConnection && NetworkService.connectedAddress !== ""
            iconName: "network-wireless-symbolic"
            label: "Access point BSSID"
            value: NetworkService.connectedAddress
        }

        InfoRow {
            Layout.fillWidth: true
            visible: !!root.connectedWifi
            iconName: "dialog-information-symbolic"
            label: "Radio link"
            value: root.connectedWifi
                ? NetworkService.primaryNetworkInfo(root.connectedWifi)
                : ""
        }

        InfoRow {
            Layout.fillWidth: true
            visible: !!root.connectedWifi
            iconName: "changes-prevent-symbolic"
            label: "Security"
            value: root.connectedWifi
                ? NetworkService.securityLabel(root.connectedWifi)
                : ""
        }

        InfoRow {
            Layout.fillWidth: true
            visible: !!root.connectedWifi
            iconName: "network-wireless-signal-excellent-symbolic"
            label: "Signal"
            value: root.connectedWifi
                ? `${Math.round(Number(root.connectedWifi.signalStrength || 0) * 100)}%`
                : ""
        }

        InfoRow {
            Layout.fillWidth: true
            iconName: "network-transmit-receive-symbolic"
            label: "Connectivity"
            value: NetworkService.connectivity
        }

        InfoRow {
            Layout.fillWidth: true
            iconName: "go-down-symbolic"
            label: "Download"
            value: Stats.formatRate(Stats.rxBytesPerSecond)
        }

        InfoRow {
            Layout.fillWidth: true
            iconName: "go-up-symbolic"
            label: "Upload"
            value: Stats.formatRate(Stats.txBytesPerSecond)
        }

        InfoRow {
            Layout.fillWidth: true
            visible: NetworkInterfaces.lastError !== ""
            iconName: "dialog-warning-symbolic"
            label: "Diagnostics"
            value: NetworkInterfaces.lastError
            valueColor: Config.styling.warning
        }
    }

    DashboardSection {
        Layout.fillWidth: true
        title: "NordVPN"
        visible: (root.detailed && (VpnService.available || VpnService.connecting))
            || VpnService.connected
            || VpnService.connecting
        collapsible: true
        collapsed: !VpnService.connected
        summary: Component {
            Text {
                width: Math.min(implicitWidth, 220)
                text: VpnService.connected ? `${VpnService.country} • ${VpnService.server}` : VpnService.statusText
                color: VpnService.connected ? Config.styling.good : Config.styling.text1
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        VpnSection {
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
    }

    DashboardSection {
        Layout.fillWidth: true
        title: "Wired connection"
        visible: NetworkService.hasWiredConnection

        Rectangle {
            Layout.fillWidth: true
            color: Config.styling.bg3
            implicitHeight: root.rowHeight + root.horizontalPadding

            RowLayout {
                anchors.fill: parent
                anchors.margins: root.horizontalPadding
                spacing: root.iconTextGap

                Icon {
                    Layout.preferredWidth: root.itemIconSize
                    Layout.preferredHeight: root.itemIconSize
                    iconName: "network-wired-symbolic"
                    color: Config.colors.blue
                    implicitSize: root.itemIconSize
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: NetworkService.wiredDeviceName || "Wired"
                        color: Config.styling.text0
                        font.pixelSize: root.itemTextSize
                        font.bold: true
                    }

                    Text {
                        visible: root.detailed && text !== ""
                        text: root.activeInterface
                            ? NetworkInterfaces.formatAddresses(root.activeInterface.ipv4)
                            : (NetworkService.wiredAddress || "")
                        color: Config.styling.text2
                        font.pixelSize: 12
                    }
                }

                SmallButton {
                    text: "Disconnect"
                    onClicked: NetworkService.disconnectWired()
                }
            }
        }
    }
}
