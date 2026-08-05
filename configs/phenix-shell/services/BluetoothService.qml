pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.services
import "bluetooth"

Singleton {
    id: root

    readonly property var tracer: Logger.scope("bluetooth.service", { category: "bluetooth" })
    readonly property var prof: Profiler.scope("bluetooth.service", { category: "bluetooth" })

    readonly property var backend: Bluetooth
    readonly property var adapter: Bluetooth.defaultAdapter

    readonly property BluetoothDeviceResolver deviceResolver: BluetoothDeviceResolver {}
    readonly property BluetoothModels bluetoothModels: BluetoothModels {}
    readonly property BluetoothPresentation bluetoothPresentation: BluetoothPresentation {}
    readonly property BluetoothOperationState operationState: BluetoothOperationState {}

    readonly property bool available: !!adapter
    readonly property bool enabled: adapter ? adapter.enabled : false
    readonly property bool blocked: adapter ? adapter.state === BluetoothAdapterState.Blocked : false
    readonly property bool scanning: adapter ? adapter.discovering : false

    readonly property var operation: root.operationState.operation
    readonly property bool busy: root.operationState.busy || scanning
    readonly property bool connected: connectedCount > 0
    readonly property int connectedCount: root.connectedDevices.length

    readonly property string state: {
        if (!adapter) return "unavailable";
        if (adapter.state === BluetoothAdapterState.Blocked) return "blocked";
        if (!adapter.enabled || adapter.state === BluetoothAdapterState.Disabled) return "disabled";
        if (connectedCount > 0) return "connected";
        return "enabled";
    }

    readonly property var devices: {
        const _ = root._revision;
        return root.bluetoothModels.collectDevices(root.adapter, root.bluetoothPresentation);
    }
    readonly property var connectedDevices: root.bluetoothModels.connectedDevices(root.devices)
    readonly property var otherDevices: root.bluetoothModels.otherDevices(root.devices)
    readonly property var availableDevices: devices

    property int _revision: 0

    readonly property string iconName: {
        if (!adapter) return "bluetooth-disabled";
        if (adapter.state === BluetoothAdapterState.Blocked) return "bluetooth-disabled";
        if (!adapter.enabled || adapter.state === BluetoothAdapterState.Disabled) return "bluetooth-disabled";
        if (connectedCount > 0) return "bluetooth-active";
        if (adapter.discovering) return "bluetooth-active";
        return "bluetooth-paired";
    }

    readonly property color iconColor: enabled ? Config.styling.bluetooth : Config.styling.critical
    readonly property string label: "Bluetooth"
    readonly property string statusText: {
        if (!adapter) return "No adapter";
        if (!enabled) return "Disabled";
        if (connectedCount > 0) return `${connectedCount} connected`;
        if (scanning) return "Scanning";
        return "Ready";
    }

    readonly property var presentation: {
        return {
            icon: root.iconName,
            color: root.iconColor,
            label: root.label,
            status: root.statusText,
            state: root.state,
            available: root.available,
            enabled: root.enabled,
            connected: root.connected,
            connectedCount: root.connectedCount
        };
    }

    function rawDeviceById(id) {
        return root.deviceResolver.rawDeviceById(adapter, id);
    }

    function resolveDevice(deviceOrId) {
        if (!deviceOrId)
            return null;
        if (typeof deviceOrId === "object")
            return deviceOrId;
        return root.rawDeviceById(deviceOrId);
    }

    function deviceKey(device) { return root.bluetoothModels.deviceKey(device); }
    function displayName(device) { return root.bluetoothPresentation.displayName(device); }
    function batteryLabel(device) { return root.bluetoothPresentation.batteryLabel(device); }
    function deviceTypeLabel(device) { return root.bluetoothPresentation.deviceTypeLabel(device); }
    function adapterStatusLabel() { return root.bluetoothPresentation.adapterStatusLabel(root.adapter); }
    function adapterIconName() { return root.bluetoothPresentation.adapterIconName(root.adapter, root.connectedCount); }
    function deviceStatusLabel(device) { return root.bluetoothPresentation.deviceStatusLabel(device); }
    function advancedDeviceInfo(device) { return root.bluetoothPresentation.advancedDeviceInfo(device); }

    function setAdapterEnabled(enabled) {
        root.setEnabled(enabled);
    }

    function setEnabled(value) {
        if (adapter) {
            root.operationState.beginOperation("toggle", "adapter");
            adapter.enabled = value;
            root.operationState.finishOperation(true, "");
            root.tracer.info("adapterEnabled", function() { return { enabled: value } });
        }
    }

    function toggle() {
        if (adapter) {
            root.operationState.beginOperation("toggle", "adapter");
            adapter.enabled = !adapter.enabled;
            root.operationState.finishOperation(true, "");
            root.tracer.info("adapterToggled", function() { return { enabled: adapter.enabled } });
        }
    }

    function scan(value) {
        if (adapter) {
            root.operationState.beginOperation("scan", value ? "on" : "off");
            adapter.discovering = value;
            if (value)
                scanTimeout.restart();
            else {
                scanTimeout.stop();
                root.operationState.finishOperation(true, "");
            }
            root.tracer.info("scanToggled", function() { return { scanning: value } });
        }
    }

    function connectDevice(deviceOrId) {
        const device = root.resolveDevice(deviceOrId);
        const key = root.deviceKey(device) || String(deviceOrId || "");
        root.operationState.beginOperation("connect", key);
        if (device) {
            device.connect();
            root.operationState.finishOperation(true, "");
            root.tracer.info("deviceConnected", function() { return { key: key, name: root.displayName(device) } });
        } else {
            root.tracer.error("connectDevice.notFound", function() { return { key: key } });
            root.operationState.finishOperation(false, "Bluetooth device not found");
        }
    }

    function disconnectDevice(deviceOrId) {
        const device = root.resolveDevice(deviceOrId);
        const key = root.deviceKey(device) || String(deviceOrId || "");
        root.operationState.beginOperation("disconnect", key);
        if (device) {
            device.disconnect();
            root.operationState.finishOperation(true, "");
            root.tracer.info("deviceDisconnected", function() { return { key: key, name: root.displayName(device) } });
        } else {
            root.tracer.error("disconnectDevice.notFound", function() { return { key: key } });
            root.operationState.finishOperation(false, "Bluetooth device not found");
        }
    }

    function pairDevice(deviceOrId) {
        const device = root.resolveDevice(deviceOrId);
        const key = root.deviceKey(device) || String(deviceOrId || "");
        root.operationState.beginOperation("pair", key);
        if (!device) {
            root.tracer.error("pairDevice.notFound", function() { return { key: key } });
            root.operationState.finishOperation(false, "Bluetooth device not found");
            return;
        }
        if (device.pairing)
            device.cancelPair();
        else
            device.pair();
        root.operationState.finishOperation(true, "");
        root.tracer.info("devicePaired", function() { return { key: key, pairing: device.pairing } });
    }

    function pairOrCancelDevice(device) {
        root.pairDevice(device);
    }

    function forgetDevice(deviceOrId) {
        const device = root.resolveDevice(deviceOrId);
        const key = root.deviceKey(device) || String(deviceOrId || "");
        root.operationState.beginOperation("forget", key);
        if (device) {
            device.forget();
            root.operationState.finishOperation(true, "");
            root.tracer.info("deviceForgotten", function() { return { key: key, name: root.displayName(device) } });
        } else {
            root.tracer.error("forgetDevice.notFound", function() { return { key: key } });
            root.operationState.finishOperation(false, "Bluetooth device not found");
        }
    }

    function setTrusted(deviceOrId, value) {
        const device = root.resolveDevice(deviceOrId);
        const key = root.deviceKey(device) || String(deviceOrId || "");
        root.operationState.beginOperation("trust", key);
        if (device) {
            device.trusted = value;
            root.operationState.finishOperation(true, "");
            root.tracer.info("deviceTrustSet", function() { return { key: key, trusted: value } });
        } else {
            root.tracer.error("setTrusted.notFound", function() { return { key: key } });
            root.operationState.finishOperation(false, "Bluetooth device not found");
        }
    }

    function toggleTrusted(device) {
        if (!device)
            return;
        root.setTrusted(device, !device.trusted);
    }

    function executePayload(payload) {
        if (!payload) {
            root.tracer.warn("executePayload.nullPayload");
            return false;
        }
        root.tracer.debug("executePayload", function() { return { op: payload.op, id: payload.id } });
        switch (payload.op) {
        case "setEnabled": root.setEnabled(!!payload.enabled); return true;
        case "toggle": root.toggle(); return true;
        case "scan": root.scan(!!payload.enabled); return true;
        case "connect": root.connectDevice(payload.id); return true;
        case "disconnect": root.disconnectDevice(payload.id); return true;
        case "pair": root.pairDevice(payload.id); return true;
        case "forget": root.forgetDevice(payload.id); return true;
        case "trust": root.setTrusted(payload.id, !!payload.trusted); return true;
        default: root.tracer.warn("executePayload.unknownOp", function() { return { op: payload.op } }); return false;
        }
    }

    Timer {
        id: scanTimeout
        interval: 15000
        repeat: false
        onTriggered: {
            if (root.adapter && root.adapter.discovering)
                root.adapter.discovering = false;
            if (root.operationState.currentOperationKind === "scan")
                root.operationState.finishOperation(true, "");
        }
    }

    Connections {
        target: Bluetooth
        function onDefaultAdapterChanged() { root._revision++; }
    }

    Connections {
        target: root.adapter

        function onEnabledChanged() { root._revision++; }
        function onStateChanged() { root._revision++; }
        function onDiscoveringChanged() {
            root._revision++;
            if (!root.adapter.discovering) {
                scanTimeout.stop();
                if (root.operationState.currentOperationKind === "scan")
                    root.operationState.finishOperation(true, "");
            }
        }
    }

    Connections {
        target: root.adapter ? root.adapter.devices : null

        function onObjectInsertedPost() { root._revision++; }
        function onObjectRemovedPost() { root._revision++; }
    }

    onAdapterChanged: root._revision++
}
