import QtQml
import qs.services

QtObject {
    id: root

    readonly property var tracer: Logger.scope("bluetooth.deviceResolver", { category: "bluetooth" })
    readonly property var prof: Profiler.scope("bluetooth.deviceResolver", { category: "bluetooth" })

    function rawDeviceById(adapter, id) {
        if (!adapter) {
            root.tracer.debug("rawDeviceById.noAdapter");
            return null;
        }
        root.tracer.trace("rawDeviceById", function() { return { id: id } });
        for (const device of (adapter.devices.values || [])) {
            if (device.address === id || device.dbusPath === id || device.name === id)
                return device;
        }
        return null;
    }
}
