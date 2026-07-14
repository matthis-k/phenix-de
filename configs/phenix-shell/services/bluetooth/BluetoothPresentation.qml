import QtQml
import Quickshell.Bluetooth
import qs.services

QtObject {
    id: root

    readonly property var tracer: Logger.scope("bluetooth.presentation", { category: "bluetooth" })
    readonly property var prof: Profiler.scope("bluetooth.presentation", { category: "bluetooth" })

    function displayName(device) {
        return device?.name || device?.deviceName || device?.address || "Bluetooth device";
    }

    function hasFriendlyName(device) {
        const name = device?.deviceName || "";
        return !!name.trim();
    }

    function batteryLabel(device) {
        return device?.batteryAvailable ? `${Math.round((device.battery || 0) * 100)}%` : "No battery";
    }

    function deviceTypeLabel(device) {
        const icon = (device?.icon || "").replace(/-symbolic$/, "");
        if (icon.includes("headphones")) return "Headphones";
        if (icon.includes("headset")) return "Headset";
        if (icon.includes("speaker")) return "Speaker";
        if (icon.includes("audio")) return "Audio device";
        if (icon.includes("mouse")) return "Mouse";
        if (icon.includes("keyboard")) return "Keyboard";
        if (icon.includes("gamepad") || icon.includes("joystick")) return "Controller";
        if (icon.includes("phone")) return "Phone";
        if (icon.includes("computer") || icon.includes("laptop")) return "Computer";
        if (icon.includes("tablet")) return "Tablet";
        if (icon.includes("watch")) return "Watch";
        return "Bluetooth device";
    }

    function adapterStatusLabel(adapter) {
        if (!adapter)
            return "No adapter";
        return BluetoothAdapterState.toString(adapter.state).replace(/([a-z])([A-Z])/g, "$1 $2");
    }

    function adapterIconName(adapter, connectedCount) {
        if (!adapter)
            return "bluetooth-disabled-symbolic";
        if (adapter.state === BluetoothAdapterState.Blocked)
            return "bluetooth-disabled-symbolic";
        if (!adapter.enabled || adapter.state === BluetoothAdapterState.Disabled)
            return "bluetooth-disabled-symbolic";
        if (connectedCount > 0)
            return "bluetooth-connected-symbolic";
        if (adapter.discovering)
            return "bluetooth-searching-symbolic";
        return "bluetooth-symbolic";
    }

    function deviceStatusLabel(device) {
        if (!device)
            return "Unavailable";
        return BluetoothDeviceState.toString(device.state);
    }

    function advancedDeviceInfo(device) {
        if (!device)
            return "Device unavailable";

        return [
            `Type: ${root.deviceTypeLabel(device)}`,
            `Address: ${device.address || "unknown"}`,
            `Adapter: ${device.adapter ? `${device.adapter.name} (${device.adapter.adapterId})` : "unknown"}`,
            `State: ${root.deviceStatusLabel(device)}`,
            `Battery: ${root.batteryLabel(device)}`,
            `Paired: ${device.paired ? "Yes" : "No"}`,
            `Bonded: ${device.bonded ? "Yes" : "No"}`,
            `Trusted: ${device.trusted ? "Yes" : "No"}`,
            `Wake allowed: ${device.wakeAllowed ? "Yes" : "No"}`,
            `Blocked: ${device.blocked ? "Yes" : "No"}`
        ].join("\n");
    }
}
