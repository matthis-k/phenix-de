import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.services
import qs.components

ColumnLayout {
    id: root

    property QtObject interactionState: null
    property var networks: []
    property var connectedNetworks: []
    property var disconnectedNetworks: []
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
    property var tabSwipeTarget: null
    readonly property var activeInterface: {
        const _ = NetworkInterfaces.revision;
        return NetworkInterfaces.activeInterface();
    }

    spacing: 0

    DashboardSection {
        id: connectedSection
        Layout.fillWidth: true
        title: qsTr("Current connection")
        showDetailToggle: NetworkService.hasWiredConnection

        DashboardListRow {
            Layout.fillWidth: true
            visible: NetworkService.hasWiredConnection
            active: true
            accentColor: Config.colors.blue
            fillOpacity: 0.28
            iconName: "network-wired-symbolic"
            iconColor: Config.colors.blue
            title: NetworkService.wiredDeviceName || qsTr("Wired connection")
            subtitle: NetworkService.connectivity
            status: qsTr("Connected")
            statusColor: Config.colors.blue
            iconSlotWidth: root.iconSlotWidth
            iconSize: root.itemIconSize
            titleSize: root.itemTextSize
            subtitleSize: root.itemSubtextSize
            horizontalPadding: root.horizontalPadding
            verticalPadding: root.verticalPadding
            contentSpacing: root.iconTextGap
            accessory: Component {
                SmallButton {
                    text: qsTr("Disconnect")
                    accessibleName: qsTr("Disconnect wired connection")
                    onClicked: NetworkService.disconnectWired()
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: NetworkService.hasWiredConnection && connectedSection.detailed
            spacing: Config.spacing.xxs

            InfoRow {
                Layout.fillWidth: true
                visible: !!root.activeInterface && root.activeInterface.mac !== ""
                iconName: "network-server-symbolic"
                label: qsTr("Interface MAC")
                value: root.activeInterface ? root.activeInterface.mac : ""
            }

            InfoRow {
                Layout.fillWidth: true
                visible: !!root.activeInterface
                iconName: "network-server-symbolic"
                label: qsTr("IPv4")
                value: root.activeInterface
                    ? NetworkInterfaces.formatAddresses(root.activeInterface.ipv4)
                    : ""
            }

            InfoRow {
                Layout.fillWidth: true
                visible: !!root.activeInterface && root.activeInterface.ipv6.length > 0
                iconName: "network-server-symbolic"
                label: qsTr("IPv6")
                value: root.activeInterface
                    ? NetworkInterfaces.formatAddresses(root.activeInterface.ipv6)
                    : ""
            }

            InfoRow {
                Layout.fillWidth: true
                visible: !!root.activeInterface
                iconName: "dialog-information-symbolic"
                label: qsTr("Link state / MTU")
                value: root.activeInterface
                    ? `${root.activeInterface.state} · ${root.activeInterface.mtu}`
                    : ""
            }
        }

        Repeater {
            model: connectedNetworks

            delegate: NetworkRow {
                required property var modelData
                Layout.fillWidth: true
                network: modelData
                interactionState: root.interactionState
                inheritedDetailed: connectedSection.detailed
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
        }

        Text {
            visible: connectedNetworks.length === 0 && !NetworkService.hasWiredConnection
            text: qsTr("No current connection")
            color: Config.styling.text2
            font.pixelSize: 12
        }

        NetworkMetricsRow {
            Layout.fillWidth: true
            visible: connectedNetworks.length > 0 || NetworkService.hasWiredConnection
            downloadRate: Stats.rxBytesPerSecond
            uploadRate: Stats.txBytesPerSecond
            showSignal: connectedNetworks.length > 0 && !NetworkService.hasWiredConnection
            signalStrength: connectedNetworks.length > 0
                ? Number(connectedNetworks[0].signalStrength || 0)
                : 0
        }
    }

    DashboardSection {
        id: availableSection
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 120
        Layout.preferredHeight: 0
        title: qsTr("Available networks")
        headerAccessory: Component {
            DashboardIconButton {
                enabled: NetworkService.wifiEnabled
                iconName: "view-refresh-symbolic"
                fallbackIconName: "view-refresh-symbolic"
                accessibleName: qsTr("Rescan Wi-Fi networks")
                onClicked: NetworkService.rescan()
            }
        }

        DashboardScrollArea {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentSpacing: itemSpacing
            tabSwipeTarget: root.tabSwipeTarget

            Repeater {
                model: disconnectedNetworks

                delegate: NetworkRow {
                    required property var modelData
                    Layout.fillWidth: true
                    network: modelData
                    interactionState: root.interactionState
                    inheritedDetailed: availableSection.detailed
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
            }

            Text {
                visible: NetworkService.networks.length === 0
                text: qsTr("No Wi-Fi networks found")
                color: Config.styling.text2
                font.pixelSize: 12
            }
        }
    }
}
