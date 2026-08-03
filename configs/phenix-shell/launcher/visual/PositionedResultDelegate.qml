pragma ComponentBehavior: Bound

import QtQuick
import qs.animations
import qs.services

TransitionListRow {
    id: root

    property Component sourceComponent: null
    property var controller: null

    property int iconSize: 32
    property bool showSubtitle: true
    property bool showActionHint: true
    property bool showEvidence: false

    readonly property var result: root.payload
    readonly property Item item: content.item

    signal activated(int rank)

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
}
