import QtQuick
import QtQuick.Layouts

import qs.services
import qs.components
import "audio"

DashboardPage {
    id: root

    title: qsTr("Audio")
    scrollable: true

    property string expandedStreamKey: ""

    readonly property int contentWidth: width > 0 ? width : 360
    readonly property int itemSpacing: Config.spacing.xs
    readonly property int actionHeight: 32
    readonly property int iconSlotWidth: 28
    readonly property int iconSize: 20
    readonly property int itemIconSize: 22
    readonly property int itemTextSize: 14
    readonly property int itemSubtextSize: 12
    readonly property int iconTextGap: Config.spacing.sm
    readonly property int horizontalPadding: Config.spacing.xs
    readonly property int verticalPadding: Config.spacing.xs
    readonly property int sliderHeight: 28
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

    readonly property var applicationStreams: {
        const sourceEntries = outputObservation.allEntries;
        const seen = {};
        const result = [];
        sourceEntries.forEach(entry => {
            (entry.streams || []).forEach(stream => {
                const key = String(stream.id || stream.name || "");
                if (seen[key])
                    return;
                seen[key] = true;
                result.push(stream);
            });
        });
        return result;
    }

    AudioDeviceSection {
        id: outputSection
        title: outputSection.detailed ? qsTr("Output devices") : qsTr("Output")
        entries: outputSection.detailed
            ? outputObservation.allEntries
            : outputObservation.visibleEntries
        isInput: false
        emptyText: qsTr("No output devices found")
        contentWidth: root.contentWidth
    }

    AudioDeviceSection {
        id: inputSection
        title: inputSection.detailed ? qsTr("Input devices") : qsTr("Input")
        entries: inputSection.detailed
            ? inputObservation.allEntries
            : inputObservation.visibleEntries
        isInput: true
        emptyText: qsTr("No input devices found")
        contentWidth: root.contentWidth
    }

    DashboardSection {
        Layout.fillWidth: true
        title: qsTr("Application streams")
        visible: root.applicationStreams.length > 0

        Repeater {
            model: root.applicationStreams

            delegate: AudioStreamRow {
                required property var modelData
                Layout.fillWidth: true
                stream: modelData
                sinks: AudioService.outputEntries
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
                forcedDetailed: root.detailed
                localDetailed: root.expandedStreamKey === String(modelData.id || modelData.name || "")
                onToggleDetailsRequested: {
                    const key = String(modelData.id || modelData.name || "");
                    root.expandedStreamKey = root.expandedStreamKey === key ? "" : key;
                }
            }
        }
    }
}
