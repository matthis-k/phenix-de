import QtQuick

import qs.services
import qs.components

Item {
    id: root

    required property var entry
    property bool isInput: false
    property int sliderHeight: 24
    property int sliderWidth: 100
    property int iconSlotWidth: 28
    property int iconTextGap: 10
    property int iconSize: 20

    readonly property int volume: root.entry ? root.entry.volume : 0

    implicitWidth: root.sliderWidth + root.iconSlotWidth + root.iconTextGap + 42
    implicitHeight: root.sliderHeight

    AudioLevelSlider {
        anchors.fill: parent
        iconName: root.entry ? root.entry.iconName : "audio-volume-muted-symbolic"
        iconColor: root.entry && root.entry.muted ? Config.styling.critical : Config.styling.text0
        valueText: `${root.volume}%`
        from: 0
        to: 100
        value: root.volume
        stepSize: 1
        enabled: !!root.entry
        accentColor: root.entry && root.entry.muted ? Config.styling.critical : Config.colors.blue
        iconSize: root.iconSize
        onIconClicked: AudioService.toggleMuteById(root.entry.id)
        onValueModified: value => AudioService.setVolumeById(root.entry.id, value)
    }
}
