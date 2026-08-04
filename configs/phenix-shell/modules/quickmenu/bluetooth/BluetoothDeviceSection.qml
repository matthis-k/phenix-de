import QtQuick
import QtQuick.Layouts

import qs.animations as Animations
import qs.services
import qs.components

DashboardSection {
    id: root

    property var devices: []
    property QtObject interactionState: null
    property string emptyText: "No Bluetooth devices"
    property var tabSwipeTarget: null
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
    property bool scroll: false

    showDetailToggle: root.devices.length > 0
    Layout.fillWidth: true

    DashboardScrollArea {
        Layout.fillWidth: true
        Layout.fillHeight: root.scroll
        visible: root.scroll
        contentSpacing: root.itemSpacing
        tabSwipeTarget: root.tabSwipeTarget

        BluetoothDeviceListContent {}
    }

    BluetoothDeviceListContent {
        visible: !root.scroll
    }

    component BluetoothDeviceListContent: ColumnLayout {
        spacing: root.itemSpacing

        Animations.SnapshotTransitionModel {
            id: deviceSnapshot
            items: root.devices
            keyOf: function(device) { return BluetoothService.deviceKey(device); }
            equals: function(previous, next) { return previous === next; }
            estimatedRowHeight: root.rowHeight + root.itemSpacing
            context: ({
                contextKey: "bluetooth:" + root.title,
                reason: "service-update"
            })
        }

        Item {
            id: rows

            Layout.fillWidth: true
            implicitHeight: deviceSnapshot.contentHeight
            height: implicitHeight

            Behavior on implicitHeight {
                enabled: Config.behaviour.animation.enabled
                NumberAnimation {
                    duration: Config.motion.short
                    easing.type: Easing.OutCubic
                }
            }

            Repeater {
                model: deviceSnapshot.model

                delegate: Animations.TransitionListRow {
                    id: animatedRow

                    coordinator: deviceSnapshot.coordinator
                    animationMode: deviceSnapshot.animationMode
                    spacing: root.itemSpacing
                    estimatedRowHeight: root.rowHeight
                    width: rows.width

                    BluetoothDeviceRow {
                        width: parent.width
                        device: animatedRow.payload
                        interactionState: root.interactionState
                        inheritedDetailed: root.detailed
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
            }
        }

        Text {
            visible: !deviceSnapshot.hasActiveItems
            text: root.emptyText
            color: Config.styling.text2
            font.pixelSize: 12
        }
    }
}
