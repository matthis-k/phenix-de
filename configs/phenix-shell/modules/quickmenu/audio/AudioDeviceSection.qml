import QtQuick
import QtQuick.Layouts

import qs.services
import qs.components

DashboardSection {
    id: root

    property var entries: []
    property var sinks: []
    property bool isInput: false
    property string emptyText: "No devices found"
    property var tabSwipeTarget: null
    property int contentWidth: 360
    property int itemSpacing: 3
    property int actionHeight: 28
    property int iconSlotWidth: 28
    property int iconSize: 20
    property int itemIconSize: 22
    property int itemTextSize: 14
    property int itemSubtextSize: 12
    property int iconTextGap: 10
    property int horizontalPadding: 8
    property int verticalPadding: 4
    property int sliderHeight: 24
    property int sliderWidth: 100

    Layout.fillWidth: true
    Layout.fillHeight: true

    DashboardScrollArea {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentSpacing: root.itemSpacing
        tabSwipeTarget: root.tabSwipeTarget

        Repeater {
            model: root.entries

            delegate: AudioDeviceRow {
                required property var modelData
                Layout.fillWidth: true
                entry: modelData
                isInput: root.isInput
                sinks: root.sinks
                contentWidth: root.contentWidth
                itemSpacing: root.itemSpacing
                actionHeight: root.actionHeight
                iconSlotWidth: root.iconSlotWidth
                iconSize: root.iconSize
                itemIconSize: root.itemIconSize
                itemTextSize: root.itemTextSize
                itemSubtextSize: root.itemSubtextSize
                iconTextGap: root.iconTextGap
                horizontalPadding: root.horizontalPadding
                verticalPadding: root.verticalPadding
                sliderHeight: root.sliderHeight
                sliderWidth: root.sliderWidth
            }
        }

        Text {
            visible: root.entries.length === 0
            text: root.emptyText
            color: Config.styling.text2
            font.pixelSize: 12
        }
    }
}
