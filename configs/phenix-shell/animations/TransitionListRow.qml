pragma ComponentBehavior: Bound

import QtQuick
import qs.services

Item {
    id: root

    required property string key
    required property var payload
    required property int rank
    required property int previousRank
    required property int targetRank
    required property string phase
    required property string movementKind
    required property bool contentChanged
    required property real targetY
    required property real visualHeight
    required property real targetOpacity
    required property real targetScale
    required property int zValue

    property var coordinator: null
    property int animationMode: TransitionPolicy.Mode.Full
    property int spacing: 0
    property int estimatedRowHeight: 56

    default property alias contentData: contentHost.data

    readonly property real measuredContentHeight: Math.max(contentHost.childrenRect.height, root.estimatedRowHeight)
    readonly property real fullHeight: root.measuredContentHeight + root.spacing
    readonly property bool activelyReordering: root.movementKind === "reorder" || root.movementKind === "resurrect"

    TransitionPolicy { id: policy }

    x: 0
    y: root.targetY
    width: parent ? parent.width : 0
    height: root.visualHeight
    opacity: root.targetOpacity
    scale: root.targetScale
    z: root.zValue
    clip: true
    visible: root.phase !== "leaving" || opacity > 0.01 || height > 0.5
    transformOrigin: Item.Top

    Behavior on y {
        enabled: Config.behaviour.animation.enabled && root.animationMode !== TransitionPolicy.Mode.None
        NumberAnimation {
            duration: policy.duration(TransitionPolicy.Kind.ListMove, root.animationMode)
            easing.type: policy.easing(TransitionPolicy.Kind.ListMove, "in", root.animationMode)
        }
    }

    Behavior on height {
        enabled: Config.behaviour.animation.enabled && root.animationMode !== TransitionPolicy.Mode.None
        NumberAnimation {
            duration: root.phase === "leaving"
                ? policy.duration(TransitionPolicy.Kind.ListRemove, root.animationMode)
                : policy.duration(TransitionPolicy.Kind.ListInsert, root.animationMode)
            easing.type: root.phase === "leaving"
                ? policy.easing(TransitionPolicy.Kind.ListRemove, "out", root.animationMode)
                : policy.easing(TransitionPolicy.Kind.ListInsert, "in", root.animationMode)
        }
    }

    Behavior on opacity {
        enabled: Config.behaviour.animation.enabled && root.animationMode !== TransitionPolicy.Mode.None
        NumberAnimation {
            duration: root.phase === "leaving"
                ? policy.duration(TransitionPolicy.Kind.ListRemove, root.animationMode)
                : policy.duration(TransitionPolicy.Kind.ListInsert, root.animationMode)
            easing.type: root.phase === "leaving"
                ? policy.easing(TransitionPolicy.Kind.ListRemove, "out", root.animationMode)
                : policy.easing(TransitionPolicy.Kind.ListInsert, "in", root.animationMode)
        }
    }

    Behavior on scale {
        enabled: Config.behaviour.animation.enabled && root.animationMode !== TransitionPolicy.Mode.None
        NumberAnimation {
            duration: policy.duration(TransitionPolicy.Kind.Scale, root.animationMode)
            easing.type: policy.easing(TransitionPolicy.Kind.Scale, "in", root.animationMode)
        }
    }

    Item {
        id: contentHost

        width: root.width
        height: childrenRect.height
        enabled: root.phase !== "leaving"
    }

    Component.onCompleted: root.reportMeasuredHeight()
    onFullHeightChanged: Qt.callLater(root.reportMeasuredHeight)

    function reportMeasuredHeight() {
        if (!root.coordinator || !root.key)
            return;
        if (typeof root.coordinator.updateMeasuredHeight === "function")
            root.coordinator.updateMeasuredHeight(root.key, root.fullHeight);
    }
}
