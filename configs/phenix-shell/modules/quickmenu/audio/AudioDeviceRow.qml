import QtQuick
import QtQuick.Layouts

import qs.services
import qs.components

Item {
    id: root

    required property var entry
    property bool isInput: false
    property int contentWidth: 360

    readonly property var node: root.entry ? root.entry.raw : null

    implicitWidth: root.contentWidth
    implicitHeight: deviceCard.implicitHeight

    AudioDeviceCard {
        id: deviceCard
        anchors.fill: parent
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
}
