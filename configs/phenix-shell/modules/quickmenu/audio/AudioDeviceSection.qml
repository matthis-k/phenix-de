import QtQuick
import QtQuick.Layouts

import qs.services
import qs.components

DashboardSection {
    id: root

    property var entries: []
    property bool isInput: false
    property string emptyText: qsTr("No devices found")
    property int contentWidth: 360

    showDetailToggle: true
    Layout.fillWidth: true

    Repeater {
        model: root.entries

        delegate: AudioDeviceRow {
            required property var modelData
            Layout.fillWidth: true
            entry: modelData
            isInput: root.isInput
            contentWidth: root.contentWidth
        }
    }

    Text {
        visible: root.entries.length === 0
        text: root.emptyText
        color: Config.styling.text2
        font.pixelSize: 12
    }
}
