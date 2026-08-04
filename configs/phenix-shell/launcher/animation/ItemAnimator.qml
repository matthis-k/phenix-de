pragma ComponentBehavior: Bound

import QtQuick
import qs.animations as Animations

Item {
    id: root

    required property Item target

    readonly property Animations.TransitionPolicy transitionPolicy: Animations.TransitionPolicy {}
    property int enterDuration: transitionPolicy.duration(
        Animations.TransitionPolicy.Kind.ListInsert,
        Animations.TransitionPolicy.Mode.Full)
    property int removeDuration: transitionPolicy.duration(
        Animations.TransitionPolicy.Kind.ListRemove,
        Animations.TransitionPolicy.Mode.Full)
    property int transformDuration: transitionPolicy.duration(
        Animations.TransitionPolicy.Kind.Scale,
        Animations.TransitionPolicy.Mode.Full)

    property bool _leaving: false

    signal leaveFinished()

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

        revealAnim.stop();
        revealAnim.to = 1;
        revealAnim.duration = root.enterDuration;
        revealAnim.easing.type = root.transitionPolicy.easing(
            Animations.TransitionPolicy.Kind.ListInsert,
            "in",
            Animations.TransitionPolicy.Mode.Full);
        revealAnim.restart();

        opacityAnim.stop();
        opacityAnim.to = 1;
        opacityAnim.duration = root.transformDuration;
        opacityAnim.easing.type = root.transitionPolicy.easing(
            Animations.TransitionPolicy.Kind.Enter,
            "in",
            Animations.TransitionPolicy.Mode.Full);
        opacityAnim.restart();

        scaleAnim.stop();
        scaleAnim.to = 1;
        scaleAnim.duration = root.transformDuration;
        scaleAnim.easing.type = root.transitionPolicy.easing(
            Animations.TransitionPolicy.Kind.Scale,
            "in",
            Animations.TransitionPolicy.Mode.Full);
        scaleAnim.restart();
    }

    function animateOut() {
        root._leaving = true;

        revealAnim.stop();
        revealAnim.to = 0;
        revealAnim.duration = root.removeDuration;
        revealAnim.easing.type = root.transitionPolicy.easing(
            Animations.TransitionPolicy.Kind.ListRemove,
            "out",
            Animations.TransitionPolicy.Mode.Full);
        revealAnim.restart();

        opacityAnim.stop();
        opacityAnim.to = 0;
        opacityAnim.duration = root.removeDuration;
        opacityAnim.easing.type = root.transitionPolicy.easing(
            Animations.TransitionPolicy.Kind.Exit,
            "out",
            Animations.TransitionPolicy.Mode.Full);
        opacityAnim.restart();

        scaleAnim.stop();
        scaleAnim.to = 0.96;
        scaleAnim.duration = root.removeDuration;
        scaleAnim.easing.type = root.transitionPolicy.easing(
            Animations.TransitionPolicy.Kind.Scale,
            "out",
            Animations.TransitionPolicy.Mode.Full);
        scaleAnim.restart();
    }

    function snapToLive() {
        root._leaving = false;
        revealAnim.stop();
        opacityAnim.stop();
        scaleAnim.stop();
        root.target.reveal = 1;
        root.target.contentOpacity = 1;
        root.target.contentScale = 1;
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
