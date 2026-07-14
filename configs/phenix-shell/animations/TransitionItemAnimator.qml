pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    required property Item target

    property int animationMode: TransitionPolicy.Mode.Full
    property bool animateReveal: true
    property bool animateOpacity: true
    property bool animateScale: true
    property real scaleFrom: 0.96
    property real scaleTo: 1.0

    property bool _leaving: false

    signal leaveFinished()

    TransitionPolicy {
        id: policy
    }

    NumberAnimation {
        id: revealAnim
        target: root.target
        property: "reveal"
    }

    NumberAnimation {
        id: opacityAnim
        target: root.target
        property: "contentOpacity"
    }

    NumberAnimation {
        id: scaleAnim
        target: root.target
        property: "contentScale"
    }

    function animateIn() {
        root._leaving = false;
        const mode = root.animationMode;
        const dur = policy.duration(TransitionPolicy.Kind.ListInsert, mode);
        const ease = policy.easing(TransitionPolicy.Kind.ListInsert, "in", mode);

        if (root.animateReveal) {
            revealAnim.stop();
            revealAnim.to = 1;
            revealAnim.duration = dur;
            revealAnim.easing.type = ease;
            revealAnim.restart();
        }

        if (root.animateOpacity) {
            opacityAnim.stop();
            opacityAnim.to = 1;
            opacityAnim.duration = policy.duration(TransitionPolicy.Kind.Short, mode);
            opacityAnim.easing.type = ease;
            opacityAnim.restart();
        }

        if (root.animateScale) {
            scaleAnim.stop();
            scaleAnim.to = root.scaleTo;
            scaleAnim.duration = policy.duration(TransitionPolicy.Kind.Scale, mode);
            scaleAnim.easing.type = ease;
            scaleAnim.restart();
        }
    }

    function animateOut() {
        root._leaving = true;
        const mode = root.animationMode;
        const dur = policy.duration(TransitionPolicy.Kind.ListRemove, mode);
        const ease = policy.easing(TransitionPolicy.Kind.ListRemove, "out", mode);

        if (root.animateReveal) {
            revealAnim.stop();
            revealAnim.to = 0;
            revealAnim.duration = dur;
            revealAnim.easing.type = ease;
            revealAnim.restart();
        }

        if (root.animateOpacity) {
            opacityAnim.stop();
            opacityAnim.to = 0;
            opacityAnim.duration = dur;
            opacityAnim.easing.type = ease;
            opacityAnim.restart();
        }

        if (root.animateScale) {
            scaleAnim.stop();
            scaleAnim.to = root.scaleFrom;
            scaleAnim.duration = dur;
            scaleAnim.easing.type = ease;
            scaleAnim.restart();
        }
    }

    function snapToLive() {
        root._leaving = false;
        revealAnim.stop();
        opacityAnim.stop();
        scaleAnim.stop();
        root.target.reveal = 1;
        root.target.contentOpacity = 1;
        root.target.contentScale = root.scaleTo;
    }

    function cancel() {
        root._leaving = false;
        revealAnim.stop();
        opacityAnim.stop();
        scaleAnim.stop();
    }

    Connections {
        target: revealAnim
        function onFinished() {
            if (root._leaving && root.target.reveal <= 0.01)
                root.leaveFinished();
        }
    }
}
