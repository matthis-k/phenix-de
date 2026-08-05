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

    NetworkInteractionState {
        id: interactionState
        networks: NetworkService.networks
        networkKeyFn: NetworkService.networkKey
    }

    readonly property var displayedNetworks: interactionState.displayedNetworks(NetworkService.networks)
    readonly property var connectedNetworks: displayedNetworks.filter(network => network.connected)
    readonly property var disconnectedNetworks: displayedNetworks.filter(network => !network.connected)

    onDisplayedNetworksChanged: {
        if (interactionState.expandedNetworkKey
                && !displayedNetworks.some(network => interactionState.networkKey(network) === interactionState.expandedNetworkKey))
            interactionState.expandedNetworkKey = "";
        if (interactionState.interactiveNetworkKey
                && !displayedNetworks.some(network => interactionState.networkKey(network) === interactionState.interactiveNetworkKey))
            interactionState.unlockInteraction();
    }

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
            visible: true
            detailed: vpnDetails.detailed
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
