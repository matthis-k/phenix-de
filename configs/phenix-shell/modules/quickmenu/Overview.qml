import QtQuick
import QtQuick.Layouts
import Quickshell.Io

import qs.services
import qs.components

DashboardPage {
    id: root

    title: qsTr("Quick Settings")
    subtitle: root.detailed
        ? qsTr("Complete device state and system telemetry")
        : qsTr("Primary controls with current values and exceptional states promoted")

    property var screenState: null

    CpuDashboardObservation {
        id: cpuObservation
        presentationMode: root.presentationMode
        average: Stats.cpuPercent
        cores: Stats.cpuCorePercents
        revision: Stats.graphRevision
    }

    UsageDashboardObservation {
        id: memoryObservation
        key: "overview-memory"
        presentationMode: root.presentationMode
        primaryLabel: qsTr("RAM")
        secondaryLabel: qsTr("Swap")
        primaryPercent: Stats.memoryPercent
        secondaryPercent: Stats.swapPercent
        secondaryEnabled: Stats.swapTotalMiB > 0
        warningThreshold: 85
        criticalThreshold: 90
    }

    UsageDashboardObservation {
        id: gpuObservation
        key: "overview-gpu"
        presentationMode: root.presentationMode
        available: Stats.gpuAvailable
        primaryLabel: qsTr("GPU compute")
        secondaryLabel: qsTr("VRAM")
        primaryPercent: Stats.gpuUtilPercent
        secondaryPercent: Stats.gpuVramPercent
        warningThreshold: 85
        criticalThreshold: 90
    }

    StorageDashboardObservation {
        id: storageObservation
        presentationMode: root.presentationMode
        partitions: Stats.diskPartitions
    }

    readonly property var activeInterface: {
        const _ = NetworkInterfaces.revision;
        return NetworkInterfaces.activeInterface();
    }

    readonly property string connectionSummary: {
        if (NetworkService.hasWiredConnection)
            return qsTr("%1 connected").arg(NetworkService.wiredDeviceName);
        if (NetworkService.connectedSsid)
            return NetworkService.connectedSsid;
        return NetworkService.wifiEnabled ? qsTr("No active network") : qsTr("Wi-Fi disabled");
    }

    readonly property string bluetoothSummary: {
        if (!BluetoothService.available)
            return qsTr("No adapter available");
        if (!BluetoothService.enabled)
            return qsTr("Bluetooth disabled");
        const count = BluetoothService.connectedCount;
        return count > 0 ? qsTr("%1 connected").arg(count) : qsTr("Ready to connect");
    }

    function percentColor(percent, normalColor, warningThreshold, criticalThreshold) {
        const value = Number(percent || 0);
        const warning = Number(warningThreshold !== undefined ? warningThreshold : 75);
        const critical = Number(criticalThreshold !== undefined ? criticalThreshold : 90);
        if (value >= critical)
            return Config.styling.critical;
        if (value >= warning)
            return Config.styling.warning;
        return normalColor;
    }

    function observationColor(observation, normalColor) {
        switch (observation.severity) {
        case DashboardObservation.Critical:
            return Config.styling.critical;
        case DashboardObservation.Warning:
            return Config.styling.warning;
        case DashboardObservation.Notice:
            return Config.styling.primaryAccent;
        case DashboardObservation.Normal:
        default:
            return normalColor;
        }
    }

    DashboardSection {
        Layout.fillWidth: true
        title: qsTr("Audio")
        iconName: AudioService.outputIconName
        iconColor: AudioService.outputMuted ? Config.styling.critical : AudioService.outputIconColor
        titleColor: AudioService.outputMuted ? Config.styling.critical : AudioService.outputIconColor

        AudioDeviceCard {
            title: AudioService.outputDeviceName
            iconName: AudioService.outputIconName
            iconColor: AudioService.outputIconColor
            valueText: AudioService.defaultSink ? `${AudioService.outputVolume}%` : ""
            from: 0; to: 100
            value: AudioService.outputVolume
            stepSize: 1
            iconEnabled: !!AudioService.defaultSink
            sliderEnabled: !!AudioService.defaultSink && !AudioService.outputMuted
            accentColor: AudioService.outputMuted ? Config.styling.critical : Config.colors.blue
            onIconClicked: AudioService.toggleOutputMute()
            onValueModified: value => AudioService.setOutputVolume(value)
        }

        AudioDeviceCard {
            visible: root.detailed
            title: AudioService.inputDeviceName
            iconName: AudioService.inputIconName
            iconColor: AudioService.inputIconColor
            valueText: AudioService.defaultSource ? `${AudioService.inputVolume}%` : ""
            from: 0; to: 100
            value: AudioService.inputVolume
            stepSize: 1
            iconEnabled: !!AudioService.defaultSource
            sliderEnabled: !!AudioService.defaultSource && !AudioService.inputMuted
            accentColor: AudioService.inputMuted ? Config.styling.critical : Config.colors.blue
            onIconClicked: AudioService.toggleInputMute()
            onValueModified: value => AudioService.setInputVolume(value)
        }
    }

    DashboardSection {
        Layout.fillWidth: true
        title: qsTr("Brightness")
        iconName: Brightness.iconName
        iconColor: Config.colors.yellow
        titleColor: Config.colors.yellow
        visible: Brightness.available

        LabeledSlider {
            Layout.fillWidth: true
            label: qsTr("Display")
            iconName: Brightness.iconName
            value: Brightness.percent
            from: 0
            to: 100
            valueText: Brightness.available ? `${Brightness.percent}%` : qsTr("Unavailable")
            enabled: Brightness.available
            onValueCommitted: val => Brightness.setPercent(val)
        }
    }

    NavigableSectionHeader {
        Layout.fillWidth: true
        title: qsTr("Network")
        iconName: NetworkService.hasWiredConnection
            ? "network-wired-symbolic"
            : (NetworkService.wifiEnabled ? "network-wireless-symbolic" : "network-wireless-offline-symbolic")
        iconColor: NetworkService.connected
            ? Config.colors.green
            : (NetworkService.wifiEnabled ? Config.styling.warning : Config.styling.text1)
        titleColor: iconColor
        screenState: root.screenState
        targetTab: "wifi"

        DashboardSwitchRow {
            Layout.fillWidth: true
            label: qsTr("Wi-Fi")
            subtitle: root.connectionSummary
            iconName: NetworkService.wifiEnabled ? "network-wireless-symbolic" : "network-wireless-offline-symbolic"
            iconColor: NetworkService.connected
                ? Config.colors.green
                : (NetworkService.wifiEnabled ? Config.styling.warning : Config.styling.text1)
            enabled: NetworkService.wifiHardwareEnabled
            checked: NetworkService.wifiEnabled
            onToggled: function (checked) {
                NetworkService.setWifiEnabled(checked);
            }
        }

        InfoRow {
            Layout.fillWidth: true
            visible: root.detailed && NetworkService.connected
            iconName: NetworkService.hasWiredConnection ? "network-wired-symbolic" : "network-wireless-symbolic"
            iconColor: Config.colors.green
            labelColor: Config.colors.green
            label: qsTr("Interface")
            value: root.activeInterface
                ? root.activeInterface.name
                : (NetworkService.hasWiredConnection
                    ? NetworkService.wiredDeviceName
                    : NetworkService.wifiDeviceName)
            valueColor: Config.colors.green
        }

        InfoRow {
            Layout.fillWidth: true
            visible: root.detailed && !!root.activeInterface && root.activeInterface.mac !== ""
            iconName: "network-server-symbolic"
            iconColor: Config.colors.blue
            labelColor: Config.colors.blue
            label: qsTr("Interface MAC")
            value: root.activeInterface ? root.activeInterface.mac : ""
            valueColor: Config.colors.blue
        }

        InfoRow {
            Layout.fillWidth: true
            visible: root.detailed && !!root.activeInterface
            iconName: "network-server-symbolic"
            iconColor: Config.colors.mauve
            labelColor: Config.colors.mauve
            label: qsTr("IPv4")
            value: root.activeInterface
                ? NetworkInterfaces.formatAddresses(root.activeInterface.ipv4)
                : qsTr("Unavailable")
            valueColor: Config.colors.mauve
        }

        InfoRow {
            Layout.fillWidth: true
            visible: root.detailed && !NetworkService.hasWiredConnection && NetworkService.connectedAddress !== ""
            iconName: "network-wireless-symbolic"
            iconColor: Config.colors.peach
            labelColor: Config.colors.peach
            label: qsTr("Access point BSSID")
            value: NetworkService.connectedAddress
            valueColor: Config.colors.peach
        }

        InfoRow {
            Layout.fillWidth: true
            visible: root.detailed
            iconName: "network-transmit-receive-symbolic"
            iconColor: Config.colors.green
            labelColor: Config.colors.green
            label: qsTr("Connectivity")
            value: NetworkService.connectivity
            valueColor: NetworkService.connected ? Config.colors.green : Config.styling.warning
        }
    }

    NavigableSectionHeader {
        Layout.fillWidth: true
        title: qsTr("Bluetooth")
        iconName: BluetoothService.enabled ? "bluetooth-symbolic" : "bluetooth-disabled-symbolic"
        iconColor: BluetoothService.enabled ? Config.styling.bluetooth : Config.styling.text1
        titleColor: iconColor
        screenState: root.screenState
        targetTab: "bluetooth"

        DashboardSwitchRow {
            Layout.fillWidth: true
            label: qsTr("Bluetooth")
            subtitle: root.bluetoothSummary
            iconName: BluetoothService.enabled ? "bluetooth-symbolic" : "bluetooth-disabled-symbolic"
            iconColor: BluetoothService.enabled ? Config.styling.bluetooth : Config.styling.text1
            enabled: BluetoothService.available
            checked: BluetoothService.enabled
            onToggled: function (checked) {
                BluetoothService.setEnabled(checked);
            }
        }

        InfoRow {
            Layout.fillWidth: true
            visible: root.detailed && BluetoothService.available
            iconName: "bluetooth-active-symbolic"
            iconColor: Config.styling.bluetooth
            labelColor: Config.styling.bluetooth
            label: qsTr("Connected devices")
            value: String(BluetoothService.connectedCount)
            valueColor: Config.styling.bluetooth
        }
    }

    DashboardSection {
        Layout.fillWidth: true
        title: qsTr("Battery and power")
        iconName: PowerService.iconName
        iconColor: PowerService.iconColor
        titleColor: iconColor
        visible: PowerService.hasBattery

        Battery {
            id: batteryContent
            Layout.fillWidth: true
            showGraph: root.detailed
        }
    }

    NavigableSectionHeader {
        id: notificationsSection
        Layout.fillWidth: true
        title: qsTr("Notifications")
        iconName: NotificationCenter.doNotDisturbEnabled ? "notifications-disabled-symbolic" : "bell-symbolic"
        iconColor: NotificationCenter.doNotDisturbEnabled
            ? Config.colors.mauve
            : (NotificationCenter.count > 0 ? Config.colors.yellow : Config.styling.text1)
        titleColor: iconColor
        screenState: root.screenState
        targetTab: "notifications"

        InfoRow {
            Layout.fillWidth: true
            iconName: NotificationCenter.doNotDisturbEnabled ? "notifications-disabled-symbolic" : "bell-symbolic"
            iconColor: notificationsSection.iconColor
            labelColor: notificationsSection.iconColor
            label: qsTr("Status")
            value: NotificationCenter.doNotDisturbEnabled
                ? qsTr("Do Not Disturb")
                : qsTr("%1 unread").arg(NotificationCenter.count)
            valueColor: notificationsSection.iconColor
        }
    }

    NavigableSectionHeader {
        id: statsSection
        Layout.fillWidth: true
        title: qsTr("System statistics")
        iconName: "processor-symbolic"
        iconColor: root.observationColor(cpuObservation, Config.colors.blue)
        titleColor: iconColor
        screenState: root.screenState
        targetTab: "stats"

        MetricGrid {
            visible: !root.detailed

            RadialMetric {
                Layout.fillWidth: true
                label: qsTr("CPU")
                iconName: "processor-symbolic"
                percent: Stats.cpuPercent
                accentColor: root.percentColor(Stats.cpuPercent, Config.colors.blue, 75, 90)
                detail: qsTr("average")
                emphasized: cpuObservation.promoted
            }

            RadialMetric {
                Layout.fillWidth: true
                label: qsTr("RAM")
                iconName: "computer-symbolic"
                percent: Stats.memoryPercent
                accentColor: root.percentColor(Stats.memoryPercent, Config.colors.blue, 85, 90)
                detail: `${Stats.memoryUsedMiB}/${Stats.memoryTotalMiB} MiB`
                emphasized: Stats.memoryPercent >= memoryObservation.warningThreshold
            }

            RadialMetric {
                Layout.fillWidth: true
                label: qsTr("Root")
                iconName: "drive-harddisk-symbolic"
                percent: Stats.rootDiskPercent
                accentColor: root.percentColor(Stats.rootDiskPercent, Config.colors.peach, 75, 90)
                detail: qsTr("filesystem")
                emphasized: Stats.rootDiskPercent >= storageObservation.warningThreshold
            }

            RadialMetric {
                visible: Stats.swapTotalMiB > 0
                Layout.fillWidth: true
                label: qsTr("Swap")
                iconName: "drive-harddisk-symbolic"
                percent: Stats.swapPercent
                accentColor: root.percentColor(Stats.swapPercent, Config.colors.mauve, 85, 90)
                detail: `${Stats.swapUsedMiB}/${Stats.swapTotalMiB} MiB`
                emphasized: Stats.swapPercent >= memoryObservation.warningThreshold
            }

            RadialMetric {
                visible: Stats.gpuAvailable
                Layout.fillWidth: true
                label: qsTr("GPU")
                iconName: "video-display-symbolic"
                percent: Stats.gpuUtilPercent
                accentColor: root.percentColor(Stats.gpuUtilPercent, Config.colors.green, 85, 90)
                detail: qsTr("compute")
                emphasized: Stats.gpuUtilPercent >= gpuObservation.warningThreshold
            }

            RadialMetric {
                visible: Stats.gpuAvailable
                Layout.fillWidth: true
                label: qsTr("VRAM")
                iconName: "video-display-symbolic"
                percent: Stats.gpuVramPercent
                accentColor: root.percentColor(Stats.gpuVramPercent, Config.colors.mauve, 85, 90)
                detail: `${Stats.gpuVramUsedMiB}/${Stats.gpuVramTotalMiB} MiB`
                emphasized: Stats.gpuVramPercent >= gpuObservation.warningThreshold
            }

            Repeater {
                model: cpuObservation.promotedRows

                delegate: RadialMetric {
                    required property var modelData
                    Layout.fillWidth: true
                    label: qsTr("Core %1").arg(modelData.index)
                    iconName: "processor-symbolic"
                    percent: Number(modelData.percent || 0)
                    accentColor: modelData.severity === DashboardObservation.Critical
                        ? Config.styling.critical
                        : Config.styling.warning
                    detail: qsTr("outlier")
                    emphasized: true
                }
            }

            Repeater {
                model: storageObservation.exceptionalRows.filter(function(row) {
                    return String(row?.mount || "") !== "/";
                })

                delegate: RadialMetric {
                    required property var modelData
                    Layout.fillWidth: true
                    label: modelData.mount || modelData.device || qsTr("Disk")
                    iconName: "drive-harddisk-symbolic"
                    percent: Number(modelData.percent || 0)
                    accentColor: root.percentColor(percent, Config.colors.peach, 75, 90)
                    detail: qsTr("filesystem")
                    emphasized: true
                }
            }
        }

        InfoRow {
            Layout.fillWidth: true
            visible: root.detailed
            iconName: "processor-symbolic"
            iconColor: root.percentColor(Stats.cpuPercent, Config.colors.blue, 75, 90)
            labelColor: iconColor
            label: qsTr("CPU average")
            value: `${Math.round(Stats.cpuPercent)}%`
            valueColor: iconColor
        }

        Repeater {
            model: root.detailed ? cpuObservation.promotedRows : []

            InfoRow {
                required property var modelData
                Layout.fillWidth: true
                iconName: "processor-symbolic"
                iconColor: modelData.severity === DashboardObservation.Critical
                    ? Config.styling.critical
                    : Config.styling.warning
                labelColor: iconColor
                label: qsTr("Core %1 outlier").arg(modelData.index)
                value: `${Math.round(modelData.percent)}%`
                valueColor: iconColor
            }
        }

        InfoRow {
            Layout.fillWidth: true
            visible: root.detailed
            iconName: "computer-symbolic"
            iconColor: root.percentColor(Stats.memoryPercent, Config.colors.blue, 85, 90)
            labelColor: iconColor
            label: qsTr("Memory")
            value: `${Stats.memoryUsedMiB}/${Stats.memoryTotalMiB} MiB`
            valueColor: iconColor
        }

        InfoRow {
            Layout.fillWidth: true
            visible: root.detailed && Stats.swapTotalMiB > 0
            iconName: "drive-harddisk-symbolic"
            iconColor: root.percentColor(Stats.swapPercent, Config.colors.mauve, 85, 90)
            labelColor: iconColor
            label: qsTr("Swap")
            value: `${Stats.swapUsedMiB}/${Stats.swapTotalMiB} MiB`
            valueColor: iconColor
        }

        InfoRow {
            Layout.fillWidth: true
            visible: root.detailed
            iconName: "drive-harddisk-symbolic"
            iconColor: root.percentColor(Stats.rootDiskPercent, Config.colors.peach, 75, 90)
            labelColor: iconColor
            label: qsTr("Root filesystem")
            value: `${Math.round(Stats.rootDiskPercent)}%`
            valueColor: iconColor
        }

        InfoRow {
            Layout.fillWidth: true
            visible: root.detailed && Stats.gpuAvailable
            iconName: "video-display-symbolic"
            iconColor: root.observationColor(gpuObservation, Config.colors.green)
            labelColor: iconColor
            label: qsTr("GPU / VRAM")
            value: `${Math.round(Stats.gpuUtilPercent)}% / ${Math.round(Stats.gpuVramPercent)}%`
            valueColor: iconColor
        }

        InfoRow {
            Layout.fillWidth: true
            visible: root.detailed && Stats.primaryInterface !== ""
            iconName: "network-transmit-receive-symbolic"
            iconColor: Config.colors.green
            labelColor: Config.colors.green
            label: qsTr("Network I/O")
            value: `↓ ${Stats.formatRate(Stats.rxBytesPerSecond)} · ↑ ${Stats.formatRate(Stats.txBytesPerSecond)}`
            valueColor: Config.colors.green
        }
    }

    DashboardSection {
        Layout.fillWidth: true
        title: qsTr("Session")
        iconName: "system-shutdown-symbolic"
        iconColor: Config.colors.red
        titleColor: Config.colors.red

        SessionActionsGrid {
            Layout.fillWidth: true
        }
    }

    component MetricGrid: GridLayout {
        Layout.fillWidth: true
        columns: Math.max(1, Math.floor((width + columnSpacing) / (108 + columnSpacing)))
        columnSpacing: Config.spacing.xs
        rowSpacing: Config.spacing.xs
        uniformCellWidths: true
    }
}
