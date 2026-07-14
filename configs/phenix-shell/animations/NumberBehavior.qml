import QtQuick
import qs.services

Behavior {
    id: root

    enum Kind {
        Micro,
        Short,
        Medium,
        Long,
        Enter,
        Exit,
        Layout,
        Neutral
    }

    property int kind: NumberBehavior.Kind.Short
    property int duration: {
        switch (kind) {
        case NumberBehavior.Kind.Micro:
            return Config.motion.micro;
        case NumberBehavior.Kind.Medium:
        case NumberBehavior.Kind.Layout:
            return Config.motion.medium;
        case NumberBehavior.Kind.Long:
            return Config.motion.long;
        default:
            return Config.motion.short;
        }
    }
    property int easingType: {
        switch (kind) {
        case NumberBehavior.Kind.Exit:
            return Easing.InCubic;
        case NumberBehavior.Kind.Layout:
            return Easing.InOutCubic;
        case NumberBehavior.Kind.Neutral:
            return Easing.InOutQuad;
        default:
            return Easing.OutCubic;
        }
    }

    NumberAnimation {
        duration: root.duration
        easing.type: root.easingType
    }
}
