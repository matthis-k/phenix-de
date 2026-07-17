import qs.services

StatusIcon {
    id: root

    readonly property var connectedNetwork: NetworkService.connectedNetwork

    label: VpnService.connected ? qsTr("Network and VPN") : qsTr("Network")
    iconName: {
        if (NetworkService.hasWiredConnection)
            return "network-wired-symbolic";

        if (!NetworkService.wifiHardwareEnabled)
            return "network-wireless-disabled-symbolic";

        if (connectedNetwork)
            return NetworkService.wifiIconName(connectedNetwork);

        return NetworkService.wifiEnabled ? "network-wireless-offline-symbolic" : "network-wireless-disabled-symbolic";
    }
    tabName: "wifi"
    overlayIconName: VpnService.available ? "network-vpn-symbolic" : ""
    overlayIconColor: VpnService.connected ? Config.styling.good : Config.styling.critical
}
