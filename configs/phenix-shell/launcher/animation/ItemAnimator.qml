pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    required property Item target

    property int enterDuration: 140
    property int removeDuration: 120
    property int transformDuration: 120

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
        revealAnim.easing.type = Easing.OutCubic;
        revealAnim.restart();

        opacityAnim.stop();
        opacityAnim.to = 1;
        opacityAnim.duration = root.transformDuration;
        opacityAnim.easing.type = Easing.OutCubic;
        opacityAnim.restart();

        scaleAnim.stop();
        scaleAnim.to = 1;
        scaleAnim.duration = root.transformDuration;
        scaleAnim.easing.type = Easing.OutCubic;
        scaleAnim.restart();
    }

    function animateOut() {
        root._leaving = true;

        revealAnim.stop();
        revealAnim.to = 0;
        revealAnim.duration = root.removeDuration;
        revealAnim.easing.type = Easing.InCubic;
        revealAnim.restart();

        opacityAnim.stop();
        opacityAnim.to = 0;
        opacityAnim.duration = root.removeDuration;
        opacityAnim.easing.type = Easing.InCubic;
        opacityAnim.restart();

        scaleAnim.stop();
        scaleAnim.to = 0.96;
        scaleAnim.duration = root.removeDuration;
        scaleAnim.easing.type = Easing.InCubic;
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
