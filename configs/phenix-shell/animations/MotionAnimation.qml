import QtQuick
import qs.services

NumberAnimation {
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

    property int kind: MotionAnimation.Kind.Short
    property int motionDuration: {
        switch (kind) {
        case MotionAnimation.Kind.Micro:
            return Config.motion.micro;
        case MotionAnimation.Kind.Medium:
        case MotionAnimation.Kind.Layout:
            return Config.motion.medium;
        case MotionAnimation.Kind.Long:
            return Config.motion.long;
        default:
            return Config.motion.short;
        }
    }
    property int motionEasingType: {
        switch (kind) {
        case MotionAnimation.Kind.Exit:
            return Easing.InCubic;
        case MotionAnimation.Kind.Layout:
            return Easing.InOutCubic;
        case MotionAnimation.Kind.Neutral:
            return Easing.InOutQuad;
        default:
            return Easing.OutCubic;
        }
    }

    duration: motionDuration
    easing.type: motionEasingType
}
