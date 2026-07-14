import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.animations as Animations
import qs.services
import qs.components

PanelWindow {
    id: root
    property var shellScreenState
    readonly property bool dashboardVisible: !!shellScreenState && shellScreenState.dashboardPhase !== "closed"
    property real tabSwipeAccumulator: 0
    readonly property real tabSwipeThreshold: Config.spacing.xxl
    focusable: true

    function resetTabSwipe() {
        tabSwipeAccumulator = 0;
    }

    function queueTabSwipe(delta) {
        if (!shellScreenState || shellScreenState.dashboardPhase !== "open")
            return;

        tabSwipeAccumulator += delta;

        if (Math.abs(tabSwipeAccumulator) < tabSwipeThreshold)
            return;

        shellScreenState.stepDashboardTab(tabSwipeAccumulator < 0 ? 1 : -1);
        resetTabSwipe();
    }

    function queueTabSwipeFromWheelEvent(event) {
        const delta = event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.angleDelta.x / 4;
        if (delta === 0)
            return false;

        queueTabSwipe(delta);
        return true;
    }

    function syncCurrentTab() {
        if (!shellScreenState)
            return;

        const targetIndex = shellScreenState.tabIndex(shellScreenState.activeTab);
        if (selection.currentIndex !== targetIndex)
            selection.setCurrentIndex(targetIndex);
    }

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }
    Component.onCompleted: {
        if (WlrLayershell)
            WlrLayershell.layer = WlrLayer.Overlay;
    }

    visible: root.dashboardVisible
    color: "transparent"

    readonly property real targetHeight: screen ? screen.height : 720
    readonly property real targetWidth: shellScreenState ? shellScreenState.dashboardWidth : 392
    readonly property real panelProgress: {
        if (!shellScreenState) return 0;
        switch (shellScreenState.dashboardPhase) {
            case "opening":
            case "open":
            case "switching":
                return 1;
            default:
                return 0;
        }
    }
    readonly property real backdropOpacity: root.panelProgress * 0.22

    MouseArea {
        width: panelCard.x
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
        enabled: root.visible && !!root.shellScreenState && root.shellScreenState.dashboardPhase === "open"
        onClicked: {
            if (!(selection.currentItem?.popupOpen))
                root.shellScreenState?.closeDashboard();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Config.colorWithOpacity(Config.styling.bg0, 1)
        opacity: root.backdropOpacity

        Animations.PanelBehavior on opacity {
        }
    }

    Item {
        id: panelCard
        z: 1
        visible: root.dashboardVisible
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: root.targetWidth
        height: root.targetHeight
        clip: true

        Item {
            id: contentLayer
            width: parent.width
            height: parent.height
            x: (1 - root.panelProgress) * Config.spacing.lg
            opacity: root.panelProgress

            Animations.PanelBehavior on x {
            }

            Animations.PanelBehavior on opacity {
            }

            Rectangle {
                anchors.fill: parent
                color: Config.styling.bg0
                radius: Config.styling.radius
            }

            SwipeView {
                id: selection
                anchors.fill: parent
                interactive: false
                clip: true
                Component.onCompleted: root.syncCurrentTab()

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    orientation: Qt.Horizontal
                    blocking: false

                    onActiveChanged: {
                        if (!active)
                            root.resetTabSwipe();
                    }

                    onWheel: event => root.queueTabSwipeFromWheelEvent(event)
                }

                // Page order must match ShellState.dashboardTabs and bar dashboard icon order.
                Overview {
                    screenState: root.shellScreenState
                    tabSwipeTarget: root
                }
                Audio {
                    tabSwipeTarget: root
                }
                Notifications {
                    tabSwipeTarget: root
                }
                Bluetooth {
                    tabSwipeTarget: root
                }
                Network {
                    tabSwipeTarget: root
                }
                Energy {
                    tabSwipeTarget: root
                }
                SystemStats {
                    tabSwipeTarget: root
                }
            }
        }

        Connections {
            target: root.shellScreenState
            enabled: root.shellScreenState !== null

            function onActiveTabChanged() {
                root.resetTabSwipe();
                root.syncCurrentTab();
            }

            function onDashboardPhaseChanged() {
                if (root.shellScreenState.dashboardPhase !== "open")
                    root.resetTabSwipe();
            }
        }
    }

    Item {
        focus: visible

        Keys.onEscapePressed: root.shellScreenState?.closeDashboard()
    }
}
