import QtQuick

StateColorBehavior {
    id: root

    property bool active: true
    property bool settled: false

    enabled: active && settled

    Component.onCompleted: Qt.callLater(function() {
        root.settled = true;
    })
}
