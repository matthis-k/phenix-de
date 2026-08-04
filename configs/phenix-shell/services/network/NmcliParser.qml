import QtQml
import qs.services

QtObject {
    readonly property var tracer: Logger.scope("network.nmcliParser", { category: "network" })
    readonly property var prof: Profiler.scope("network.nmcliParser", { category: "network" })

    function splitEscaped(text, separator) {
        const result = [];
        let current = "";
        let escaped = false;

        for (let i = 0; i < text.length; ++i) {
            const ch = text[i];

            if (escaped) {
                current += ch;
                escaped = false;
                continue;
            }

            if (ch === "\\") {
                escaped = true;
                continue;
            }

            if (ch === separator) {
                result.push(current);
                current = "";
                continue;
            }

            current += ch;
        }

        result.push(current);
        return result;
    }

    function parseSignal(signalStr) {
        const num = parseInt(signalStr, 10);
        if (isNaN(num))
            return 0;
        return Math.max(0, Math.min(100, num)) / 100;
    }

    function parseSecurity(secStr) {
        if (!secStr || secStr === "--")
            return "Open";
        return secStr;
    }

    function parseWifiNetworks(output) {
        const lines = (output || "").trim().split("\n");
        const result = [];

        for (let i = 0; i < lines.length; ++i) {
            const line = lines[i];
            if (!line)
                continue;

            const parts = splitEscaped(line, ":");
            if (parts.length < 6)
                continue;

            result.push({
                connected: parts[0] === "yes",
                signalStrength: parseSignal(parts[1]),
                frequency: parts[2],
                ssid: parts[3] || "Hidden network",
                bssid: parts[4],
                security: parseSecurity(parts[5])
            });
        }

        return result;
    }

    function parseRadioState(output) {
        const trimmed = (output || "").trim();
        const values = trimmed.includes(":") ? trimmed.split(":") : trimmed.split("\n");
        return {
            wifiHardwareEnabled: values.length > 0 ? values[0].trim() === "enabled" : true,
            wifiEnabled: values.length > 1 ? values[1].trim() === "enabled" : false
        };
    }

    function parseDeviceStatus(output) {
        const lines = (output || "").trim().split("\n");
        const state = {
            hasWiredConnection: false,
            wifiDeviceName: "",
            wiredDeviceName: "",
            wiredAddress: ""
        };

        for (let i = 0; i < lines.length; ++i) {
            const line = lines[i];
            const parts = line.split(":");
            if (parts.length < 3)
                continue;

            const device = parts[0];
            const type = parts[1];
            const status = parts[2];
            const address = parts[3] || "";

            if (type === "wifi" && status === "connected") {
                state.wifiDeviceName = device;
            } else if (type === "ethernet" && status === "connected" && !state.hasWiredConnection) {
                state.hasWiredConnection = true;
                state.wiredDeviceName = device;
                state.wiredAddress = address;
            }
        }

        return state;
    }

    function parseInterfaceAddresses(output) {
        let values;
        try {
            values = JSON.parse(output || "[]");
        } catch (error) {
            tracer.warn("parseInterfaceAddresses.invalidJson", function() {
                return { message: String(error) };
            });
            return [];
        }

        if (!Array.isArray(values))
            return [];

        return values.filter(function(value) {
            return value && value.ifname && value.ifname !== "lo";
        }).map(function(value) {
            const addressInfo = Array.isArray(value.addr_info) ? value.addr_info : [];
            const ipv4 = [];
            const ipv6 = [];

            for (const address of addressInfo) {
                if (!address || !address.local)
                    continue;
                const rendered = address.prefixlen !== undefined
                    ? `${address.local}/${address.prefixlen}`
                    : String(address.local);
                if (address.family === "inet")
                    ipv4.push(rendered);
                else if (address.family === "inet6")
                    ipv6.push(rendered);
            }

            return {
                name: String(value.ifname),
                mac: String(value.address || ""),
                state: String(value.operstate || "unknown").toLowerCase(),
                mtu: Number(value.mtu || 0),
                flags: Array.isArray(value.flags) ? value.flags.slice() : [],
                ipv4: ipv4,
                ipv6: ipv6
            };
        });
    }
}
