import QtQml
import qs.services

QtObject {
    id: root

    readonly property var tracer: Logger.scope("network.interfaceParser", { category: "network" })

    function parse(output) {
        let values;
        try {
            values = JSON.parse(output || "[]");
        } catch (error) {
            root.tracer.warn("invalidJson", function() {
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
