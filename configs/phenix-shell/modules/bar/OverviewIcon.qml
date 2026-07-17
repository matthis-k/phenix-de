import qs.services

StatusIcon {
    id: root
    readonly property bool muted: AudioService.outputMuted
    readonly property bool batteryCritical: PowerService.hasBattery && PowerService.batteryPercent <= 10
    readonly property bool networkOffline: !NetworkService.connectedSsid && !NetworkService.hasWiredConnection

    label: qsTr("Quick Settings")
    iconName: "view-grid-symbolic"
    iconColor: {
        if (NotificationCenter.hasCritical || batteryCritical)
            return Config.styling.critical;
        if (muted || networkOffline)
            return Config.styling.warning;
        return Config.styling.primaryAccent;
    }
    tabName: "overview"
}
