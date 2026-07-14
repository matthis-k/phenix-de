import QtQuick
import QtQuick.Layouts

import qs.animations as Animations
import qs.services
import qs.components

Item {
    id: root

    required property var device
    property QtObject interactionState: null
    property int contentWidth: 320
    property int itemSpacing: 3
    property int rowHeight: 36
    property int iconSlotWidth: 28
    property int itemIconSize: 22
    property int itemTextSize: 16
    property int itemSubtextSize: 12
    property int iconTextGap: 10
    property int horizontalPadding: 8
    property int verticalPadding: 4

    readonly property bool hasDevice: !!root.device
    readonly property string rowKey: root.interactionState && root.device ? String(root.interactionState.deviceKey(root.device) || "") : ""
    readonly property bool expanded: root.interactionState && root.rowKey !== "" ? root.interactionState.interactiveDeviceKey === root.rowKey : false
    readonly property bool showAdvanced: root.expanded && root.interactionState ? !!root.interactionState.interactiveShowAdvanced : false
    readonly property bool isConnecting: root.hasDevice && BluetoothService.deviceStatusLabel(root.device) === "Connecting"
    readonly property bool isDisconnecting: root.hasDevice && BluetoothService.deviceStatusLabel(root.device) === "Disconnecting"
    readonly property bool isPairing: root.hasDevice && !!root.device.pairing

    implicitWidth: root.contentWidth
    implicitHeight: header.implicitHeight + (details.implicitHeight > 0 ? details.implicitHeight + root.itemSpacing : 0)
    height: implicitHeight

    onHasDeviceChanged: {
        if (!root.hasDevice && root.expanded && root.interactionState)
            root.interactionState.unlockInteraction();
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: root.itemSpacing

        DashboardListRow {
            id: header
            minimumRowHeight: root.rowHeight
            active: root.hasDevice && root.device.connected
            accentColor: root.hasDevice && root.device.connected ? Config.colors.blue : Config.styling.bluetooth
            fillOpacity: root.hasDevice && root.device.connected ? 0.28 : Config.behaviour.hoverBgOpacity
            iconName: root.hasDevice ? root.device.icon : "bluetooth-symbolic"
            fallbackIconName: "bluetooth-symbolic"
            iconColor: root.hasDevice && root.device.connected ? Config.colors.blue : Config.styling.text0
            title: root.hasDevice ? BluetoothService.displayName(root.device) : "Unavailable"
            subtitle: root.hasDevice
                ? `${BluetoothService.deviceTypeLabel(root.device)} | ${BluetoothService.batteryLabel(root.device)}${root.device.paired ? " | Paired" : ""}`
                : "Device unavailable"
            status: root.hasDevice
                ? root.device.connected
                    ? "Connected"
                    : root.isConnecting
                        ? "Connecting"
                        : root.isDisconnecting
                            ? "Disconnecting"
                            : root.isPairing
                                ? "Pairing"
                                : root.device.paired
                                    ? "Paired"
                                    : "Available"
                : "Unavailable"
            statusColor: root.hasDevice && root.device.connected
                ? Config.colors.blue
                : root.isConnecting || root.isDisconnecting || root.isPairing
                    ? Config.colors.yellow
                    : Config.styling.text1
            iconSlotWidth: root.iconSlotWidth
            iconSize: root.itemIconSize
            titleSize: root.itemTextSize
            subtitleSize: root.itemSubtextSize
            horizontalPadding: root.horizontalPadding
            verticalPadding: root.verticalPadding
            contentSpacing: root.iconTextGap

            onClicked: {
                if (root.expanded && root.interactionState)
                    root.interactionState.unlockInteraction();
                else if (root.hasDevice && root.interactionState)
                    root.interactionState.lockInteractionFor(root.device);
            }
        }

        Expander {
            id: details
            Layout.fillWidth: true
            expanded: root.expanded
            slideDistance: Config.spacing.sm

            Rectangle {
                width: parent.width
                height: implicitHeight
                color: Config.styling.bg1
                implicitHeight: detailsColumn.implicitHeight + root.horizontalPadding * 2

                ColumnLayout {
                    id: detailsColumn
                    anchors.fill: parent
                    anchors.margins: root.horizontalPadding
                    spacing: Config.spacing.xxs

                    Text {
                        Layout.fillWidth: true
                        text: root.hasDevice
                            ? `State: ${BluetoothService.deviceStatusLabel(root.device)} | Adapter: ${root.device.adapter ? root.device.adapter.adapterId : "unknown"}`
                            : "Device unavailable"
                        color: Config.styling.text1
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        implicitHeight: 28
                        spacing: root.itemSpacing

                        SmallButton {
                            Layout.fillWidth: true
                            text: root.hasDevice && root.device.connected
                                ? "Disconnect"
                                : root.hasDevice && !root.device.paired
                                    ? (root.device.pairing ? "Cancel Pair" : "Pair")
                                    : "Connect"
                            onClicked: {
                                if (!root.hasDevice) {
                                    if (root.interactionState)
                                        root.interactionState.unlockInteraction();
                                    return;
                                }

                                if (root.device.connected)
                                    BluetoothService.disconnectDevice(root.device);
                                else if (!root.device.paired)
                                    BluetoothService.pairOrCancelDevice(root.device);
                                else
                                    BluetoothService.connectDevice(root.device);
                            }
                        }

                        SmallButton {
                            visible: root.hasDevice && (root.device.paired || root.device.bonded || root.device.trusted)
                            text: root.hasDevice && root.device.trusted ? "Untrust" : "Trust"
                            onClicked: {
                                if (root.hasDevice)
                                    BluetoothService.toggleTrusted(root.device);
                            }
                        }

                        SmallButton {
                            visible: root.hasDevice && (root.device.paired || root.device.bonded)
                            text: "Forget"
                            onClicked: {
                                if (!root.hasDevice) {
                                    if (root.interactionState)
                                        root.interactionState.unlockInteraction();
                                    return;
                                }

                                BluetoothService.forgetDevice(root.device);
                                if (root.interactionState)
                                    root.interactionState.unlockInteraction();
                            }
                        }

                        SmallButton {
                            text: root.showAdvanced ? "Hide Advanced" : "Show Advanced"
                            onClicked: {
                                if (root.interactionState)
                                    root.interactionState.interactiveShowAdvanced = !root.interactionState.interactiveShowAdvanced;
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.showAdvanced
                        text: BluetoothService.advancedDeviceInfo(root.device)
                        color: Config.styling.text2
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }
}
