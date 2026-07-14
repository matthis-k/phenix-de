import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.animations as Animations
import qs.services
import qs.components

Item {
    id: root
    property bool onlyForScreen: true
    property HyprlandMonitor monitor: onlyForScreen ? Hyprland.monitorFor(screen) : null

    implicitHeight: parent.height
    implicitWidth: row.implicitWidth

    Animations.LayoutBehavior on implicitWidth {
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: Config.spacing.xxs

        Repeater {
            id: workspaceRepeater

            model: HyprlandService.workspacesForScreen(screen, HyprlandService.revision)
            delegate: WorkspaceOverview {}
        }
    }

    component WorkspaceOverview: Item {
        required property var modelData
        property var workspace: modelData
        property bool appeared: false

        implicitHeight: root.height
        implicitWidth: ws.implicitWidth + toplevels.implicitWidth
        opacity: appeared ? 1 : 0

        Animations.LayoutBehavior on implicitWidth {
        }

        Animations.ShiftBehavior on x {
        }

        Animations.RevealBehavior on opacity {
        }

        Component.onCompleted: appeared = true

        ActionButton {
            id: ws
            implicitHeight: root.height
            implicitWidth: root.height
            fillOnHover: false
            indicatorOnHover: false
            highlightThickness: 0
            scaleText: true
            textScaleTarget: wsLabel
            hoveredScale: 1.0
            unhoveredScale: 0.92
            baseScale: HyprlandService.focusedWorkspace?.id === workspace?.id ? 1.0 : 0.92

            onClicked: {
                if (workspace && HyprlandService.focusedWorkspace?.id !== workspace?.id)
                    HyprlandService.activateWorkspace(workspace.id);
            }
        }

        Text {
            id: wsLabel
            text: workspace.name
            anchors.centerIn: ws
            color: (HyprlandService.focusedWorkspace?.id === workspace?.id) ? Config.styling.activeIndicator : Config.styling.text0
            font.pixelSize: parent.height
            font.bold: true

            Animations.ScaleBehavior on scale {
            }

            Animations.StateColorBehavior on color {
            }
        }

        RowLayout {
            id: toplevels
            implicitHeight: root.height
            anchors.left: ws.right
            spacing: 0

            Repeater {
                model: workspace.toplevels

                delegate: TopLevel {}  // modelData auto-assigned to required property
            }
        }
    }

    component TopLevel: ActionButton {
        id: tl
        required property HyprlandToplevel modelData
        property HyprlandToplevel toplevel: modelData
        property bool appeared: false
        property DesktopEntry entry: {
            DesktopEntries.applications?.values;
            return DesktopEntries.heuristicLookup(toplevel.wayland?.appId);
        }
        property string iconSource: Quickshell.iconPath(entry?.icon, "dialog-warning")

        implicitHeight: root.height
        implicitWidth: root.height
        opacity: appeared ? 1 : 0
        active: toplevel.activated && Hyprland.focusedWorkspace?.id === toplevel?.workspace?.id
        highlightSide: ActiveIndicator.Side.Top
        highlightAnimationMode: ActiveIndicator.AnimationMode.GrowAcross
        highlightThickness: Math.max(2, height * 0.1)
        scaleIcon: true
        iconScaleTarget: tlIcon
        hoveredScale: 1.0
        unhoveredScale: active ? 1.0 : 0.92

        Animations.LayoutBehavior on implicitWidth {
        }

        Animations.ShiftBehavior on x {
        }

        Animations.RevealBehavior on opacity {
        }

        Component.onCompleted: appeared = true

        onHoveredChanged: {
            if (hovered) {
                const globalPos = tl.mapToGlobal(Qt.point(tl.width / 2, 0));
                ShellActions.requestHyprlandPreview(screen, toplevel, globalPos.x);
            }
            ShellActions.addHyprlandPreviewHover(screen, hovered ? 1 : -1);
        }

        onClicked: {
            toplevel.wayland?.activate();
        }

        contentItem: Icon {
            id: tlIcon
            anchors.centerIn: parent
            source: iconSource
            implicitSize: parent.height * 0.9

            Animations.ScaleBehavior on scale {
            }
        }

        TapHandler {
            acceptedButtons: Qt.MiddleButton
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: {
                toplevel.wayland?.close();
            }
        }
    }

    Component.onCompleted: {
        HyprlandService.refresh();
    }
}
