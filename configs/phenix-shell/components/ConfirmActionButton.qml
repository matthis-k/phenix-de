import QtQuick

ActionButton {
    id: root

    property bool confirming: false
    property int confirmTimeoutMs: 1600

    signal confirmed

    onClicked: {
        if (confirming) {
            confirming = false;
            confirmed();
            return;
        }

        confirming = true;
    }

    Timer {
        id: confirmTimer
        interval: root.confirmTimeoutMs
        running: root.confirming
        repeat: false
        onTriggered: root.confirming = false
    }
}
