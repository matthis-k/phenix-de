import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.animations as Animations
import qs.utils
import qs.components
import qs.services

PanelWindow {
    id: root
    property HyprlandToplevel previewToplevel: null
    property bool previewActive: false
    property bool previewShown: false
    property bool previewContentFallback: false
    property bool animateReveal: true
    property int previewGeneration: 0
    property real revealProgress: 0
    property real topInset: 0
    property real anchorX: (screen ? screen.width : 0) / 2
    readonly property bool previewReady: previewLoader.status === Loader.Ready && !!previewLoader.item
    readonly property bool previewHasContent: previewReady && previewLoader.item.hasPreviewContent
    readonly property bool previewCanReveal: previewReady && (previewHasContent || previewContentFallback)
    readonly property real previewWidth: previewReady ? previewLoader.item.implicitWidth + Config.spacing.md : 1
    readonly property real previewHeight: previewReady ? previewLoader.item.implicitHeight + Config.spacing.md : 1

    function screenOriginX() {
        return screen && typeof screen.x === "number" ? screen.x : 0;
    }

    function screenLocalX(globalX) {
        return globalX - screenOriginX();
    }

    function clampedCardX() {
        const centeredLeft = anchorX - previewWidth / 2;
        const maxLeft = Math.max(0, (screen ? screen.width : previewWidth) - previewWidth);
        return Math.min(Math.max(centeredLeft, 0), maxLeft);
    }

    function showPreviewAtGlobal(toplevel, sourceGlobalX) {
        showPreview(toplevel, screenLocalX(sourceGlobalX));
    }

    function showPreview(toplevel, sourceCenterX) {
        if (!toplevel)
            return;

        clearAnimationTimer.stop();
        contentFallbackTimer.stop();
        const generation = ++previewGeneration;
        animateReveal = false;
        revealProgress = 0;
        if (Number.isFinite(sourceCenterX))
            anchorX = sourceCenterX;
        previewActive = false;
        previewToplevel = toplevel;
        previewShown = false;
        previewContentFallback = false;
        animateReveal = true;
        Qt.callLater(function() {
            if (root.previewGeneration === generation && root.previewToplevel === toplevel) {
                root.previewActive = true;
                contentFallbackTimer.restart();
            }
            root.revealIfReady(generation, toplevel);
        });
    }

    function revealIfReady(generation, toplevel) {
        if (previewGeneration !== generation || previewToplevel !== toplevel || !previewCanReveal)
            return;

        contentFallbackTimer.stop();
        previewShown = true;
        revealProgress = 1;
    }

    function clearPreview() {
        if (!previewToplevel)
            return;

        previewShown = false;
        previewContentFallback = false;
        revealProgress = 0;
        if (Config.motion.medium <= 0)
            finishClearPreview();
        else
            clearAnimationTimer.restart();
    }

    function finishClearPreview() {
        contentFallbackTimer.stop();
        previewActive = false;
        previewToplevel = null;
    }

    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        top: root.topInset
    }
    implicitWidth: screen ? screen.width : previewWidth
    implicitHeight: previewHeight

    visible: root.revealProgress > 0 || root.previewShown
    color: "transparent"
    mask: Region {
        item: previewCard
    }

    onPreviewReadyChanged: {
        if (previewReady) {
            if (!previewHasContent)
                contentFallbackTimer.restart();
            revealIfReady(previewGeneration, previewToplevel);
        }
    }

    onPreviewHasContentChanged: {
        if (previewHasContent)
            revealIfReady(previewGeneration, previewToplevel);
    }

    Animations.PanelBehavior on revealProgress {
        enabled: root.animateReveal
    }

    Component.onCompleted: {
        if (WlrLayershell) {
            WlrLayershell.layer = WlrLayer.Overlay;
            WlrLayershell.exclusionMode = ExclusionMode.Ignore;
        }
    }

    Item {
        id: revealFrame
        anchors.fill: parent
        clip: true

        Item {
            id: previewCard
            width: root.previewWidth
            height: parent.height
            x: root.clampedCardX()
            y: -height * (1 - root.revealProgress)

            Rectangle {
                anchors.fill: parent
                color: Config.styling.bg0
                radius: Config.styling.radius
            }

            Item {
                anchors.fill: parent
                clip: true

                Loader {
                    id: previewLoader
                    anchors.fill: parent
                    active: root.previewActive
                    sourceComponent: previewFactory
                }
            }
        }
    }

    Component {
        id: previewFactory

        HyprlandToplevelView {
            toplevel: root.previewToplevel
            captureActive: root.previewActive
        }
    }

    property int externalHovers: 0
    readonly property bool deferredClose: !(hoverHandler.hovered || externalHovers > 0)
    onDeferredCloseChanged: deferredClose ? closeTimer.start() : closeTimer.stop()

    HoverHandler {
        id: hoverHandler
        target: previewCard
    }

    Timer {
        id: closeTimer
        interval: 300
        onTriggered: root.clearPreview()
    }

    Timer {
        id: contentFallbackTimer
        interval: 250
        onTriggered: {
            root.previewContentFallback = true;
            root.revealIfReady(root.previewGeneration, root.previewToplevel);
        }
    }

    Timer {
        id: clearAnimationTimer
        interval: Config.motion.medium
        onTriggered: root.finishClearPreview()
    }
}
