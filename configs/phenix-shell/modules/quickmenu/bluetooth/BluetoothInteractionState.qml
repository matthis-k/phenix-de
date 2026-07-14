import QtQml
import qs.services

QtObject {
    id: root

    readonly property var tracer: Logger.scope("quickmenu.bluetoothInteractionState", { category: "quickmenu" })
    readonly property var prof: Profiler.scope("quickmenu.bluetoothInteractionState", { category: "quickmenu" })

    property string interactiveDeviceKey: ""
    property bool interactiveShowAdvanced: false
    property var frozenDeviceOrder: []
    property var devices: []

    readonly property bool interactionLocked: interactiveDeviceKey !== ""

    function deviceKey(device) {
        return BluetoothService.deviceKey(device);
    }

    function applyFrozenOrder(devices) {
        const order = new Map();
        for (let i = 0; i < root.frozenDeviceOrder.length; ++i)
            order.set(root.frozenDeviceOrder[i], i);

        const items = (devices || []).slice();
        items.sort(function(a, b) {
            const aIndex = order.has(root.deviceKey(a)) ? order.get(root.deviceKey(a)) : Number.MAX_SAFE_INTEGER;
            const bIndex = order.has(root.deviceKey(b)) ? order.get(root.deviceKey(b)) : Number.MAX_SAFE_INTEGER;
            if (aIndex !== bIndex)
                return aIndex - bIndex;
            return 0;
        });

        return items;
    }

    function lockInteractionFor(device) {
        tracer.debug("lockInteractionFor", function() { return { deviceKey: root.deviceKey(device), wasLocked: root.interactionLocked }; });
        const key = root.deviceKey(device);
        if (!key)
            return;

        if (!root.interactionLocked)
            root.frozenDeviceOrder = root.devices.map(candidate => root.deviceKey(candidate));

        if (root.interactiveDeviceKey !== key)
            root.interactiveShowAdvanced = false;

        root.interactiveDeviceKey = key;
    }

    function unlockInteraction() {
        tracer.info("unlockInteraction", function() { return {}; });
        root.interactiveDeviceKey = "";
        root.interactiveShowAdvanced = false;
        root.frozenDeviceOrder = [];
    }

    function displayedDevices(devices) {
        return root.interactionLocked ? root.applyFrozenOrder(devices) : devices;
    }
}
