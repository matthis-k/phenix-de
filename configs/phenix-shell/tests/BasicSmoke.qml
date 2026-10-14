// Control fixture to distinguish missing Qt modules from custom style bugs.
import QtQuick
import QtQuick.Controls.Basic

ApplicationWindow {
    width: 220
    height: 100
    visible: true

    Button {
        anchors.centerIn: parent
        text: "Basic works"
    }

    Component.onCompleted: Qt.callLater(Qt.quit)
}
