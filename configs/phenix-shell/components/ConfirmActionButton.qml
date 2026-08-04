import QtQuick

ActionButton {
    id: root

    property bool confirming: false
    property int confirmTimeoutMs: 1600
    property string confirmationDescription: qsTr("Activate again to confirm. Press Escape to cancel.")

    signal confirmed
    signal confirmationCancelled

    Accessible.description: root.confirming
        ? root.confirmationDescription
        : root.accessibleDescription

    function cancelConfirmation() {
        if (!root.confirming)
            return;
        root.confirming = false;
        root.confirmationCancelled();
    }

    onClicked: {
        if (confirming) {
            confirming = false;
            confirmed();
            return;
        }

        confirming = true;
        forceActiveFocus(Qt.MouseFocusReason);
    }

    onActiveFocusChanged: {
        if (!activeFocus)
            root.cancelConfirmation();
    }

    Keys.onEscapePressed: event => {
        if (!root.confirming)
            return;
        root.cancelConfirmation();
        event.accepted = true;
    }

    Timer {
        id: confirmTimer
        interval: root.confirmTimeoutMs
        running: root.confirming
        repeat: false
        onTriggered: root.cancelConfirmation()
    }
}
