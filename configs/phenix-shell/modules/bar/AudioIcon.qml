import QtQuick
import Quickshell
import qs.services

StatusIcon {
    id: root

    label: qsTr("Audio")
    iconName: AudioService.outputIconName
    iconColor: AudioService.outputIconColor

    tabName: "audio"
}
