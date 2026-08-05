import QtQml
import qs.services

QtObject {
    id: root

    readonly property var tracer: Logger.scope("bluetooth.models", { category: "bluetooth" })
    readonly property var prof: Profiler.scope("bluetooth.models", { category: "bluetooth" })

    function deviceKey(device) {
        if (!device)
            return "";
        const address = String(device.address || "").trim();
        if (address !== "")
            return address;
        return String(device.dbusPath || "").trim();
    }

    function collectDevices(adapter, presentation) {
        const items = [];
        if (!adapter) {
            root.tracer.debug("collectDevices.noAdapter");
            return items;
        }

        const seen = {};
        for (const device of adapter.devices.values || []) {
            const key = root.deviceKey(device);
            if (key === "" || seen[key])
                continue;
            seen[key] = true;
            items.push(device);
        }

        items.sort(function(a, b) {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            if (a.paired !== b.paired)
                return a.paired ? -1 : 1;
            if (a.trusted !== b.trusted)
                return a.trusted ? -1 : 1;

            const aFriendly = presentation ? presentation.hasFriendlyName(a) : !!(a?.deviceName || "").trim();
            const bFriendly = presentation ? presentation.hasFriendlyName(b) : !!(b?.deviceName || "").trim();
            if (aFriendly !== bFriendly)
                return aFriendly ? -1 : 1;

            const aName = presentation ? presentation.displayName(a) : root.displayFallback(a);
            const bName = presentation ? presentation.displayName(b) : root.displayFallback(b);
            return aName.localeCompare(bName);
        });

        root.tracer.trace("devicesCollected", function() { return { count: items.length, connected: items.filter(d => d.connected).length } });
        return items;
    }

    function connectedDevices(devices) {
        const result = (devices || []).filter(device => !!device && device.connected);
        root.tracer.trace("connectedDevices", function() { return { count: result.length } });
        return result;
    }

    function otherDevices(devices) {
        const result = (devices || []).filter(device => !!device && !device.connected);
        root.tracer.trace("otherDevices", function() { return { count: result.length } });
        return result;
    }

    function displayFallback(device) {
        return device?.name || device?.deviceName || device?.address || "Bluetooth device";
    }
}
