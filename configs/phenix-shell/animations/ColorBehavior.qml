import QtQuick
import qs.services

Behavior {
    id: root

    enum Kind {
        State,
        Neutral,
        Accent
    }

    property int kind: ColorBehavior.Kind.State
    property int duration: kind === ColorBehavior.Kind.Neutral
        ? Config.motion.short
        : Config.motion.micro
    property int easingType: kind === ColorBehavior.Kind.Neutral
        ? Easing.InOutQuad
        : Easing.OutCubic

    ColorAnimation {
        duration: root.duration
        easing.type: root.easingType
    }
}
