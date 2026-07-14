pragma ComponentBehavior: Bound

import QtQuick
import qs.services

ListView {
    id: root

    property var coordinator: null
    property Component payloadDelegate: null
    property int rowSpacing: 0
    property int estimatedRowHeight: 56
    property int visibleRows: 12
    property bool contentPinningEnabled: true

    readonly property int activeAnimationMode: coordinator ? coordinator.animationMode : TransitionPolicy.Mode.Full

    TransitionPolicy {
        id: policy
    }

    model: root.coordinator ? root.coordinator.model : null
    boundsBehavior: Flickable.StopAtBounds
    cacheBuffer: root.visibleRows * (root.estimatedRowHeight + root.rowSpacing)
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
        if (!root.contentPinningEnabled)
            return;
        if (contentHeight <= height)
            contentY = 0;
    }

    function settleLayout() {
        forceLayout();
        pinContentToTopIfNeeded();
    }

    onCountChanged: Qt.callLater(settleLayout)
    onContentHeightChanged: Qt.callLater(settleLayout)
    onHeightChanged: Qt.callLater(settleLayout)

    delegate: TransitionListDelegate {
        coordinator: root.coordinator
        sourceComponent: root.payloadDelegate
        animationMode: root.activeAnimationMode
        spacing: root.rowSpacing
        estimatedRowHeight: root.estimatedRowHeight
    }
}
