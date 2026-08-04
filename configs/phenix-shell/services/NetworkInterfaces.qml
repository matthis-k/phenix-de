pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

import qs.services
import "network"

Singleton {
    id: root

    readonly property var tracer: Logger.scope("network.interfaces", { category: "network" })
    readonly property var backend: root

    readonly property InterfaceAddressParser parser: InterfaceAddressParser {}

    property var interfaces: []
    property int revision: 0
    property string lastError: ""
    readonly property bool available: interfaces.length > 0

    function interfaceByName(name) {
        const normalized = String(name || "");
        if (normalized === "")
            return null;
        for (const entry of root.interfaces) {
            if (entry && entry.name === normalized)
                return entry;
        }
        return null;
    }

    function activeInterface() {
        const name = NetworkService.hasWiredConnection
            ? NetworkService.wiredDeviceName
            : NetworkService.wifiDeviceName;
        return root.interfaceByName(name);
    }

    function formatAddresses(addresses) {
        const values = Array.isArray(addresses) ? addresses : [];
        return values.length > 0 ? values.join(", ") : qsTr("Unavailable");
    }

    function refresh() {
        if (collector.running)
            return;
        collector.exec({
            command: ["ip", "-j", "address", "show"]
        });
    }

    Process {
        id: collector

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.interfaces = root.parser.parse(text);
                root.revision += 1;
                root.lastError = "";
            }
        }

        function onExited(exitCode) {
            if (exitCode === 0)
                return;
            root.lastError = qsTr("Interface diagnostics failed (%1)").arg(exitCode);
            root.tracer.warn("refreshFailed", function() {
                return { exitCode: exitCode };
            });
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
