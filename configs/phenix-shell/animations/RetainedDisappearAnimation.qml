import QtQuick
import qs.services

SequentialAnimation {
    id: root

    property Item targetItem
    property string sizeProperty: "height"
    property real sizeTo: 0
    property int sizeKind: MotionAnimation.Kind.Layout

    PropertyAction {
        target: root.targetItem
        property: "ListView.delayRemove"
        value: true
    }

    MotionAnimation {
        target: root.targetItem
        property: root.sizeProperty
        to: root.sizeTo
        kind: root.sizeKind
    }

    PropertyAction {
        target: root.targetItem
        property: "ListView.delayRemove"
        value: false
    }
}
