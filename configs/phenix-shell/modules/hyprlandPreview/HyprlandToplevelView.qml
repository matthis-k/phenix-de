import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.services
import qs.components

Item {
    id: root

    required property HyprlandToplevel toplevel
    property bool captureActive: true
    property real screenFraction: 0.3

    readonly property real screenWidth: screen.width
    readonly property real screenHeight: screen.height
    readonly property real maxViewWidth: screenWidth * screenFraction
    readonly property real maxViewHeight: screenHeight * screenFraction
    readonly property bool hasPreviewContent: screencopyView.hasContent

    implicitWidth: (screencopyView.implicitWidth || maxViewWidth)
    implicitHeight: (screencopyView.implicitHeight || maxViewHeight) + header.height

    Item {
        id: header
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: screencopyView.width
        height: 32

        Icon {
            id: appIcon
            property DesktopEntry entry: {
                DesktopEntries.applications?.values;
                return DesktopEntries.heuristicLookup(root.toplevel?.wayland?.appId);
            }
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: height
            source: Quickshell.iconPath(entry?.icon || "dialog-warning", "dialog-warning")
            mipmap: false
            scale: Config.styling.statusIconScaler
        }

        Text {
            text: root.toplevel.title || root.toplevel?.wayland.title
            color: Config.styling.text0
            font.pixelSize: 14
            font.bold: true
            elide: Text.ElideRight
            maximumLineCount: 1
            anchors {
                left: appIcon.right
                leftMargin: Config.spacing.xxs
                right: closeBtn.left
                verticalCenter: parent.verticalCenter
            }
        }

        InteractiveButton {
            id: closeBtn
            width: 32
            height: 32
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            scaleTarget: null
            scaleIcon: true
            iconScaleTarget: closeIcon
            hoveredScale: 1.0
            unhoveredScale: 0.8

            onClicked: {
                root.toplevel?.wayland?.close();
                ShellActions.addHyprlandPreviewHover(screen, -1);
                const previewWindow = ShellState.getScreenByName(screen.name);
                if (previewWindow && previewWindow.hyprlandPreview)
                    previewWindow.hyprlandPreview.clearPreview();
            }

            contentItem: Icon {
                id: closeIcon
                anchors.fill: parent
                iconName: "window-close"
                fallbackIconName: "window-close"
                color: Config.styling.close || Config.colors.red
            }
        }
    }

    ScreencopyView {
        id: screencopyView
        captureSource: root.captureActive ? root.toplevel?.wayland : null
        constraintSize: Qt.size(root.maxViewWidth, root.maxViewHeight)
        width: implicitWidth || root.maxViewWidth
        height: implicitHeight || root.maxViewHeight
        anchors.top: header.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        live: root.captureActive
        paintCursor: false
        visible: root.hasPreviewContent

        TapHandler {
            onSingleTapped: {
                root.toplevel?.wayland?.activate();
                ShellActions.addHyprlandPreviewHover(screen, -1);
                const previewWindow = ShellState.getScreenByName(screen.name);
                if (previewWindow && previewWindow.hyprlandPreview)
                    previewWindow.hyprlandPreview.clearPreview();
            }
        }
    }

    Item {
        anchors.fill: screencopyView
        visible: !root.hasPreviewContent

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Config.spacing.xs

            Icon {
                Layout.alignment: Qt.AlignHCenter
                implicitSize: 48
                source: appIcon.source
                mipmap: false
            }

            Text {
                Layout.maximumWidth: root.maxViewWidth - Config.spacing.md
                text: root.toplevel?.title || root.toplevel?.wayland?.title || qsTr("Window preview unavailable")
                color: Config.styling.text0
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
