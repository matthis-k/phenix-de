pragma ComponentBehavior: Bound

import QtQuick
import qs.animations
import qs.services

Item {
    id: root

    required property string key
    required property var payload
    required property int rank
    required property int targetRank
    required property string phase
    required property real targetY
    required property real visualHeight
    required property real targetOpacity
    required property real targetScale
    required property int zValue

    property var coordinator: null
    property Component sourceComponent: null
    property var controller: null

    property int animationMode: TransitionPolicy.Mode.Full
    property int spacing: 0
    property int estimatedRowHeight: 56
    property int iconSize: 32
    property bool showSubtitle: true
    property bool showActionHint: true
    property bool showEvidence: false

    readonly property var result: root.payload
    readonly property Item item: content.item
    readonly property real fullHeight: Math.max(content.implicitHeight, root.estimatedRowHeight) + root.spacing

    signal activated(int rank)

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
            easing.type: Easing.OutCubic
        }
    }

    Behavior on opacity {
        enabled: Config.behaviour.animation.enabled && root.animationMode !== TransitionPolicy.Mode.None
        NumberAnimation {
            duration: root.phase === "leaving"
                ? policy.duration(TransitionPolicy.Kind.ListRemove, root.animationMode)
                : policy.duration(TransitionPolicy.Kind.ListInsert, root.animationMode)
            easing.type: Easing.OutCubic
        }
    }

    Behavior on scale {
        enabled: Config.behaviour.animation.enabled && root.animationMode !== TransitionPolicy.Mode.None
        NumberAnimation {
            duration: policy.duration(TransitionPolicy.Kind.ListTransform, root.animationMode)
            easing.type: Easing.OutCubic
        }
    }

    Component.onCompleted: reportMeasuredHeight()
    onFullHeightChanged: Qt.callLater(reportMeasuredHeight)

    function reportMeasuredHeight() {
        if (!root.coordinator || !root.key)
            return;
        if (typeof root.coordinator.updateMeasuredHeight === "function")
            root.coordinator.updateMeasuredHeight(root.key, root.fullHeight);
    }

    function currentResult() {
        return root.payload || {};
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

        if (loaded.activated) {
            loaded.activated.connect(function() {
                if (root.phase !== "leaving")
                    root.activated(root.rank);
            });
        }

        Qt.callLater(root.reportMeasuredHeight);
    }

    Loader {
        id: content

        active: !!root.sourceComponent
        sourceComponent: root.sourceComponent
        width: root.width
        height: implicitHeight
        opacity: 1
        scale: 1
        transformOrigin: Item.Top
        enabled: root.phase !== "leaving"

        onLoaded: root.wireLoadedItem()
    }
}
