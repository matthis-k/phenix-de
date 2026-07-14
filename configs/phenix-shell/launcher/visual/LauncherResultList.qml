pragma ComponentBehavior: Bound

import QtQuick
import qs.animations
import qs.services

ListView {
    id: root

    property var coordinator: null
    property Component resultDelegate: null
    property var controller: null
    property int iconSize: 32
    property int visibleResultRows: 12
    property bool showSubtitles: true
    property bool showActionHint: true
    property bool showEvidence: false
    property int rowSpacing: Config.spacing.xxs
    property int estimatedRowHeight: 56

    readonly property int activeAnimationMode: coordinator ? coordinator.animationMode : TransitionPolicy.Mode.Full

    signal closeRequested()

    TransitionPolicy {
        id: policy
    }

    model: root.coordinator ? root.coordinator.model : null
    boundsBehavior: Flickable.StopAtBounds
    cacheBuffer: root.visibleResultRows * (root.estimatedRowHeight + root.rowSpacing)
    clip: true
    spacing: 0
    reuseItems: false

    readonly property int _moveDuration: policy.duration(TransitionPolicy.Kind.ListMove, root.activeAnimationMode)
    readonly property int _moveEasing: policy.easing(TransitionPolicy.Kind.ListMove, "in", root.activeAnimationMode)

    move: Transition {
        NumberAnimation {
            properties: "x,y"
            duration: root._moveDuration
            easing.type: root._moveEasing
        }
    }

    moveDisplaced: Transition {
        NumberAnimation {
            properties: "x,y"
            duration: root._moveDuration
            easing.type: root._moveEasing
        }
    }

    function pinContentToTopIfNeeded() {
        if (contentHeight <= height || (!root.controller || !root.controller.isInTree || (!root.controller.isInTree() && count <= root.visibleResultRows)))
            contentY = 0;
    }

    function settleLayout() {
        forceLayout();
        pinContentToTopIfNeeded();
    }

    onCountChanged: Qt.callLater(settleLayout)
    onContentHeightChanged: Qt.callLater(settleLayout)
    onHeightChanged: Qt.callLater(settleLayout)

    delegate: LauncherResultDelegate {
        sourceComponent: root.resultDelegate
        controller: root.controller
        animationMode: root.activeAnimationMode
        spacing: root.rowSpacing
        estimatedRowHeight: root.estimatedRowHeight
        iconSize: root.iconSize
        showSubtitle: root.showSubtitles
        showActionHint: root.showActionHint
        showEvidence: root.showEvidence

        onActivated: function(rank) {
            if (!root.controller)
                return;
            root.controller.selectedIndex = rank;
            var result = root.controller._handleActivationWithConfirm();
            if (result && result.closeRequested)
                root.closeRequested();
        }
    }
}
