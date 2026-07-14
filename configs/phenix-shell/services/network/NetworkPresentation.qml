import QtQml
import qs.services

QtObject {
    readonly property var tracer: Logger.scope("network.presentation", { category: "network" })
    readonly property var prof: Profiler.scope("network.presentation", { category: "network" })

    function signalBucket(strength) {
        const normalized = Math.max(0, Math.min(1, strength || 0));
        const percent = Math.round(normalized * 100);
        if (percent === 0)
            return "none";
        if (percent < 25)
            return "weak";
        if (percent < 50)
            return "ok";
        if (percent < 75)
            return "good";
        return "excellent";
    }

    function wifiIconName(network) {
        return `network-wireless-signal-${signalBucket(network ? network.signalStrength : 0)}-symbolic`;
    }

    function securityNeedsPsk(security) {
        return security.includes("WPA") || security.includes("WPA2") || security.includes("SAE") || security.includes("wpa-psk") || security.includes("wpa2-psk") || security.includes("sae");
    }

    function isOpenNetwork(network) {
        return network && (network.security === "Open" || network.security === "--" || !network.security);
    }

    function securityLabel(network) {
        if (!network)
            return "Unknown";
        if (isOpenNetwork(network))
            return "Open";
        return network.security;
    }

    function wifiBand(frequency) {
        const mhz = parseInt(frequency || "0", 10);
        if (mhz >= 5925)
            return "6 GHz";
        if (mhz >= 5000)
            return "5 GHz";
        if (mhz >= 2400)
            return "2.4 GHz";
        return "unknown";
    }

    function wifiChannel(frequency) {
        const mhz = parseInt(frequency || "0", 10);
        if (mhz === 2484)
            return 14;
        if (mhz >= 2412 && mhz <= 2472)
            return Math.floor((mhz - 2407) / 5);
        if (mhz >= 5000 && mhz <= 5895)
            return Math.floor((mhz - 5000) / 5);
        if (mhz >= 5955 && mhz <= 7115)
            return Math.floor((mhz - 5950) / 5);
        return "unknown";
    }

    function connectivityLabel(connectivity) {
        if (connectivity === "full")
            return "Connected";
        if (connectivity === "portal")
            return "Captive portal";
        if (connectivity === "limited")
            return "Limited";
        if (connectivity === "none")
            return "No internet";
        return connectivity;
    }

    function primaryNetworkInfo(network) {
        if (!network)
            return "Network unavailable";
        return [`Frequency: ${network.frequency || "unknown"} MHz`, `Channel: ${wifiChannel(network.frequency)}`, `Band: ${wifiBand(network.frequency)}`].join(" | ");
    }

    function advancedNetworkInfo(network) {
        if (!network)
            return "Network unavailable";
        return [`SSID: ${network.ssid || "unknown"}`, `BSSID: ${network.bssid || "unknown"}`].join("\n");
    }
}
