pragma ComponentBehavior: Bound

import QtQuick
import qs.services

QtObject {
    id: root

    enum Mode {
        None,
        Light,
        Full,
        FastInput
    }

    enum Kind {
        Micro,
        Short,
        Medium,
        Long,
        Enter,
        Exit,
        Layout,
        Move,
        Color,
        Scale,
        Panel,
        ListInsert,
        ListRemove,
        ListMove
    }

    property bool animationsEnabled: Config.behaviour.animation.enabled

    function duration(kind, mode) {
        if (!root.animationsEnabled || mode === TransitionPolicy.Mode.None)
            return 0;

        const base = root.baseDuration(kind);
        const scale = root.modeScale(mode);
        return Math.round(base * scale);
    }

    function easing(kind, direction, mode) {
        if (!root.animationsEnabled || mode === TransitionPolicy.Mode.None)
            return Easing.Linear;

        if (mode === TransitionPolicy.Mode.FastInput)
            return Easing.OutQuad;

        switch (kind) {
        case TransitionPolicy.Kind.Exit:
        case TransitionPolicy.Kind.ListRemove:
            return Easing.InCubic;
        case TransitionPolicy.Kind.Layout:
        case TransitionPolicy.Kind.Move:
        case TransitionPolicy.Kind.ListMove:
            return Easing.InOutCubic;
        case TransitionPolicy.Kind.Color:
        case TransitionPolicy.Kind.Scale:
            return Easing.OutCubic;
        default:
            return direction === "out" ? Easing.InCubic : Easing.OutCubic;
        }
    }

    function settleDelay(mode) {
        if (!root.animationsEnabled || mode === TransitionPolicy.Mode.None)
            return 0;
        switch (mode) {
        case TransitionPolicy.Mode.Light:
        case TransitionPolicy.Mode.FastInput:
            return 80;
        case TransitionPolicy.Mode.Full:
            return 160;
        default:
            return 0;
        }
    }

    function removalDelay(mode) {
        if (!root.animationsEnabled || mode === TransitionPolicy.Mode.None)
            return 0;
        switch (mode) {
        case TransitionPolicy.Mode.Light:
        case TransitionPolicy.Mode.FastInput:
            return 120;
        case TransitionPolicy.Mode.Full:
            return 180;
        default:
            return 0;
        }
    }

    function shouldAnimate(kind, mode) {
        return root.animationsEnabled && mode !== TransitionPolicy.Mode.None && root.duration(kind, mode) > 0;
    }

    function modeForSnapshot(context) {
        if (!root.animationsEnabled)
            return TransitionPolicy.Mode.None;

        const input = context.inputText || "";
        const prevInput = context.previousInputText || "";
        const ctxKey = context.contextKey || "";
        const prevCtxKey = context.previousContextKey || "";
        const reason = context.reason || "";
        const prevCount = context.previousItemCount || 0;
        const nextCount = context.activeItemCount || 0;

        if (reason === "close" || reason === "reset")
            return TransitionPolicy.Mode.None;

        if (reason === "open")
            return prevCount > 0 ? TransitionPolicy.Mode.Light : TransitionPolicy.Mode.Full;

        if (reason === "contextSwitch" || (prevCtxKey !== "" && ctxKey !== prevCtxKey))
            return TransitionPolicy.Mode.Full;

        if (input.trim().length === 0)
            return prevCount > 0 ? TransitionPolicy.Mode.Light : TransitionPolicy.Mode.None;

        if (prevInput.trim().length === 0)
            return TransitionPolicy.Mode.Full;

        if (prevInput === input)
            return TransitionPolicy.Mode.Light;

        if (root.isSingleCharEdit(prevInput, input)) {
            const timeSince = context.timeSinceLastSnapshot || 999;
            if (timeSince < 120)
                return TransitionPolicy.Mode.FastInput;
            return TransitionPolicy.Mode.Light;
        }

        return TransitionPolicy.Mode.Light;
    }

    function baseDuration(kind) {
        switch (kind) {
        case TransitionPolicy.Kind.Micro:
            return Config.motion.micro;
        case TransitionPolicy.Kind.Short:
        case TransitionPolicy.Kind.Enter:
        case TransitionPolicy.Kind.Exit:
        case TransitionPolicy.Kind.Scale:
        case TransitionPolicy.Kind.ListInsert:
        case TransitionPolicy.Kind.ListRemove:
            return Config.motion.short;
        case TransitionPolicy.Kind.Medium:
        case TransitionPolicy.Kind.Layout:
        case TransitionPolicy.Kind.Move:
        case TransitionPolicy.Kind.Panel:
        case TransitionPolicy.Kind.ListMove:
            return Config.motion.medium;
        case TransitionPolicy.Kind.Long:
            return Config.motion.long;
        case TransitionPolicy.Kind.Color:
            return Config.motion.micro;
        default:
            return Config.motion.short;
        }
    }

    function modeScale(mode) {
        switch (mode) {
        case TransitionPolicy.Mode.Light:
            return 0.6;
        case TransitionPolicy.Mode.FastInput:
            return 0.4;
        case TransitionPolicy.Mode.Full:
            return 1.0;
        default:
            return 0;
        }
    }

    function isSingleCharEdit(prev, next) {
        if (Math.abs(prev.length - next.length) !== 1)
            return false;
        return prev.indexOf(next) === 0 || next.indexOf(prev) === 0;
    }
}
