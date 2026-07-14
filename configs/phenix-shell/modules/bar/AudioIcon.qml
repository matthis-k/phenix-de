import QtQuick
import Quickshell
import qs.services

StatusIcon {
    id: root

    iconName: AudioService.outputIconName
    iconColor: AudioService.outputIconColor

    tabName: "audio"
}