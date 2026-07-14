pragma ComponentBehavior: Bound

import QtQuick
import qs.animations
import qs.services

Flickable {
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

    clip: true
    boundsBehavior: Flickable.StopAtBounds
    contentWidth: width
    contentHeight: coordinator ? coordinator.contentHeight : 0

    function itemAtIndex(index) {
        let best = null;
        for (let i = 0; i < repeater.count; i += 1) {
            const item = repeater.itemAt(i);
            if (!item)
                continue;
            if (item.rank === index || item.targetRank === index) {
                best = item;
                break;
            }
        }
        return best;
    }

    function settleLayout() {
        pinContentToTopIfNeeded();
    }

    function pinContentToTopIfNeeded() {
        if (contentHeight <= height || (!root.controller || !root.controller.isInTree || (!root.controller.isInTree() && repeater.count <= root.visibleResultRows)))
            contentY = 0;
    }

    onContentHeightChanged: Qt.callLater(settleLayout)
    onHeightChanged: Qt.callLater(settleLayout)

    Repeater {
        id: repeater

        model: root.coordinator ? root.coordinator.model : null

        delegate: PositionedResultDelegate {
            coordinator: root.coordinator
            sourceComponent: root.resultDelegate
            controller: root.controller
            animationMode: root.activeAnimationMode
            spacing: root.rowSpacing
            estimatedRowHeight: root.estimatedRowHeight
            iconSize: root.iconSize
            showSubtitle: root.showSubtitles
            showActionHint: root.showActionHint
            showEvidence: root.showEvidence

            width: root.width

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
}
