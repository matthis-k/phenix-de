import QtQuick
import QtQuick.Layouts
import Quickshell.Io

import qs.services
import qs.components

DashboardPage {
    id: root

    title: "Overview"

    property var screenState: null

    readonly property string connectionSummary: {
        if (NetworkService.hasWiredConnection)
            return `${NetworkService.wiredDeviceName} connected`;
        if (NetworkService.connectedSsid)
            return NetworkService.connectedSsid;
        return NetworkService.wifiEnabled ? "No active network" : "Wi-Fi disabled";
    }

    readonly property string bluetoothSummary: {
        if (!BluetoothService.available)
            return "No adapter available";
        if (!BluetoothService.enabled)
            return "Bluetooth disabled";
        const count = BluetoothService.connectedCount;
        return count > 0 ? `${count} connected` : "Ready to connect";
    }

    DashboardSection {
        Layout.fillWidth: true
        title: "Session"

        SessionActionsGrid {
            Layout.fillWidth: true
        }
    }

    DashboardSection {
        Layout.fillWidth: true
        title: "Connectivity"

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Config.spacing.xs

            DashboardSwitchRow {
                Layout.fillWidth: true
                label: "Wi-Fi"
                subtitle: root.connectionSummary
                iconName: NetworkService.wifiEnabled ? "network-wireless-symbolic" : "network-wireless-offline-symbolic"
                iconColor: NetworkService.wifiEnabled ? Config.styling.primaryAccent : Config.styling.text1
                enabled: NetworkService.wifiHardwareEnabled
                checked: NetworkService.wifiEnabled
                onToggled: function (checked) {
                    NetworkService.setWifiEnabled(checked);
                }
            }

            DashboardSwitchRow {
                Layout.fillWidth: true
                label: "Bluetooth"
                subtitle: root.bluetoothSummary
                iconName: BluetoothService.enabled ? "bluetooth-symbolic" : "bluetooth-disabled-symbolic"
                iconColor: BluetoothService.enabled ? Config.styling.bluetooth : Config.styling.text1
                enabled: BluetoothService.available
                checked: BluetoothService.enabled
                onToggled: function (checked) {
                    BluetoothService.setEnabled(checked);
                }
            }
        }
    }

    DashboardSection {
        Layout.fillWidth: true
        title: "Audio"

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
        title: "Brightness"
        visible: Brightness.available

        LabeledSlider {
            Layout.fillWidth: true
            label: "Display"
            iconName: Brightness.iconName
            value: Brightness.percent
            from: 0
            to: 100
            valueText: Brightness.available ? `${Brightness.percent}%` : "Unavailable"
            enabled: Brightness.available
            onValueCommitted: val => Brightness.setPercent(val)
        }
    }

    DashboardSection {
        Layout.fillWidth: true
        title: "Battery and power"
        visible: PowerService.hasBattery

        Battery {
            id: batteryContent
            Layout.fillWidth: true
            showGraph: false
        }
    }

    NavigableSectionHeader {
        Layout.fillWidth: true
        title: "Notifications"
        screenState: root.screenState
        targetTab: "notifications"

        InfoRow {
            Layout.fillWidth: true
            iconName: "bell-symbolic"
            label: "Status"
            value: NotificationCenter.doNotDisturbEnabled ? "Do Not Disturb" : `${NotificationCenter.count} unread`
        }
    }

    NavigableSectionHeader {
        Layout.fillWidth: true
        title: "System stats"
        screenState: root.screenState
        targetTab: "stats"

        InfoRow {
            Layout.fillWidth: true
            iconName: "processor-symbolic"
            label: "CPU"
            value: `${Math.round(Stats.cpuPercent)}%`
            valueColor: Stats.cpuPercent >= 90 ? Config.styling.critical : (Stats.cpuPercent >= 70 ? Config.styling.warning : Config.styling.text0)
        }

        InfoRow {
            Layout.fillWidth: true
            iconName: "computer-symbolic"
            label: "Memory"
            value: `${Stats.memoryUsedMiB}/${Stats.memoryTotalMiB} MiB`
        }
    }

}
