import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

import qs.services
import qs.components

Item {
    id: root

    required property var stream
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

    readonly property var outputEntries: root.sinks || []

    implicitWidth: root.contentWidth
    implicitHeight: rowContent.implicitHeight + root.verticalPadding * 2

    Rectangle {
        anchors.fill: parent
        color: Config.styling.bg2
        opacity: 0.5
    }

    ColumnLayout {
        id: rowContent
        anchors.fill: parent
        anchors.margins: root.horizontalPadding
        spacing: root.itemSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: root.iconTextGap

            Icon {
                Layout.preferredWidth: root.itemIconSize
                Layout.preferredHeight: root.itemIconSize
                iconName: root.stream.iconName
                color: root.stream.iconColor
                implicitSize: root.itemIconSize
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: root.stream.name
                    color: Config.styling.text0
                    font.pixelSize: root.itemTextSize
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.stream.defaultTarget ? "Default output" : (root.stream.targetName || "No output")
                    color: Config.styling.text2
                    font.pixelSize: root.itemSubtextSize
                    elide: Text.ElideRight
                }
            }
        }

        VolumeSliderRow {
            Layout.fillWidth: true
            entry: root.stream
            sliderHeight: root.sliderHeight
            sliderWidth: root.sliderWidth
            iconSlotWidth: root.iconSlotWidth
            iconTextGap: root.iconTextGap
            iconSize: root.iconSize
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: root.itemSpacing

            Text {
                text: "Output:"
                color: Config.styling.text1
                font.pixelSize: 12
            }

            ComboBox {
                id: outputSelector
                Layout.fillWidth: true
                Layout.preferredHeight: root.actionHeight
                implicitHeight: root.actionHeight
                model: outputSelector.displayModel
                currentIndex: findCurrentIndex()

                property var displayModel: root.outputEntries.map(sink => ({
                    id: sink.id,
                    label: sink.name,
                    isDefault: sink.default
                }))

                textRole: ""
                displayText: outputSelector.displayModel.length > 0 && outputSelector.currentIndex >= 0
                    ? outputSelector.displayModel[outputSelector.currentIndex].label
                    : "Select output"

                contentItem: Text {
                    leftPadding: root.horizontalPadding
                    rightPadding: root.horizontalPadding
                    verticalAlignment: Text.AlignVCenter
                    text: outputSelector.displayText
                    color: Config.styling.text0
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                delegate: ItemDelegate {
                    required property int index
                    width: outputSelector.width
                    highlighted: outputSelector.highlightedIndex === index

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: root.horizontalPadding
                        anchors.rightMargin: root.horizontalPadding
                        spacing: root.iconTextGap

                        Icon {
                            Layout.preferredWidth: root.iconSize
                            Layout.preferredHeight: root.iconSize
                            iconName: outputSelector.displayModel[index].isDefault ? "audio-card-symbolic" : "audio-speakers-symbolic"
                            color: outputSelector.displayModel[index].isDefault ? Config.colors.blue : Config.styling.text0
                            implicitSize: root.iconSize
                        }

                        Text {
                            Layout.fillWidth: true
                            text: outputSelector.displayModel[index].label
                            color: Config.styling.text0
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: outputSelector.displayModel[index].isDefault
                            text: "Default"
                            color: Config.colors.blue
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }

                    background: Rectangle {
                        color: outputSelector.highlightedIndex === index ? Config.styling.bg4 : "transparent"
                    }
                }

                background: Rectangle {
                    color: Config.styling.bg3
                    radius: Config.styling.radius
                    border.width: 1
                    border.color: Config.styling.bg5
                }

                function findCurrentIndex() {
                    const targetId = root.stream.targetId;
                    if (!targetId) return 0;
                    for (let i = 0; i < outputSelector.displayModel.length; i++) {
                        if (outputSelector.displayModel[i].id === targetId)
                            return i;
                    }
                    return 0;
                }

                onActivated: function(index) {
                    if (index >= 0 && index < outputSelector.displayModel.length)
                        AudioService.moveStreamTo(root.stream.id, outputSelector.displayModel[index].id);
                }
            }
        }
    }
}
