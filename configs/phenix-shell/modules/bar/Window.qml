import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.utils

PanelWindow {
    id: root
    property var shellScreenState

    anchors {
        top: true
        right: true
        left: true
    }
    implicitHeight: Math.round(Pixels.mm(10, screen)) | 1

    Component.onCompleted: {
        if (WlrLayershell)
            WlrLayershell.layer = WlrLayer.Top;
    }
    Bar {
        screenState: root.shellScreenState
    }
}
