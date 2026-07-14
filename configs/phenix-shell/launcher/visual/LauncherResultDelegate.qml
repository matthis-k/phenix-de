pragma ComponentBehavior: Bound

import QtQuick
import qs.animations
import qs.services
import "../animation" as Animation

Item {
    id: root

    required property string key
    required property var payload
    required property int rank
    required property int zValue
    required property string phase

    property var coordinator: null
    property Component sourceComponent: null
    property int animationMode: TransitionPolicy.Mode.Full
    property int spacing: 0
    property int estimatedRowHeight: 56

    property var controller: null
    property int iconSize: 32
    property bool showSubtitle: true
    property bool showActionHint: true
    property bool showEvidence: false
    readonly property var result: root.payload

    property real reveal: 1
    property real contentOpacity: 1
    property real contentScale: 1
    property bool removing: false
    property bool delayModelRemove: false
    property real fullHeight: Math.max(content.implicitHeight, root.estimatedRowHeight) + root.spacing
    readonly property Item item: content.item

    property Timer removeFallbackTimer: Timer {
        interval: Math.max(1, policy.duration(TransitionPolicy.Kind.ListRemove, root.animationMode) + 80)
        repeat: false
        onTriggered: {
            root.ListView.delayRemove = false;
            Qt.callLater(root.settleListView);
        }
    }

    signal activated(int rank)

    TransitionPolicy {
        id: policy
    }

    width: ListView.view ? ListView.view.width : 0
    height: root.fullHeight * root.reveal
    clip: true
    z: root.zValue
    visible: !!root.sourceComponent || root.removing

    Component.onCompleted: {
        if (root.phase === "entering")
            Qt.callLater(root.startEnterAnimation);
    }

    onPhaseChanged: {
        if (root.phase === "entering") {
            animator.animateIn();
        } else if (root.phase === "leaving") {
            root.removing = true;
            animator.animateOut();
        } else if (root.phase === "live") {
            if (root.removing) {
                root.removing = false;
                root.delayModelRemove = false;
                root.removeFallbackTimer.stop();
                root.ListView.delayRemove = false;
                animator.snapToLive();
            } else {
                animator.snapToLive();
            }
        }
    }

    ListView.onAdd: root.startEnterAnimation()

    ListView.onRemove: {
        if (root.phase === "leaving" || root.reveal <= 0.01) {
            root.ListView.delayRemove = false;
            Qt.callLater(root.settleListView);
            return;
        }
        root.startLeaveAnimation(true);
    }

    function startEnterAnimation() {
        if (root.phase !== "entering") {
            if (!root.removing)
                animator.snapToLive();
            return;
        }

        const dur = policy.duration(TransitionPolicy.Kind.ListInsert, root.animationMode);
        if (dur <= 0) {
            animator.snapToLive();
            return;
        }

        root.reveal = 0;
        root.contentOpacity = 0;
        root.contentScale = 0.96;
        Qt.callLater(function() {
            if (!root || root.removing)
                return;
            animator.animateIn();
        });
    }

    function finishVisualState() {
        root.removing = false;
        root.delayModelRemove = false;
        animator.snapToLive();
    }

    function startLeaveAnimation(delayRemove) {
        root.removing = true;
        root.delayModelRemove = delayRemove;
        if (delayRemove) {
            root.ListView.delayRemove = true;
            removeFallbackTimer.restart();
        } else {
            removeFallbackTimer.stop();
        }

        const dur = policy.duration(TransitionPolicy.Kind.ListRemove, root.animationMode);
        if (dur <= 0) {
            root.finishLeaveAnimation();
            return;
        }

        animator.animateOut();
    }

    function finishLeaveAnimation() {
        root.reveal = 0;
        root.contentOpacity = 0;
        root.contentScale = 0.96;
        removeFallbackTimer.stop();
        if (root.delayModelRemove)
            root.ListView.delayRemove = false;
        Qt.callLater(root.settleListView);
    }

    function currentResult() {
        return root.result;
    }

    function settleListView() {
        const view = root.ListView.view;
        if (!view)
            return;
        if (typeof view.settleLayout === "function")
            view.settleLayout();
        else if (typeof view.forceLayout === "function")
            view.forceLayout();
    }

    function wireLoadedItem() {
        const loaded = content.item;
        if (!loaded)
            return;

        if ("result" in loaded)
            loaded.result = Qt.binding(function() { return root.currentResult(); });
        if ("resultIndex" in loaded)
            loaded.resultIndex = Qt.binding(function() { return root.rank; });
        if ("selected" in loaded)
            loaded.selected = Qt.binding(function() { return root.controller && root.controller.activeNodeKey === root.key; });
        if ("iconSize" in loaded)
            loaded.iconSize = Qt.binding(function() { return root.iconSize; });
        if ("showSubtitle" in loaded)
            loaded.showSubtitle = Qt.binding(function() { return root.showSubtitle; });
        if ("showActionHint" in loaded)
            loaded.showActionHint = Qt.binding(function() { return root.showActionHint; });
        if ("showEvidence" in loaded)
            loaded.showEvidence = Qt.binding(function() { return root.showEvidence; });
        if ("controller" in loaded)
            loaded.controller = Qt.binding(function() { return root.controller; });
        if (loaded.activated)
            loaded.activated.connect(function() {
                if (!root.removing)
                    root.activated(root.rank);
            });
    }

    TransitionItemAnimator {
        id: animator
        target: root
        animationMode: root.animationMode
        onLeaveFinished: root.finishLeaveAnimation()
    }

    Loader {
        id: content

        active: !!root.sourceComponent
        sourceComponent: root.sourceComponent
        width: root.width
        height: implicitHeight
        opacity: root.contentOpacity
        scale: root.contentScale
        transformOrigin: Item.Top
        enabled: !root.removing && root.phase !== "leaving"

        onLoaded: root.wireLoadedItem()
    }
}
