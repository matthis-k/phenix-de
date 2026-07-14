pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services

Singleton {
    id: root

    readonly property var tracer: Logger.scope("vpn.service", { category: "vpn" })
    readonly property var prof: Profiler.scope("vpn.service", { category: "vpn" })

    readonly property var backend: NordVPN

    readonly property bool available: NordVPN.available
    readonly property bool connected: NordVPN.connected
    readonly property bool connecting: NordVPN.connecting
    readonly property bool busy: NordVPN.busy
    readonly property string currentOperationKind: NordVPN.currentOperationKind
    readonly property string currentOperationTarget: NordVPN.currentOperationTarget
    readonly property bool currentOperationRunning: NordVPN.currentOperationRunning
    readonly property string currentOperationLastError: NordVPN.currentOperationLastError
    readonly property var operation: NordVPN.operation

    readonly property string providerName: "NordVPN"

    readonly property string state: {
        if (connecting) return "connecting";
        if (connected) return "connected";
        if (available) return "disconnected";
        return "unavailable";
    }

    readonly property string location: NordVPN.country ? `${NordVPN.city}, ${NordVPN.country}` : ""
    readonly property string country: NordVPN.country
    readonly property string city: NordVPN.city
    readonly property string server: NordVPN.server
    readonly property string hostname: NordVPN.hostname
    readonly property string ip: NordVPN.ip
    readonly property string technology: NordVPN.technology
    readonly property string protocol: NordVPN.protocol

    readonly property var destinations: normalizeDestinations()

    function normalizeDestinations() {
        const result = [];
        const nordDests = NordVPN.destinations || [];
        for (const d of nordDests) {
            result.push({
                id: d.kind === "fastest" ? "fastest" : `${d.kind}-${d.value}`,
                name: d.name,
                value: d.value,
                kind: d.kind,
                label: destinationLabel(d),
                subtext: destinationSubtext(d)
            });
        }
        return result;
    }

    readonly property string iconName: connected ? "network-vpn-symbolic" : "network-vpn-disconnected-symbolic"
    readonly property color iconColor: connected ? Config.styling.good : (connecting ? Config.styling.warning : Config.styling.text1)

    readonly property string label: providerName
    readonly property string statusText: {
        if (connecting) return "Connecting";
        if (connected) return `${country} • ${server}`;
        return "Disconnected";
    }

    readonly property var presentation: {
        return {
            icon: root.iconName,
            color: root.iconColor,
            label: root.label,
            status: root.statusText,
            state: root.state,
            available: root.available,
            connected: root.connected,
            connecting: root.connecting,
            location: root.location,
            server: root.server,
            country: root.country
        };
    }

    function refresh() {
        root.tracer.trace("refresh");
        NordVPN.refreshStatus();
    }

    function connect(destinationId) {
        if (root.connecting) {
            root.tracer.warn("connect.alreadyConnecting");
            return;
        }

        const dests = NordVPN.destinations || [];
        let destination = null;
        if (destinationId && destinationId !== "fastest") {
            const found = dests.find(d => d.value === destinationId || d.name === destinationId);
            if (found)
                destination = found.value;
        }
        root.tracer.info("connect", function() { return { destination: destination || "fastest", destinationId: destinationId } });
        NordVPN.connect(destination);
    }

    function disconnect() {
        root.tracer.info("disconnect");
        NordVPN.disconnect();
    }

    function toggle() {
        root.tracer.info("toggle");
        if (root.connected || root.connecting)
            root.disconnect();
        else
            root.connect(null);
    }

    function executePayload(payload) {
        if (!payload || payload.service !== "vpn") {
            if (payload) root.tracer.warn("executePayload.wrongService", function() { return { service: payload.service } });
            return false;
        }

        root.tracer.debug("executePayload", function() { return { op: payload.op } });
        switch (payload.op) {
        case "connect":
            root.connect(payload.destination || null);
            return true;
        case "disconnect":
            root.disconnect();
            return true;
        case "toggle":
            root.toggle();
            return true;
        default:
            root.tracer.warn("executePayload.unknownOp", function() { return { op: payload.op } });
            return false;
        }
    }

    function destinationLabel(destination) {
        if (!destination)
            return "Unknown";
        if (destination.kind === "fastest")
            return "Fastest server";
        return destination.name;
    }

    function destinationSubtext(destination) {
        if (!destination)
            return "";
        if (destination.kind === "fastest")
            return "Automatic";
        if (destination.kind === "country")
            return "Country";
        return "Group";
    }
}
