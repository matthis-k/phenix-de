import QtQuick
import QtQml
import Quickshell.Io
import qs.services

QtObject {
    id: root

    readonly property var tracer: Logger.scope("network.commands", { category: "network" })
    readonly property var prof: Profiler.scope("network.commands", { category: "network" })

    signal networksOutput(string text)
    signal radioOutput(string text)
    signal networkingOutput(string text)
    signal generalOutput(string text)
    signal wiredOutput(string text)
    signal operationFinished(string kind, bool success, string message)
    signal scanResult(bool success)

    property Process networkingStateProcess: Process {
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.networkingOutput(text)
        }
    }

    property Process statusProcess: Process {
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.radioOutput(text)
        }
    }

    property Process generalProcess: Process {
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.generalOutput(text)
        }
    }

    property Process rescanProcess: Process {
        function onExited(exitCode) {
            if (exitCode === 0) {
                getNetworksProcess.exec({
                    command: ["nmcli", "-g", "ACTIVE,SIGNAL,FREQ,SSID,BSSID,SECURITY", "d", "wifi"]
                });
            } else {
                root.scanResult(false);
                root.operationFinished("scan", false, `scan failed (${exitCode})`);
            }
        }
    }

    property Process getNetworksProcess: Process {
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.networksOutput(text);
                root.scanResult(true);
            }
        }
    }

    property Process wiredCheckProcess: Process {
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.wiredOutput(text)
        }
    }

    property Process nmcliNetworkingProcess: Process {
        function onExited(exitCode) {
            root._onOperationExited(exitCode, "networking", "networking toggle failed");
        }
    }

    property Process connectProcess: Process {
        function onExited(exitCode) {
            root._onOperationExited(exitCode, "connect", "connect failed");
        }
    }

    property Process disconnectProcess: Process {
        function onExited(exitCode) {
            root._onOperationExited(exitCode, "disconnect", "disconnect failed");
        }
    }

    property Process forgetProcess: Process {
        function onExited(exitCode) {
            root._onOperationExited(exitCode, "forget", "forget failed");
        }
    }

    property Process wifiToggleProcess: Process {
        function onExited(exitCode) {
            root._onOperationExited(exitCode, "wifi", "wifi toggle failed");
        }
    }

    function refreshAll() {
        root.tracer.trace("refreshAll");
        root.networkingStateProcess.exec({
            command: ["nmcli", "networking"]
        });
        root.statusProcess.exec({
            command: ["nmcli", "-g", "WIFI-HW,WIFI", "radio"]
        });
        root.generalProcess.exec({
            command: ["nmcli", "-g", "CONNECTIVITY", "general"]
        });
        root.getNetworksProcess.exec({
            command: ["nmcli", "-g", "ACTIVE,SIGNAL,FREQ,SSID,BSSID,SECURITY", "d", "wifi"]
        });
        root._checkWiredConnection();
    }

    function scan() {
        root.tracer.info("scan.executing");
        root.rescanProcess.exec({
            command: ["nmcli", "dev", "wifi", "list", "--rescan", "yes"]
        });
    }

    function setNetworkingEnabled(value) {
        const cmd = value ? "on" : "off";
        root.tracer.info("setNetworkingEnabled", function() { return { enabled: value } });
        root.nmcliNetworkingProcess.exec({
            command: ["nmcli", "networking", cmd]
        });
    }

    function setWifiEnabled(enabled) {
        const cmd = enabled ? "on" : "off";
        root.tracer.info("setWifiEnabled", function() { return { enabled: enabled } });
        root.wifiToggleProcess.exec({
            command: ["nmcli", "radio", "wifi", cmd]
        });
    }

    function connectToNetwork(ssid, password) {
        const args = ["nmcli", "dev", "wifi", "connect", ssid];
        if (password)
            args.push("password", password);
        root.tracer.info("connectToNetwork", function() { return { ssid: ssid, hasPassword: !!password } });
        root.connectProcess.exec({
            command: args
        });
    }

    function disconnectDevice(deviceName) {
        if (!deviceName) {
            root.tracer.warn("disconnectDevice.noDeviceName");
            return;
        }
        root.tracer.info("disconnectDevice", function() { return { device: deviceName } });
        root.disconnectProcess.exec({
            command: ["nmcli", "dev", "disconnect", deviceName]
        });
    }

    function forgetNetwork(uuid) {
        if (!uuid) {
            root.tracer.warn("forgetNetwork.noUuid");
            return;
        }
        root.tracer.info("forgetNetwork", function() { return { uuid: uuid } });
        root.forgetProcess.exec({
            command: ["nmcli", "con", "delete", "uuid", uuid]
        });
    }

    function _checkWiredConnection() {
        root.tracer.trace("checkWiredConnection");
        root.wiredCheckProcess.exec({
            command: ["nmcli", "-g", "DEVICE,TYPE,STATE,IP4.ADDRESS", "device", "status"]
        });
    }

    function _onOperationExited(exitCode, kind, failMsg) {
        root.tracer.debug("operationExited", function() { return { kind: kind, exitCode: exitCode } });
        root.operationFinished(kind, exitCode === 0, exitCode === 0 ? "" : `${failMsg} (${exitCode})`);
    }
}
