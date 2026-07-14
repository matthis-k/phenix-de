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

    spacing: 0

    DashboardSection {
        Layout.fillWidth: true
        title: connectedNetworks.length === 1 ? "Connected network" : "Connected networks"

        Repeater {
            model: connectedNetworks

            delegate: NetworkRow {
                required property var modelData
                Layout.fillWidth: true
                network: modelData
                interactionState: root.interactionState
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
            visible: connectedNetworks.length === 0
            text: "No connected Wi-Fi networks"
            color: Config.styling.text2
            font.pixelSize: 12
        }
    }

    DashboardSection {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 120
        Layout.preferredHeight: 0
        title: "Available networks"
        headerAccessory: Component {
            DashboardIconButton {
                enabled: NetworkService.wifiEnabled
                iconName: "view-refresh-symbolic"
                fallbackIconName: "view-refresh-symbolic"
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
                text: "No Wi-Fi networks found"
                color: Config.styling.text2
                font.pixelSize: 12
            }
        }
    }
}
