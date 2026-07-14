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
        title: "NordVPN"
        visible: VpnService.available || VpnService.connecting
        collapsible: true
        collapsed: true
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
                        text: NetworkService.wiredAddress || ""
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
