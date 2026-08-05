import QtQuick
import QtQuick.Layouts

import qs.services
import qs.components

DashboardPage {
    id: root

    title: qsTr("Quick Settings")
    scrollable: true

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

    NavigableSectionHeader {
        id: audioControlsSection
        Layout.fillWidth: true
        title: qsTr("Audio")
        iconName: AudioService.outputIconName
        iconColor: AudioService.outputMuted
            ? Config.styling.critical
            : AudioService.outputIconColor
        titleColor: iconColor
        screenState: root.screenState
        targetTab: "audio"
        showDetailToggle: !!AudioService.defaultSource

        AudioDeviceCard {
            title: AudioService.outputDeviceName
            iconName: AudioService.outputIconName
            iconColor: AudioService.outputIconColor
            valueText: AudioService.defaultSink ? `${AudioService.outputVolume}%` : ""
            from: 0
            to: 100
            value: AudioService.outputVolume
            stepSize: 1
            iconEnabled: !!AudioService.defaultSink
            sliderEnabled: !!AudioService.defaultSink && !AudioService.outputMuted
            accentColor: AudioService.outputMuted ? Config.styling.critical : Config.colors.blue
            onIconClicked: AudioService.toggleOutputMute()
            onValueModified: value => AudioService.setOutputVolume(value)
        }

        AudioDeviceCard {
            visible: audioControlsSection.detailed || AudioService.inputMuted
            title: AudioService.inputDeviceName
            iconName: AudioService.inputIconName
            iconColor: AudioService.inputIconColor
            valueText: AudioService.defaultSource ? `${AudioService.inputVolume}%` : ""
            from: 0
            to: 100
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
        visible: Brightness.available
        title: qsTr("Display")
        iconName: Brightness.iconName
        iconColor: Config.colors.yellow
        titleColor: iconColor

        LabeledSlider {
            Layout.fillWidth: true
            label: qsTr("Brightness")
            iconName: Brightness.iconName
            value: Brightness.percent
            from: 0
            to: 100
            valueText: `${Brightness.percent}%`
            onValueCommitted: value => Brightness.setPercent(value)
        }
    }

    NavigableSectionHeader {
        id: networkSection
        Layout.fillWidth: true
        title: qsTr("Network")
        iconName: NetworkService.hasWiredConnection
            ? "network-wired-symbolic"
            : (NetworkService.wifiEnabled
                ? "network-wireless-symbolic"
                : "network-wireless-offline-symbolic")
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
            iconName: NetworkService.wifiEnabled
                ? "network-wireless-symbolic"
                : "network-wireless-offline-symbolic"
            iconColor: NetworkService.connected
                ? Config.colors.green
                : (NetworkService.wifiEnabled ? Config.styling.warning : Config.styling.text1)
            enabled: NetworkService.wifiHardwareEnabled
            checked: NetworkService.wifiEnabled
            onToggled: checked => NetworkService.setWifiEnabled(checked)
        }

    }

    NavigableSectionHeader {
        id: bluetoothSection
        Layout.fillWidth: true
        title: qsTr("Bluetooth")
        iconName: BluetoothService.enabled
            ? "bluetooth-symbolic"
            : "bluetooth-disabled-symbolic"
        iconColor: BluetoothService.enabled
            ? Config.styling.bluetooth
            : Config.styling.text1
        titleColor: iconColor
        screenState: root.screenState
        targetTab: "bluetooth"

        DashboardSwitchRow {
            Layout.fillWidth: true
            label: qsTr("Bluetooth")
            subtitle: root.bluetoothSummary
            iconName: BluetoothService.enabled
                ? "bluetooth-symbolic"
                : "bluetooth-disabled-symbolic"
            iconColor: BluetoothService.enabled
                ? Config.styling.bluetooth
                : Config.styling.text1
            enabled: BluetoothService.available
            checked: BluetoothService.enabled
            onToggled: checked => BluetoothService.setEnabled(checked)
        }

    }

    DashboardSection {
        id: batterySection
        Layout.fillWidth: true
        title: qsTr("Battery and power")
        iconName: PowerService.iconName
        iconColor: PowerService.iconColor
        titleColor: iconColor
        visible: PowerService.hasBattery
        showDetailToggle: true

        Battery {
            Layout.fillWidth: true
            showGraph: false
            showPowerModes: batterySection.detailed
        }
    }

    NavigableSectionHeader {
        id: notificationsSection
        Layout.fillWidth: true
        title: qsTr("Notifications")
        iconName: NotificationCenter.doNotDisturbEnabled
            ? "notifications-disabled-symbolic"
            : "bell-symbolic"
        iconColor: NotificationCenter.doNotDisturbEnabled
            ? Config.colors.mauve
            : (NotificationCenter.count > 0 ? Config.colors.yellow : Config.styling.text1)
        titleColor: iconColor
        screenState: root.screenState
        targetTab: "notifications"

        InfoRow {
            Layout.fillWidth: true
            iconName: notificationsSection.iconName
            iconColor: notificationsSection.iconColor
            labelColor: notificationsSection.iconColor
            label: NotificationCenter.doNotDisturbEnabled
                ? qsTr("Do Not Disturb")
                : qsTr("Unread")
            value: NotificationCenter.doNotDisturbEnabled
                ? qsTr("Enabled")
                : String(NotificationCenter.count)
            valueColor: notificationsSection.iconColor
        }
    }

    NavigableSectionHeader {
        id: statsSection
        Layout.fillWidth: true
        title: qsTr("System health")
        iconName: "utilities-system-monitor-symbolic"
        iconColor: root.observationColor(cpuObservation, Config.colors.blue)
        titleColor: iconColor
        screenState: root.screenState
        targetTab: "stats"
        showDetailToggle: true

        MetricGrid {
            Repeater {
                model: cpuObservation.promotedRows

                delegate: RadialMetric {
                    required property var modelData
                    Layout.fillWidth: true
                    label: qsTr("Core %1").arg(modelData.index)
                    iconName: "utilities-system-monitor-symbolic"
                    percent: Number(modelData.percent || 0)
                    accentColor: modelData.severity === DashboardObservation.Critical
                        ? Config.styling.critical
                        : Config.styling.warning
                    detail: qsTr("outlier")
                    emphasized: true
                }
            }

            Repeater {
                model: storageObservation.exceptionalRows.filter(row => String(row?.mount || "") !== "/")

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

            RadialMetric {
                Layout.fillWidth: true
                label: qsTr("CPU")
                iconName: "utilities-system-monitor-symbolic"
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
                visible: statsSection.detailed && Stats.swapTotalMiB > 0
                Layout.fillWidth: true
                label: qsTr("Swap")
                iconName: "drive-harddisk-symbolic"
                percent: Stats.swapPercent
                accentColor: root.percentColor(Stats.swapPercent, Config.colors.mauve, 85, 90)
                detail: `${Stats.swapUsedMiB}/${Stats.swapTotalMiB} MiB`
            }

            RadialMetric {
                visible: statsSection.detailed && Stats.gpuAvailable
                Layout.fillWidth: true
                label: qsTr("GPU")
                iconName: "video-display-symbolic"
                percent: Stats.gpuUtilPercent
                accentColor: root.percentColor(Stats.gpuUtilPercent, Config.colors.green, 85, 90)
                detail: qsTr("compute")
            }

            RadialMetric {
                visible: statsSection.detailed && Stats.gpuAvailable
                Layout.fillWidth: true
                label: qsTr("VRAM")
                iconName: "video-display-symbolic"
                percent: Stats.gpuVramPercent
                accentColor: root.percentColor(Stats.gpuVramPercent, Config.colors.mauve, 85, 90)
                detail: `${Stats.gpuVramUsedMiB}/${Stats.gpuVramTotalMiB} MiB`
            }

        }

        InfoRow {
            Layout.fillWidth: true
            visible: statsSection.detailed && Stats.primaryInterface !== ""
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
