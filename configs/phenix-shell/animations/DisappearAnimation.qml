import QtQuick
import qs.services

ParallelAnimation {
    id: root

    property string sizeProperty: "height"
    property real sizeTo: 0
    property int sizeKind: MotionAnimation.Kind.Layout

    MotionAnimation {
        properties: root.sizeProperty
        to: root.sizeTo
        kind: root.sizeKind
    }
}
