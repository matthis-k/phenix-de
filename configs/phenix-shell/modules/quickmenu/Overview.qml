import QtQuick
import QtQuick.Layouts
import Quickshell.Io

import qs.services
import qs.components

DashboardPage {
    id: root

    title: qsTr("Quick Settings")

    property var screenState: null

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

    DashboardSection {
        Layout.fillWidth: true
        title: qsTr("Audio")

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
        title: qsTr("Brightness")
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
        screenState: root.screenState
        targetTab: "wifi"

        DashboardSwitchRow {
            Layout.fillWidth: true
            label: qsTr("Wi-Fi")
            subtitle: root.connectionSummary
            iconName: NetworkService.wifiEnabled ? "network-wireless-symbolic" : "network-wireless-offline-symbolic"
            iconColor: NetworkService.wifiEnabled ? Config.styling.primaryAccent : Config.styling.text1
            enabled: NetworkService.wifiHardwareEnabled
            checked: NetworkService.wifiEnabled
            onToggled: function (checked) {
                NetworkService.setWifiEnabled(checked);
            }
        }
    }

    NavigableSectionHeader {
        Layout.fillWidth: true
        title: qsTr("Bluetooth")
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
    }

    DashboardSection {
        Layout.fillWidth: true
        title: qsTr("Battery and power")
        visible: PowerService.hasBattery

        Battery {
            id: batteryContent
            Layout.fillWidth: true
            showGraph: false
        }
    }

    NavigableSectionHeader {
        Layout.fillWidth: true
        title: qsTr("Notifications")
        screenState: root.screenState
        targetTab: "notifications"

        InfoRow {
            Layout.fillWidth: true
            iconName: "bell-symbolic"
            label: qsTr("Status")
            value: NotificationCenter.doNotDisturbEnabled
                ? qsTr("Do Not Disturb")
                : qsTr("%1 unread").arg(NotificationCenter.count)
        }
    }

    NavigableSectionHeader {
        Layout.fillWidth: true
        title: qsTr("System statistics")
        screenState: root.screenState
        targetTab: "stats"

        InfoRow {
            Layout.fillWidth: true
            iconName: "processor-symbolic"
            label: qsTr("CPU")
            value: `${Math.round(Stats.cpuPercent)}%`
            valueColor: Stats.cpuPercent >= 90 ? Config.styling.critical : (Stats.cpuPercent >= 70 ? Config.styling.warning : Config.styling.text0)
        }

        InfoRow {
            Layout.fillWidth: true
            iconName: "computer-symbolic"
            label: qsTr("Memory")
            value: `${Stats.memoryUsedMiB}/${Stats.memoryTotalMiB} MiB`
        }
    }

    DashboardSection {
        Layout.fillWidth: true
        title: qsTr("Session")

        SessionActionsGrid {
            Layout.fillWidth: true
        }
    }
}
