import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

PanelWindow {
    id: root

    color: Config.styling.bg0
    focusable: false
    visible: true

    property alias wallpaperPath: wallpaperItem.source

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Item {
        anchors.fill: parent
        Image {
            id: wallpaperItem
            anchors.fill: parent
            source: Config.wallpaper
            sourceSize.width: parent.width
            sourceSize.height: parent.height
            visible: !!Config.wallpaper
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
        }
    }

    Component.onCompleted: {
        if (WlrLayershell) {
            WlrLayershell.layer = WlrLayer.Background;
            WlrLayershell.keyboardFocus = WlrKeyboardFocus.None;
        }
    }
}
