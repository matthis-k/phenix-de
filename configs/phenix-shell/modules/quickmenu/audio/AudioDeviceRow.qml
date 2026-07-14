import QtQuick
import QtQuick.Layouts

import qs.services
import qs.components

Item {
    id: root

    required property var entry
    property bool isInput: false
    property var sinks: []
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

    readonly property var node: root.entry ? root.entry.raw : null
    readonly property var streams: root.entry ? root.entry.streams || [] : []

    implicitWidth: root.contentWidth
    implicitHeight: content.implicitHeight

    ColumnLayout {
        id: content
        anchors.fill: parent
        spacing: root.itemSpacing

        AudioDeviceCard {
            Layout.fillWidth: true
            title: root.entry.name
            iconName: root.entry.iconName
            iconColor: root.entry.iconColor
            valueText: `${root.entry.volume}%`
            from: 0
            to: 100
            value: root.entry.volume
            stepSize: 1
            iconEnabled: !!root.node
            sliderEnabled: !!root.entry && !root.entry.muted
            accentColor: root.entry.muted ? Config.styling.critical : Config.colors.blue
            showDefaultBadge: root.entry.default
            onIconClicked: AudioService.toggleMuteById(root.entry.id)
            onValueModified: value => AudioService.setVolumeById(root.entry.id, value)
        }

        Repeater {
            visible: !root.isInput
            model: root.isInput ? [] : root.streams

            delegate: AudioStreamRow {
                required property var modelData
                Layout.fillWidth: true
                stream: modelData
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
    }
}
