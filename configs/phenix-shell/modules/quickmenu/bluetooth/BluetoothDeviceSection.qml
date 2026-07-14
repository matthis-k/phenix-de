import QtQuick
import QtQuick.Layouts

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

        Repeater {
            model: root.devices

            delegate: BluetoothDeviceRow {
                required property var modelData
                Layout.fillWidth: true
                device: modelData
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
            visible: root.devices.length === 0
            text: root.emptyText
            color: Config.styling.text2
            font.pixelSize: 12
        }
    }
}
