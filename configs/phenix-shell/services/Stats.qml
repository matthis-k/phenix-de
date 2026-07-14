pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.components
import qs.services

Singleton {
    id: root

    readonly property var backend: root

    Component.onDestruction: {
        cpuTimer.running = false;
        memoryTimer.running = false;
        diskTimer.running = false;
        networkTimer.running = false;
        gpuTimer.running = false;
    }

    property UPowerDevice battery: UPower.displayDevice
    readonly property bool hasBattery: battery?.isLaptopBattery === true
    property real cpuPercent: 0
    property real memoryPercent: 0
    property real swapPercent: 0
    property real rootDiskPercent: 0
    property real rxBytesPerSecond: 0
    property real txBytesPerSecond: 0
    property int memoryUsedMiB: 0
    property int memoryTotalMiB: 0
    property int swapUsedMiB: 0
    property int swapTotalMiB: 0
    property string primaryInterface: ""
    property var diskPartitions: []
    property int graphRevision: 0
    property var cpuCorePercents: []
    property real gpuVramUsedMiB: 0
    property real gpuVramTotalMiB: 0
    property real gpuVramPercent: 0
    property real gpuUtilPercent: 0
    property string gpuName: ""
    property bool gpuAvailable: false

    readonly property string state: {
        if (cpuPercent >= 90 || memoryPercent >= 90) return "critical";
        if (cpuPercent >= 70 || memoryPercent >= 75) return "warning";
        return "normal";
    }

    readonly property string iconName: "utilities-system-monitor-symbolic"
    readonly property color iconColor: {
        if (cpuPercent >= 90 || memoryPercent >= 90) return Config.styling.critical;
        if (cpuPercent >= 70 || memoryPercent >= 75) return Config.styling.warning;
        return Config.styling.text0;
    }

    readonly property string label: "System Stats"
    readonly property string statusText: `CPU ${Math.round(cpuPercent)}% · RAM ${Math.round(memoryPercent)}%`

    readonly property var presentation: {
        return {
            icon: root.iconName,
            color: root.iconColor,
            label: root.label,
            status: root.statusText,
            state: root.state,
            cpuPercent: root.cpuPercent,
            memoryPercent: root.memoryPercent
        };
    }

    readonly property var summary: {
        return {
            cpuPercent: root.cpuPercent,
            memoryPercent: root.memoryPercent,
            swapPercent: root.swapPercent,
            rootDiskPercent: root.rootDiskPercent,
            gpuAvailable: root.gpuAvailable,
            gpuUtilPercent: root.gpuUtilPercent,
            gpuVramPercent: root.gpuVramPercent,
            rxBytesPerSecond: root.rxBytesPerSecond,
            txBytesPerSecond: root.txBytesPerSecond
        };
    }

    // Everything below is preserved from the original implementation

    property string _statsCacheDir: _localPath(StandardPaths.writableLocation(StandardPaths.CacheLocation)) + "/newshell/stats"

    function _localPath(location) {
        return String(location).replace(/^file:(\/\/)?/, "");
    }

    Process {
        id: _persistProcess
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
    }

    Process {
        id: _loadCpuProcess
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    const data = _flatSeriesData(JSON.parse(text));
                    if (Array.isArray(data) && data.length > 0)
                        cpuGraphCollector.replaceRawData(data);
                } catch (e) {}
            }
        }
    }

    Process {
        id: _loadMemoryProcess
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    const data = _flatSeriesData(JSON.parse(text));
                    if (Array.isArray(data) && data.length > 0)
                        memoryGraphCollector.replaceRawData(data);
                } catch (e) {}
            }
        }
    }

    Process {
        id: _loadBatteryProcess
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    const data = _flatSeriesData(JSON.parse(text));
                    if (Array.isArray(data) && data.length > 0)
                        batteryGraphCollector.replaceRawData(data);
                } catch (e) {}
            }
        }
    }

    Process {
        id: _loadGpuProcess
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    const data = _flatSeriesData(JSON.parse(text));
                    if (Array.isArray(data) && data.length > 0)
                        gpuGraphCollector.replaceRawData(data);
                } catch (e) {}
            }
        }
    }

    Component.onCompleted: {
        _loadCpuProcess.exec({
            command: ["sh", "-c", "mkdir -p \"$1\" && cat \"$1/$2\" 2>/dev/null || echo \"[]\"", "sh", _statsCacheDir, "cpu.json"]
        });
        _loadMemoryProcess.exec({
            command: ["sh", "-c", "mkdir -p \"$1\" && cat \"$1/$2\" 2>/dev/null || echo \"[]\"", "sh", _statsCacheDir, "memory.json"]
        });
        _loadBatteryProcess.exec({
            command: ["sh", "-c", "mkdir -p \"$1\" && cat \"$1/$2\" 2>/dev/null || echo \"[]\"", "sh", _statsCacheDir, "battery.json"]
        });
        _loadGpuProcess.exec({
            command: ["sh", "-c", "mkdir -p \"$1\" && cat \"$1/$2\" 2>/dev/null || echo \"[]\"", "sh", _statsCacheDir, "gpu.json"]
        });
    }

    function _writeJson(filename, data) {
        const json = JSON.stringify(_flatSeriesData(data));
        _persistProcess.exec({
            command: ["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$1/$3\"", "sh", _statsCacheDir, json, filename]
        });
    }

    function _flatSeriesData(data) {
        const result = [];
        if (!Array.isArray(data))
            return result;

        for (let i = 0; i < data.length; i++) {
            let point = data[i];
            while (point && point.raw && point.raw.x !== undefined && point.raw.y !== undefined)
                point = point.raw;
            if (!point || point.x === undefined || point.y === undefined)
                continue;

            result.push({
                x: point.x,
                y: point.y,
                series: point.series || point.name || ""
            });
        }
        return result;
    }

    property TimedDataCollector cpuGraphCollector: TimedDataCollector {
        running: true
        xWindow: 120000
        sampleInterval: 2000
        persistFilename: "cpu.json"
        persistEvery: 10

        collect: function () {
            if (!root._hasCpuDelta)
                return null;

            const x = Date.now();
            const points = [
                {
                    x: x,
                    y: root.cpuPercent,
                    series: "avg"
                }
            ];
            for (let i = 0; i < root.cpuCorePercents.length; i++) {
                points.push({
                    x: x,
                    y: root.cpuCorePercents[i],
                    series: `core${i}`
                });
            }
            return points;
        }

        onCollected: {
            root.graphRevision++;
        }

        onPersistReady: function (filename, data) {
            root._writeJson(filename, data);
        }
    }

    property TimedDataCollector memoryGraphCollector: TimedDataCollector {
        running: true
        xWindow: 300000
        sampleInterval: 10000
        persistFilename: "memory.json"
        persistEvery: 10

        collect: function () {
            const x = Date.now();
            return [
                {
                    x: x,
                    y: root.memoryPercent,
                    series: "RAM"
                },
                {
                    x: x,
                    y: root.swapTotalMiB > 0 ? root.swapPercent : 0,
                    series: "Swap"
                }
            ];
        }

        onCollected: {
            root.graphRevision++;
        }

        onPersistReady: function (filename, data) {
            root._writeJson(filename, data);
        }
    }

    property TimedDataCollector batteryGraphCollector: TimedDataCollector {
        running: true
        xWindow: 18000000
        sampleInterval: 300000
        persistFilename: "battery.json"
        persistEvery: 10

        collect: function () {
            if (!root.battery || root.battery.isLaptopBattery !== true)
                return null;

            return [{
                x: Date.now(),
                y: Math.round((root.battery.percentage || 0) * 100),
                series: "Battery"
            }];
        }

        onCollected: {
            root.graphRevision++;
        }

        onPersistReady: function (filename, data) {
            root._writeJson(filename, data);
        }
    }

    property TimedDataCollector gpuGraphCollector: TimedDataCollector {
        running: true
        xWindow: 120000
        sampleInterval: 2000
        persistFilename: "gpu.json"
        persistEvery: 10

        collect: function () {
            if (!root.gpuAvailable)
                return null;

            const x = Date.now();
            return [
                {
                    x: x,
                    y: root.gpuVramPercent,
                    series: "VRAM"
                },
                {
                    x: x,
                    y: root.gpuUtilPercent,
                    series: "GPU"
                }
            ];
        }

        onCollected: {
            root.graphRevision++;
        }

        onPersistReady: function (filename, data) {
            root._writeJson(filename, data);
        }
    }

    property real _lastCpuTotal: 0
    property real _lastCpuIdle: 0
    property bool _hasCpuDelta: false
    property real _lastRxBytes: 0
    property real _lastTxBytes: 0
    property double _lastSampleMs: 0
    property var _lastCpuCoreTotals: []
    property var _lastCpuCoreIdles: []

    function calculateCpuGraphSeries() {
        const _ = graphRevision;
        const series = [
            {
                name: "avg",
                collector: cpuGraphCollector,
                visible: true,
                z: cpuCorePercents.length
            }
        ];
        for (let i = 0; i < cpuCorePercents.length; i++)
            series.push({
                name: `core${i}`,
                collector: cpuGraphCollector,
                visible: false,
                z: i
            });
        return series;
    }

    function calculateMemoryGraphSeries() {
        const _ = graphRevision;
        return [
            {
                name: "RAM",
                collector: memoryGraphCollector,
                visible: true
            },
            {
                name: "Swap",
                collector: memoryGraphCollector,
                visible: true
            }
        ];
    }

    function calculateBatteryGraphSeries() {
        const _ = graphRevision;
        return [
            {
                name: "Battery",
                collector: batteryGraphCollector,
                visible: true
            }
        ];
    }

    function calculateGpuGraphSeries() {
        const _ = graphRevision;
        return [
            {
                name: "VRAM",
                collector: gpuGraphCollector,
                visible: true
            },
            {
                name: "GPU",
                collector: gpuGraphCollector,
                visible: true
            }
        ];
    }

    function formatRate(bytesPerSecond) {
        const absValue = Math.abs(bytesPerSecond || 0);
        if (absValue >= 1024 * 1024)
            return `${(bytesPerSecond / (1024 * 1024)).toFixed(1)} MiB/s`;
        if (absValue >= 1024)
            return `${(bytesPerSecond / 1024).toFixed(1)} KiB/s`;
        return `${Math.round(bytesPerSecond || 0)} B/s`;
    }

    property Process cpuCollectorProcess: Process {
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.applyCpuSample(text)
        }
    }

    property Process memoryCollectorProcess: Process {
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.applyMemorySample(text)
        }
    }

    property Process diskCollectorProcess: Process {
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.applyDiskSample(text)
        }
    }

    property Process networkCollectorProcess: Process {
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.applyNetworkSample(text)
        }
    }

    property Process gpuCollectorProcess: Process {
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.applyGpuSample(text)
        }
    }

    property Timer cpuTimer: Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshCpu()
    }

    property Timer memoryTimer: Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshMemory()
    }

    property Timer diskTimer: Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshDisk()
    }

    property Timer networkTimer: Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshNetwork()
    }

    property Timer gpuTimer: Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshGpu()
    }

    function applyCpuSample(text) {
        const sampleTime = Date.now();
        const lines = (text || "").trim().split(/\n+/);

        for (const line of lines) {
            const parts = line.trim().split(/\s+/);
            if (parts.length < 3)
                continue;

            const key = parts[0];
            if (key === "cpu" && parts.length >= 3) {
                const cpuTotal = parseFloat(parts[1]);
                const cpuIdle = parseFloat(parts[2]);
                if (!isNaN(cpuTotal) && !isNaN(cpuIdle)) {
                    const totalDelta = cpuTotal - _lastCpuTotal;
                    const idleDelta = cpuIdle - _lastCpuIdle;
                    if (_lastCpuTotal > 0 && totalDelta > 0) {
                        cpuPercent = Math.max(0, Math.min(100, ((totalDelta - idleDelta) / totalDelta) * 100));
                        _hasCpuDelta = true;
                    }
                    _lastCpuTotal = cpuTotal;
                    _lastCpuIdle = cpuIdle;
                }
            } else if (key.startsWith("cpu") && key !== "cpu" && !isNaN(key.charAt(3))) {
                const coreIndex = parseInt(key.substring(3));
                if (parts.length >= 3) {
                    const coreTotal = parseFloat(parts[1]);
                    const coreIdle = parseFloat(parts[2]);

                    while (_lastCpuCoreTotals.length <= coreIndex) {
                        _lastCpuCoreTotals.push(0);
                        _lastCpuCoreIdles.push(0);
                    }

                    if (_lastCpuCoreTotals[coreIndex] > 0) {
                        const totalDelta = coreTotal - _lastCpuCoreTotals[coreIndex];
                        const idleDelta = coreIdle - _lastCpuCoreIdles[coreIndex];
                        const corePercent = totalDelta > 0 ? Math.max(0, Math.min(100, ((totalDelta - idleDelta) / totalDelta) * 100)) : 0;
                        while (cpuCorePercents.length <= coreIndex)
                            cpuCorePercents.push(0);
                        cpuCorePercents[coreIndex] = corePercent;
                    }

                    _lastCpuCoreTotals[coreIndex] = coreTotal;
                    _lastCpuCoreIdles[coreIndex] = coreIdle;
                }
            }
        }
    }

    function applyMemorySample(text) {
        const lines = (text || "").trim().split(/\n+/);
        for (const line of lines) {
            const parts = line.trim().split(/\s+/);
            if (parts.length >= 2) {
                if (parts[0] === "mem") {
                    const usedKiB = parseFloat(parts[1]);
                    const totalKiB = parseFloat(parts[2]);
                    if (!isNaN(usedKiB) && !isNaN(totalKiB) && totalKiB > 0) {
                        memoryUsedMiB = Math.round(usedKiB / 1024);
                        memoryTotalMiB = Math.round(totalKiB / 1024);
                        memoryPercent = (usedKiB / totalKiB) * 100;
                    }
                } else if (parts[0] === "swap") {
                    const usedKiB = parseFloat(parts[1]);
                    const totalKiB = parseFloat(parts[2]);
                    if (!isNaN(usedKiB) && !isNaN(totalKiB)) {
                        swapUsedMiB = Math.round(usedKiB / 1024);
                        swapTotalMiB = Math.round(totalKiB / 1024);
                        swapPercent = totalKiB > 0 ? (usedKiB / totalKiB) * 100 : 0;
                    }
                }
            }
        }
    }

    function applyDiskSample(text) {
        const lines = (text || "").trim().split(/\n+/);
        const newPartitions = [];
        for (const line of lines) {
            const parts = line.trim().split(/\s+/);
            if (parts.length >= 3) {
                const mountPoint = parts[0];
                const usedKiB = parseFloat(parts[1]);
                const totalKiB = parseFloat(parts[2]);
                if (!isNaN(usedKiB) && !isNaN(totalKiB) && totalKiB > 0) {
                    const percent = (usedKiB / totalKiB) * 100;
                    newPartitions.push({
                        mount: mountPoint,
                        usedGiB: Math.round(usedKiB / (1024 * 1024)),
                        totalGiB: Math.round(totalKiB / (1024 * 1024)),
                        percent: Math.round(percent)
                    });
                    if (mountPoint === "/")
                        rootDiskPercent = (usedKiB / totalKiB) * 100;
                }
            }
        }
        diskPartitions = newPartitions;
    }

    function applyNetworkSample(text) {
        const sampleTime = Date.now();
        const lines = (text || "").trim().split(/\n+/);
        for (const line of lines) {
            const parts = line.trim().split(/\s+/);
            if (parts.length >= 3) {
                const iface = parts[0];
                const rxBytes = parseFloat(parts[1]);
                const txBytes = parseFloat(parts[2]);
                const elapsedSeconds = _lastSampleMs > 0 ? Math.max((sampleTime - _lastSampleMs) / 1000, 0.001) : 0;

                primaryInterface = iface === "none" ? "" : iface;

                if (!isNaN(rxBytes) && !isNaN(txBytes)) {
                    if (_lastSampleMs > 0) {
                        rxBytesPerSecond = Math.max(0, (rxBytes - _lastRxBytes) / elapsedSeconds);
                        txBytesPerSecond = Math.max(0, (txBytes - _lastTxBytes) / elapsedSeconds);
                    }
                    _lastRxBytes = rxBytes;
                    _lastTxBytes = txBytes;
                    _lastSampleMs = sampleTime;
                }
            }
        }
    }

    function applyGpuSample(text) {
        const parts = (text || "").trim().split(",");
        if (parts.length >= 4) {
            const name = parts[0].trim();
            const vramUsed = parseFloat(parts[1]);
            const vramTotal = parseFloat(parts[2]);
            const util = parseFloat(parts[3]);

            if (!isNaN(vramUsed) && !isNaN(vramTotal) && vramTotal > 0) {
                gpuName = name;
                gpuVramUsedMiB = Math.round(vramUsed);
                gpuVramTotalMiB = Math.round(vramTotal);
                gpuVramPercent = (vramUsed / vramTotal) * 100;
                gpuUtilPercent = isNaN(util) ? 0 : util;
                gpuAvailable = true;
            }
        }
    }

    function refreshCpu() {
        cpuCollectorProcess.exec({
            command: ["sh", "-c", "read _ u n s i w irq sirq st g gn < /proc/stat; total=$((u+n+s+i+w+irq+sirq+st)); idle=$((i+w)); echo \"cpu $total $idle\"; idx=0; while read -r line; do case \"$line\" in cpu[0-9]*) set -- $line; u2=$2; n2=$3; s2=$4; i2=$5; w2=$6; irq2=$7; sirq2=$8; st2=$9; t2=$((u2+n2+s2+i2+w2+irq2+sirq2+st2)); id2=$((i2+w2)); echo \"cpu${idx} $t2 $id2\"; idx=$((idx+1));; esac; done < /proc/stat"]
        });
    }

    function refreshMemory() {
        memoryCollectorProcess.exec({
            command: ["sh", "-c", "mem_total=$(awk '/MemTotal/ {print $2}' /proc/meminfo); mem_available=$(awk '/MemAvailable/ {print $2}' /proc/meminfo); swap_total=$(awk '/SwapTotal/ {print $2}' /proc/meminfo); swap_free=$(awk '/SwapFree/ {print $2}' /proc/meminfo); printf 'mem %s %s\\nswap %s %s\\n' \"$((mem_total-mem_available))\" \"$mem_total\" \"$((swap_total-swap_free))\" \"$swap_total\""]
        });
    }

    function refreshDisk() {
        diskCollectorProcess.exec({
            command: ["sh", "-c", "df -Pk | awk 'NR>1 && $1 ~ /^\\/dev/ {printf \"%s %s %s\\n\", $6, $3, $2}'"]
        });
    }

    function refreshNetwork() {
        networkCollectorProcess.exec({
            command: ["sh", "-c", "iface=$(awk -F: '$1 !~ /lo/ {gsub(/ /, \"\", $1); print $1; exit}' /proc/net/dev); if [ -n \"$iface\" ]; then set -- $(awk -F'[: ]+' -v iface=\"$iface\" '$1 == iface {print $3, $11}' /proc/net/dev); rx=$1; tx=$2; else iface=none; rx=0; tx=0; fi; echo \"$iface $rx $tx\""]
        });
    }

    function refreshGpu() {
        gpuCollectorProcess.exec({
            command: ["sh", "-c", "nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1"]
        });
    }
}
