import QtQuick
import QtQuick.Layouts

import qs.animations as Animations
import qs.services
import qs.components

Item {
    id: root

    required property var device
    property QtObject interactionState: null
    property bool inheritedDetailed: false
    property bool localDetailed: false
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
    readonly property string rowKey: root.interactionState && root.device
        ? String(root.interactionState.deviceKey(root.device) || "")
        : ""
    readonly property bool interactionExpanded: root.interactionState && root.rowKey !== ""
        ? root.interactionState.interactiveDeviceKey === root.rowKey
        : false
    readonly property bool forcedDetailed: DashboardPresentation.detailed || root.inheritedDetailed
    readonly property bool detailed: root.forcedDetailed || root.localDetailed
    readonly property bool detailExpanded: root.interactionExpanded || root.detailed
    readonly property bool isConnecting: root.hasDevice
        && BluetoothService.deviceStatusLabel(root.device) === "Connecting"
    readonly property bool isDisconnecting: root.hasDevice
        && BluetoothService.deviceStatusLabel(root.device) === "Disconnecting"
    readonly property bool isPairing: root.hasDevice && !!root.device.pairing

    implicitWidth: root.contentWidth
    implicitHeight: header.implicitHeight + (details.implicitHeight > 0 ? details.implicitHeight + root.itemSpacing : 0)
    height: implicitHeight

    onHasDeviceChanged: {
        if (!root.hasDevice && root.interactionExpanded && root.interactionState)
            root.interactionState.unlockInteraction();
    }

    function toggleLocalDetails() {
        if (root.forcedDetailed)
            return;
        root.localDetailed = !root.localDetailed;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: root.itemSpacing

        DashboardListRow {
            id: header
            minimumRowHeight: root.rowHeight
            active: root.hasDevice && root.device.connected
            accentColor: root.hasDevice && root.device.connected
                ? Config.colors.blue
                : Config.styling.bluetooth
            fillOpacity: root.hasDevice && root.device.connected
                ? 0.28
                : Config.behaviour.hoverBgOpacity
            iconName: root.hasDevice ? root.device.icon : "bluetooth-symbolic"
            fallbackIconName: "bluetooth-symbolic"
            iconColor: root.hasDevice && root.device.connected
                ? Config.colors.blue
                : Config.styling.text0
            title: root.hasDevice
                ? BluetoothService.displayName(root.device)
                : qsTr("Unavailable")
            subtitle: root.hasDevice
                ? (root.detailed
                    ? `${BluetoothService.deviceTypeLabel(root.device)} | ${BluetoothService.batteryLabel(root.device)}${root.device.paired ? " | " + qsTr("Paired") : ""}`
                    : (root.device.connected
                        ? BluetoothService.batteryLabel(root.device)
                        : (root.device.paired ? qsTr("Paired") : "")))
                : qsTr("Device unavailable")
            status: root.hasDevice
                ? root.device.connected
                    ? qsTr("Connected")
                    : root.isConnecting
                        ? qsTr("Connecting")
                        : root.isDisconnecting
                            ? qsTr("Disconnecting")
                            : root.isPairing
                                ? qsTr("Pairing")
                                : root.device.paired
                                    ? qsTr("Paired")
                                    : qsTr("Available")
                : qsTr("Unavailable")
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
            accessory: Component {
                DashboardDetailToggle {
                    detailed: root.detailed
                    forcedDetailed: root.forcedDetailed
                    localDetailed: root.localDetailed
                    subject: root.hasDevice
                        ? BluetoothService.displayName(root.device)
                        : qsTr("Bluetooth device")
                    onToggleRequested: root.toggleLocalDetails()
                }
            }

            onClicked: {
                if (root.interactionExpanded && root.interactionState)
                    root.interactionState.unlockInteraction();
                else if (root.hasDevice && root.interactionState)
                    root.interactionState.lockInteractionFor(root.device);
            }
        }

        Expander {
            id: details
            Layout.fillWidth: true
            expanded: root.detailExpanded
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
                            ? qsTr("State: %1 | Adapter: %2").arg(
                                BluetoothService.deviceStatusLabel(root.device),
                                root.device.adapter ? root.device.adapter.adapterId : qsTr("unknown"))
                            : qsTr("Device unavailable")
                        color: Config.styling.text1
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.detailed
                        text: root.hasDevice
                            ? BluetoothService.advancedDeviceInfo(root.device)
                            : ""
                        color: Config.styling.text2
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: visible ? 32 : 0
                        implicitHeight: visible ? 32 : 0
                        visible: root.interactionExpanded
                        spacing: root.itemSpacing

                        SmallButton {
                            Layout.fillWidth: true
                            text: root.hasDevice && root.device.connected
                                ? qsTr("Disconnect")
                                : root.hasDevice && !root.device.paired
                                    ? (root.device.pairing ? qsTr("Cancel Pair") : qsTr("Pair"))
                                    : qsTr("Connect")
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
                            visible: root.detailed
                                && root.hasDevice
                                && (root.device.paired || root.device.bonded || root.device.trusted)
                            text: root.hasDevice && root.device.trusted
                                ? qsTr("Untrust")
                                : qsTr("Trust")
                            onClicked: {
                                if (root.hasDevice)
                                    BluetoothService.toggleTrusted(root.device);
                            }
                        }

                        ConfirmSmallButton {
                            visible: root.detailed
                                && root.hasDevice
                                && (root.device.paired || root.device.bonded)
                            text: qsTr("Forget")
                            confirmText: qsTr("Confirm forget")
                            onConfirmed: {
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
                    }
                }
            }
        }
    }
}
