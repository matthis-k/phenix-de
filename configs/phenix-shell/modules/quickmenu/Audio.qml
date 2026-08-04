import QtQuick
import QtQuick.Layouts

import qs.services
import qs.components
import "audio"

DashboardPage {
    id: root

    title: "Audio"
    subtitle: root.detailed
        ? qsTr("All PipeWire devices and active streams")
        : qsTr("Primary devices; active and exceptional devices are promoted")
    fillHeight: true

    readonly property int contentWidth: width > 0 ? width : 360
    readonly property int itemSpacing: 3
    readonly property int rowHeight: 40
    readonly property int actionHeight: 28
    readonly property int iconSlotWidth: 28
    readonly property int iconSize: 20
    readonly property int itemIconSize: 22
    readonly property int itemTextSize: 14
    readonly property int itemSubtextSize: 12
    readonly property int iconTextGap: 10
    readonly property int horizontalPadding: 8
    readonly property int verticalPadding: 4
    readonly property int sliderHeight: 24
    readonly property int sliderWidth: 100

    AudioDashboardObservation {
        id: outputObservation
        key: "audio-output"
        presentationMode: root.presentationMode
        entries: AudioService.outputEntries
    }

    AudioDashboardObservation {
        id: inputObservation
        key: "audio-input"
        presentationMode: root.presentationMode
        entries: AudioService.inputEntries
    }

    AudioDeviceSection {
        id: outputSection
        title: outputSection.detailed ? "Output devices" : "Output"
        entries: outputSection.detailed
            ? outputObservation.allEntries
            : outputObservation.visibleEntries
        sinks: AudioService.outputEntries
        emptyText: "No output devices found"
        tabSwipeTarget: root.tabSwipeTarget
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

    AudioDeviceSection {
        id: inputSection
        title: inputSection.detailed ? "Input devices" : "Input"
        entries: inputSection.detailed
            ? inputObservation.allEntries
            : inputObservation.visibleEntries
        sinks: AudioService.outputEntries
        isInput: true
        emptyText: "No input devices found"
        tabSwipeTarget: root.tabSwipeTarget
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
