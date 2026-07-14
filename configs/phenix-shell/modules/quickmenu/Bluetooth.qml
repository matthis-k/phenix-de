import QtQuick
import QtQuick.Layouts

import qs.services
import qs.components
import "bluetooth"

DashboardPage {
    id: root

    title: "Bluetooth"
    fillHeight: true
    headerAccessory: Component {
        DashboardToggleSwitch {
            enabled: BluetoothService.available
            checked: BluetoothService.enabled
            onToggled: BluetoothService.setAdapterEnabled(checked)
        }
    }

    readonly property int contentWidth: width > 0 ? width : 320
    readonly property int itemSpacing: 3
    readonly property int rowHeight: 36
    readonly property int iconSlotWidth: 28
    readonly property int iconSize: 20
    readonly property int itemIconSize: 22
    readonly property int itemTextSize: 16
    readonly property int itemSubtextSize: 12
    readonly property int iconTextGap: 10
    readonly property int horizontalPadding: 8
    readonly property int verticalPadding: 4

    BluetoothInteractionState {
        id: interactionState
        devices: BluetoothService.devices
    }

    readonly property var displayedDevices: interactionState.displayedDevices(BluetoothService.devices)
    readonly property var connectedDevices: displayedDevices.filter(device => !!device && device.connected)
    readonly property var otherDevices: displayedDevices.filter(device => !!device && !device.connected)
    readonly property bool interactiveDevicePresent: !interactionState.interactionLocked || displayedDevices.some(device => BluetoothService.deviceKey(device) === interactionState.interactiveDeviceKey)

    onInteractiveDevicePresentChanged: {
        if (!root.interactiveDevicePresent)
            interactionState.unlockInteraction();
    }

    BluetoothDeviceSection {
        title: "Connected devices"
        devices: root.connectedDevices
        interactionState: interactionState
        emptyText: "No connected Bluetooth devices"
        contentWidth: root.contentWidth
        itemSpacing: root.itemSpacing
        rowHeight: root.rowHeight
        iconSlotWidth: root.iconSlotWidth
        itemIconSize: root.itemIconSize
        itemTextSize: root.itemTextSize
        itemSubtextSize: root.itemSubtextSize
        iconTextGap: root.iconTextGap
        horizontalPadding: root.horizontalPadding
        verticalPadding: root.verticalPadding
    }

    BluetoothDeviceSection {
        Layout.fillHeight: true
        title: "Other devices"
        devices: root.otherDevices
        interactionState: interactionState
        emptyText: BluetoothService.enabled ? "No Bluetooth devices found" : "Bluetooth is off"
        scroll: true
        tabSwipeTarget: root.tabSwipeTarget
        contentWidth: root.contentWidth
        itemSpacing: root.itemSpacing
        rowHeight: root.rowHeight
        iconSlotWidth: root.iconSlotWidth
        itemIconSize: root.itemIconSize
        itemTextSize: root.itemTextSize
        itemSubtextSize: root.itemSubtextSize
        iconTextGap: root.iconTextGap
        horizontalPadding: root.horizontalPadding
        verticalPadding: root.verticalPadding
        headerAccessory: Component {
            DashboardIconButton {
                enabled: BluetoothService.available && BluetoothService.enabled
                iconName: "view-refresh-symbolic"
                fallbackIconName: "view-refresh-symbolic"
                onClicked: BluetoothService.scan(!BluetoothService.scanning)
            }
        }
    }
}
