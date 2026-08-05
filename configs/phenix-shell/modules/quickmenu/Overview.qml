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
        revision: Stats.cpuRevision
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

    readonly property string vpnSummary: {
        if (!VpnService.available)
            return qsTr("Unavailable");
        if (VpnService.connecting)
            return qsTr("Connecting");
        if (VpnService.connected)
            return VpnService.location || qsTr("Connected");
        return qsTr("Disconnected");
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

    DashboardSection {
        Layout.fillWidth: true
        contentSpacing: 3

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
            navigationEnabled: true
            navigationLabel: qsTr("Open network details")
            onToggled: checked => NetworkService.setWifiEnabled(checked)
            onNavigationRequested: {
                if (root.screenState)
                    root.screenState.openDashboard("wifi");
            }
        }

        DashboardSwitchRow {
            Layout.fillWidth: true
            label: qsTr("VPN")
            subtitle: root.vpnSummary
            iconName: VpnService.iconName
            iconColor: VpnService.iconColor
            enabled: VpnService.available && !VpnService.connecting
            checked: VpnService.connected || VpnService.connecting
            onToggled: checked => checked ? VpnService.connect(null) : VpnService.disconnect()
        }
    }

    DashboardSection {
        Layout.fillWidth: true

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
            navigationEnabled: true
            navigationLabel: qsTr("Open Bluetooth details")
            onToggled: checked => BluetoothService.setEnabled(checked)
            onNavigationRequested: {
                if (root.screenState)
                    root.screenState.openDashboard("bluetooth");
            }
        }
    }

    DashboardSection {
        Layout.fillWidth: true
        visible: PowerService.hasBattery

        Battery {
            Layout.fillWidth: true
            compact: true
            showGraph: false
            showPowerModes: true
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
        Layout.fillWidth: true
        title: qsTr("System health")
        iconName: "utilities-system-monitor-symbolic"
        iconColor: root.observationColor(cpuObservation, Config.colors.blue)
        titleColor: iconColor
        screenState: root.screenState
        targetTab: "stats"

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: Config.spacing.xs
            rowSpacing: 0
            uniformCellWidths: true

            RadialMetric {
                Layout.fillWidth: true
                compact: true
                label: qsTr("RAM")
                percent: Stats.memoryPercent
                accentColor: root.percentColor(Stats.memoryPercent, Config.colors.blue, 85, 90)
                emphasized: Stats.memoryPercent >= memoryObservation.warningThreshold
            }

            RadialMetric {
                Layout.fillWidth: true
                compact: true
                label: qsTr("CPU")
                percent: Stats.cpuPercent
                accentColor: root.percentColor(Stats.cpuPercent, Config.colors.blue, 75, 90)
                emphasized: cpuObservation.promoted
            }

            RadialMetric {
                Layout.fillWidth: true
                compact: true
                label: qsTr("Storage")
                percent: Stats.rootDiskPercent
                accentColor: root.percentColor(Stats.rootDiskPercent, Config.colors.peach, 75, 90)
                emphasized: Stats.rootDiskPercent >= storageObservation.warningThreshold
            }
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

}
