import QtQml
import qs.services

QtObject {
    id: root
    readonly property var tracer: Logger.scope("network.models", { category: "network" })
    readonly property var prof: Profiler.scope("network.models", { category: "network" })

    function networkKey(network) {
        return `${network?.frequency || "unknown"}:${network?.ssid || "Hidden network"}:${network?.bssid || ""}`;
    }

    function networkId(network) {
        return `wifi-${network.bssid || network.frequency}-${network.ssid}`;
    }

    function mergeWifiNetworks(existingNetworks, parsedNetworks, presentation) {
        const byKey = new Map();
        for (let i = 0; i < (existingNetworks || []).length; ++i)
            byKey.set(networkKey(existingNetworks[i]), existingNetworks[i]);

        const result = [];
        for (let i = 0; i < (parsedNetworks || []).length; ++i) {
            const parsed = parsedNetworks[i];
            const key = networkKey(parsed);
            const network = byKey.get(key) || {
                id: networkId(parsed)
            };
            const secured = parsed.security !== "Open" && parsed.security !== "--";

            network.connected = parsed.connected;
            network.signalStrength = parsed.signalStrength;
            network.frequency = parsed.frequency;
            network.ssid = parsed.ssid;
            network.bssid = parsed.bssid;
            network.security = parsed.security;
            network.name = parsed.ssid;
            network.known = network.known || false;
            network.secured = secured;
            network.strength = Math.round(parsed.signalStrength * 100);
            network.band = presentation.wifiBand(parsed.frequency);
            network.channel = presentation.wifiChannel(parsed.frequency);
            network.iconName = presentation.wifiIconName({
                signalStrength: parsed.signalStrength
            });
            network.statusText = parsed.connected ? "Connected" : (secured ? "Secured" : "Open");
            result.push(network);
        }

        root.tracer.trace("networksMerged", function() { return { existing: (existingNetworks || []).length, parsed: (parsedNetworks || []).length, merged: result.length } });
        return result;
    }
}
