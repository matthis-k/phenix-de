import QtQuick
import qs.services

RotationAnimation {
    id: root

    property int motionDuration: Config.behaviour.animation.enabled
        ? Config.behaviour.animation.calc(0.9)
        : 0

    loops: Animation.Infinite
    from: 0
    to: 360
    duration: motionDuration
}
