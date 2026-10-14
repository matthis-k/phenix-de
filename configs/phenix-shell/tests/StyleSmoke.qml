// Offscreen smoke fixture for the standalone Qt Quick Controls style.
// Run with QT_QUICK_CONTROLS_STYLE=Phenix and STYLE_PATH=.../styles.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    width: 500
    height: 360
    visible: true
    title: "Phenix Qt Controls smoke"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12

        RowLayout {
            Button { text: "Apply" }
            CheckBox { text: "Enabled"; checked: true }
            RadioButton { text: "Option"; checked: true }
            Switch { text: "On"; checked: true }
        }

        TextField { placeholderText: "Search"; Layout.fillWidth: true }
        TextArea { text: "Multiline input"; Layout.fillWidth: true }
        Slider { from: 0; to: 100; value: 50; Layout.fillWidth: true }

        TabBar {
            TabButton { text: "Overview" }
            TabButton { text: "Details" }
        }

        RowLayout {
            ComboBox { model: ["One", "Two"] }
            SpinBox { from: 0; to: 12; value: 3 }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Text { text: "Basic fallback controls remain available" }
        }
    }

    Timer {
        running: true
        interval: 500
        repeat: false
        onTriggered: Qt.quit()
    }
}
