import QtQml
import qs.services
import "../../logic/EvaluationProfiles.js" as EvalProfiles

QtObject {
    id: root

    readonly property var tracer: Logger.scope("backend.actions.network", { category: "backend" })
    readonly property var prof: Profiler.scope("backend.actions.network", { category: "backend" })

    function roots(context) {
        tracer.trace("roots", function() { return {}; });
        return [{
            id: "network",
            display: {
                title: qsTr("Networking"),
                icon: "network-wireless-symbolic",
                iconColor: Config.styling.primaryAccent
            },
            match: {
                aliases: ["net", "network", "networking"],
                evaluationProfile: EvalProfiles.groupProfile()
            },
            template: "flat-action-group",
            behavior: { filterChildren: true },
            children: [wifiNode(), vpnNode(), bluetoothNode()]
        }];
    }

    function wifiNode() {
        return {
            id: "wifi",
            display: {
                title: qsTr("Wi-Fi"),
                icon: "network-wireless-symbolic",
                iconColor: NetworkService.wifiEnabled ? Config.styling.primaryAccent : Config.styling.text1
            },
            match: { aliases: ["wifi", "wi-fi"] },
            template: "switch",
            switchState: NetworkService.wifiEnabled,
            switchActions: {
                toggle: switchAction("toggle", qsTr("Toggle"), null,
                    { service: "network", op: "toggleWifi" },
                    ["toggle", "switch"], null),
                on: switchAction("on", qsTr("Turn on"), true,
                    { service: "network", op: "setWifiEnabled", enabled: true },
                    ["on", "enable", "start"],
                    { title: qsTr("Turn Wi-Fi on"), subtitle: qsTr("Enable wireless networking"), icon: "network-wireless-symbolic" }),
                off: switchAction("off", qsTr("Turn off"), false,
                    { service: "network", op: "setWifiEnabled", enabled: false },
                    ["off", "disable", "stop"],
                    { title: qsTr("Turn Wi-Fi off"), subtitle: qsTr("Disable wireless networking"), icon: "network-wireless-offline-symbolic" })
            }
        };
    }

    function vpnNode() {
        return {
            id: "vpn",
            display: {
                title: qsTr("VPN"),
                subtitle: VpnService.connected && VpnService.country ? VpnService.country : "",
                icon: "network-vpn-symbolic",
                iconColor: VpnService.connected || VpnService.connecting ? Config.styling.good : Config.styling.warning
            },
            match: {
                aliases: ["vpn", "connect to"],
                evaluationProfile: EvalProfiles.switchProfile()
            },
            template: "switch",
            switchState: VpnService.connected || VpnService.connecting,
            behavior: {
                filterChildren: true,
                depthPenalty: 1,
                exploration: { descend: false },
                intentProjection: {
                    subjects: "children",
                    requireParentMatch: true,
                    minParentScore: 0.05,
                    minSubjectScore: 0.18,
                    minResidualCoverage: 1,
                    unusedTokenPenalty: 0.1
                }
            },
            switchActions: {
                toggle: switchAction("toggle", qsTr("Toggle"), null,
                    { service: "vpn", op: "toggle" },
                    ["toggle", "switch"], null),
                on: switchAction("on", qsTr("Connect"), true,
                    { service: "vpn", op: "connect" },
                    ["on", "connect", "start"],
                    { title: qsTr("Connect VPN"), subtitle: qsTr("Connect using the default destination"), icon: "network-vpn-symbolic" }),
                off: switchAction("off", qsTr("Disconnect"), false,
                    { service: "vpn", op: "disconnect" },
                    ["off", "disconnect", "stop"],
                    { title: qsTr("Disconnect VPN"), subtitle: qsTr("End the active VPN connection"), icon: "network-vpn-symbolic" })
            },
            children: vpnChildren()
        };
    }

    function bluetoothNode() {
        return {
            id: "bluetooth",
            display: {
                title: qsTr("Bluetooth"),
                icon: BluetoothService.iconName,
                iconColor: BluetoothService.enabled ? Config.styling.bluetooth : Config.styling.text1
            },
            match: { aliases: ["bt", "bluetooth"] },
            template: "switch",
            switchState: BluetoothService.enabled,
            switchActions: {
                toggle: switchAction("toggle", qsTr("Toggle"), null,
                    { service: "bluetooth", op: "toggle" },
                    ["toggle", "switch"], null),
                on: switchAction("on", qsTr("Turn on"), true,
                    { service: "bluetooth", op: "setEnabled", enabled: true },
                    ["on", "enable", "start"],
                    { title: qsTr("Turn Bluetooth on"), subtitle: qsTr("Enable Bluetooth devices"), icon: BluetoothService.iconName }),
                off: switchAction("off", qsTr("Turn off"), false,
                    { service: "bluetooth", op: "setEnabled", enabled: false },
                    ["off", "disable", "stop"],
                    { title: qsTr("Turn Bluetooth off"), subtitle: qsTr("Disable Bluetooth devices"), icon: BluetoothService.iconName })
            }
        };
    }

    function vpnChildren() {
        return (VpnService.destinations || []).slice().sort(function(a, b) {
            return root.vpnDestinationRank(a) - root.vpnDestinationRank(b)
                || String(a.label || a.name || "").localeCompare(String(b.label || b.name || ""));
        }).map(function(destination) {
            var name = destination.label || destination.name || destination.value;
            var subtitle = root.vpnDestinationSubtitle(destination);
            var active = root.vpnDestinationActive(destination);
            return {
                id: destination.name,
                display: {
                    title: name,
                    subtitle: subtitle,
                    icon: "network-vpn-symbolic",
                    iconColor: active ? Config.styling.good : destination.kind === "group" ? Config.styling.info : Config.styling.text1
                },
                match: {
                    aliases: [destination.name, destination.label, destination.value].filter(Boolean),
                    evaluationProfile: EvalProfiles.switchProfile()
                },
                template: "switch",
                switchState: active,
                switchActions: {
                    on: switchAction("on", qsTr("Connect"), true,
                        { service: "vpn", op: "connect", destination: destination.value },
                        ["on", "connect", "start"],
                        { title: qsTr("Connect to VPN %1").arg(name), subtitle: subtitle, icon: "network-vpn-symbolic" }),
                    off: switchAction("off", qsTr("Disconnect"), false,
                        { service: "vpn", op: "disconnect", destination: destination.value },
                        ["off", "disconnect", "stop"],
                        { title: qsTr("Disconnect from VPN %1").arg(name), subtitle: subtitle, icon: "network-vpn-symbolic" })
                }
            };
        });
    }

    function vpnDestinationActive(destination) {
        if (!VpnService.connected || destination.kind !== "country")
            return false;
        return normalize(destination.value) === normalize(VpnService.country);
    }

    function vpnDestinationSubtitle(destination) {
        if (destination.kind === "fastest")
            return qsTr("Fastest available destination");
        if (destination.kind === "group")
            return qsTr("VPN region");
        return qsTr("VPN country");
    }

    function vpnDestinationRank(destination) {
        return destination.kind === "fastest" ? 0 : destination.kind === "group" ? 1 : 2;
    }

    function normalize(value) {
        return String(value || "").trim().toLowerCase();
    }

    function switchAction(id, title, state, payload, aliases, presentation) {
        return {
            id: id,
            title: title,
            state: state,
            aliases: aliases || [],
            presentation: presentation || null,
            payload: payload || {}
        };
    }
}
