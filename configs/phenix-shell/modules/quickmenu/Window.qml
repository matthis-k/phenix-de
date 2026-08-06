import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import qs.animations as Animations
import qs.services
import qs.components

PanelWindow {
    id: root

    property var shellScreenState
    readonly property string presentationMode: DashboardPresentation.mode
    readonly property bool detailed: DashboardPresentation.detailed
    readonly property var dashboardTabs: DashboardPresentation.tabOrder
    readonly property bool dashboardVisible: !!shellScreenState
        && shellScreenState.dashboardPhase !== "closed"
    property real tabSwipeAccumulator: 0
    readonly property real tabSwipeThreshold: Config.spacing.xxl

    focusable: true

    function setPresentationMode(mode) {
        DashboardPresentation.setMode(mode);
    }

    function togglePresentationMode() {
        DashboardPresentation.toggle();
    }

    function tabIndex(tabName) {
        const index = root.dashboardTabs.indexOf(String(tabName || ""));
        return index >= 0 ? index : root.dashboardTabs.indexOf("overview");
    }

    function stepDashboardTab(offset) {
        if (!root.shellScreenState || !root.shellScreenState.dashboardOpen)
            return false;
        const currentIndex = root.tabIndex(root.shellScreenState.activeTab);
        const nextTab = root.dashboardTabs[currentIndex + offset];
        if (!nextTab)
            return false;
        root.shellScreenState.openDashboard(nextTab);
        return true;
    }

    function resetTabSwipe() {
        tabSwipeAccumulator = 0;
    }

    function queueTabSwipe(delta) {
        if (!shellScreenState || shellScreenState.dashboardPhase !== "open")
            return;

        tabSwipeAccumulator += delta;
        if (Math.abs(tabSwipeAccumulator) < tabSwipeThreshold)
            return;

        root.stepDashboardTab(tabSwipeAccumulator < 0 ? 1 : -1);
        resetTabSwipe();
    }

    function queueTabSwipeFromWheelEvent(event) {
        const delta = event.pixelDelta.x !== 0
            ? event.pixelDelta.x
            : event.angleDelta.x / 4;
        if (delta === 0)
            return false;

        queueTabSwipe(delta);
        return true;
    }

    function positionTabInstantly(targetIndex) {
        const contentView = selection.contentItem;
        const previousMoveDuration = contentView
            && contentView.highlightMoveDuration !== undefined
            ? contentView.highlightMoveDuration
            : undefined;
        const previousResizeDuration = contentView
            && contentView.highlightResizeDuration !== undefined
            ? contentView.highlightResizeDuration
            : undefined;

        if (previousMoveDuration !== undefined)
            contentView.highlightMoveDuration = 0;
        if (previousResizeDuration !== undefined)
            contentView.highlightResizeDuration = 0;

        selection.setCurrentIndex(targetIndex);
        if (contentView && contentView.positionViewAtIndex)
            contentView.positionViewAtIndex(targetIndex, ListView.Beginning);
        if (contentView
                && contentView.contentX !== undefined
                && selection.width > 0)
            contentView.contentX = targetIndex * selection.width;

        Qt.callLater(function() {
            if (!contentView)
                return;
            if (previousMoveDuration !== undefined)
                contentView.highlightMoveDuration = previousMoveDuration;
            if (previousResizeDuration !== undefined)
                contentView.highlightResizeDuration = previousResizeDuration;
        });
    }

    function syncCurrentTab(animate) {
        if (!shellScreenState)
            return;

        const targetIndex = root.tabIndex(shellScreenState.activeTab);
        const contentView = selection.contentItem;
        const expectedX = targetIndex * selection.width;
        const visuallyAligned = !contentView
            || contentView.contentX === undefined
            || Math.abs(contentView.contentX - expectedX) < 0.5;
        if (selection.currentIndex === targetIndex && visuallyAligned)
            return;

        if (animate === true) {
            selection.setCurrentIndex(targetIndex);
            return;
        }

        root.positionTabInstantly(targetIndex);
    }

    function componentForPage(pageId) {
        switch (String(pageId || "")) {
        case "overview":
            return overviewPageComponent;
        case "audio":
            return audioPageComponent;
        case "notifications":
            return notificationsPageComponent;
        case "bluetooth":
            return bluetoothPageComponent;
        case "wifi":
            return networkPageComponent;
        case "energy":
            return energyPageComponent;
        case "stats":
            return statsPageComponent;
        default:
            return null;
        }
    }

    function configureLoadedPage(loader) {
        if (!loader || !loader.item)
            return;

        if (loader.item.screenState !== undefined)
            loader.item.screenState = root.shellScreenState;
        if (loader.item.tabSwipeTarget !== undefined)
            loader.item.tabSwipeTarget = root;
        if (loader.item.modeController !== undefined)
            loader.item.modeController = root;
        if (loader.item.globalPresentationMode !== undefined)
            loader.item.globalPresentationMode = Qt.binding(() => root.presentationMode);
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
    mask: Region {
        item: inputSurface
    }

    readonly property real targetHeight: screen ? screen.height : 720
    readonly property real targetWidth: shellScreenState ? shellScreenState.dashboardWidth : 392
    readonly property real panelProgress: {
        if (!shellScreenState)
            return 0;
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

    Component {
        id: overviewPageComponent
        Overview {}
    }

    Component {
        id: audioPageComponent
        Audio {}
    }

    Component {
        id: notificationsPageComponent
        Notifications {}
    }

    Component {
        id: bluetoothPageComponent
        Bluetooth {}
    }

    Component {
        id: networkPageComponent
        Network {}
    }

    Component {
        id: energyPageComponent
        Energy {}
    }

    Component {
        id: statsPageComponent
        SystemStats {}
    }

    Shortcut {
        sequence: "Ctrl+D"
        enabled: root.dashboardVisible
        onActivated: root.togglePresentationMode()
    }

    Shortcut {
        sequence: "F2"
        enabled: root.dashboardVisible
        onActivated: root.togglePresentationMode()
    }

    Shortcut {
        sequence: "Alt+H"
        enabled: root.dashboardVisible && !!root.shellScreenState
        onActivated: root.stepDashboardTab(-1)
    }

    Shortcut {
        sequence: "Alt+L"
        enabled: root.dashboardVisible && !!root.shellScreenState
        onActivated: root.stepDashboardTab(1)
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.dashboardVisible && !!root.shellScreenState
        onActivated: root.shellScreenState.closeDashboard()
    }

    Item {
        id: inputSurface

        anchors.fill: parent
    }

    MouseArea {
        id: inputShield

        anchors.fill: inputSurface
        z: 0.5
        enabled: root.dashboardVisible
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        preventStealing: true
        propagateComposedEvents: false
        scrollGestureEnabled: true
        onPressed: mouse => mouse.accepted = true
        onReleased: mouse => mouse.accepted = true
        onPositionChanged: mouse => mouse.accepted = true
        onWheel: wheel => wheel.accepted = true
        onDoubleClicked: mouse => mouse.accepted = true
        onPressAndHold: mouse => mouse.accepted = true
        onClicked: mouse => {
            mouse.accepted = true;
            if (mouse.x >= panelCard.x
                    || !root.shellScreenState
                    || root.shellScreenState.dashboardPhase !== "open")
                return;
            if (!(selection.currentItem?.item?.popupOpen || selection.currentItem?.popupOpen))
                root.shellScreenState.closeDashboard();
        }
    }

    Rectangle {
        anchors.fill: parent
        z: 0
        color: Config.colorWithOpacity(Config.styling.bg0, 1)
        opacity: root.backdropOpacity

        Animations.PanelBehavior on opacity {}
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

            Animations.PanelBehavior on x {}
            Animations.PanelBehavior on opacity {}

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
                Component.onCompleted: Qt.callLater(() => root.syncCurrentTab(false))

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    orientation: Qt.Horizontal
                    blocking: true

                    onActiveChanged: {
                        if (!active)
                            root.resetTabSwipe();
                    }

                    onWheel: event => {
                        event.accepted = root.queueTabSwipeFromWheelEvent(event);
                    }
                }

                Repeater {
                    model: root.dashboardTabs

                    Loader {
                        id: pageLoader
                        required property string modelData
                        readonly property string pageId: modelData

                        sourceComponent: root.componentForPage(pageId)
                        onLoaded: root.configureLoadedPage(pageLoader)
                    }
                }
            }
        }

        Connections {
            target: root.shellScreenState
            enabled: root.shellScreenState !== null

            function onActiveTabChanged() {
                const animate = root.shellScreenState.dashboardPhase === "open";
                root.resetTabSwipe();
                root.syncCurrentTab(animate);
            }

            function onDashboardPhaseChanged() {
                if (root.shellScreenState.dashboardPhase !== "open")
                    root.resetTabSwipe();
                if (root.shellScreenState.dashboardPhase === "opening")
                    Qt.callLater(() => root.syncCurrentTab(false));
            }
        }
    }
}
