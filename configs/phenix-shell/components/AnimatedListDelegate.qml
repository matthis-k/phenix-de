import QtQuick
import qs.animations as Animations

Loader {
    id: root

    property bool animateSize: true
    property bool appeared: true
    property string animationKey: ""
    property var seenKeys: null

    width: ListView.view ? ListView.view.width : 0
    height: appeared && visible && item ? item.implicitHeight : 0
    visible: !!sourceComponent
    clip: true

    Animations.LayoutBehavior on height {
        enabled: root.animateSize
    }

    ListView.onAdd: {
        var shouldAnimate = true;
        if (root.animationKey !== "" && root.seenKeys !== null) {
            shouldAnimate = root.seenKeys[root.animationKey] !== true;
            root.seenKeys[root.animationKey] = true;
        }
        if (shouldAnimate) {
            root.appeared = false;
            Qt.callLater(function() {
                if (root)
                    root.appeared = true;
            });
        }
    }

    ListView.onRemove: retainedDisappear.start()

    Animations.RetainedDisappearAnimation {
        id: retainedDisappear

        targetItem: root
    }
}
