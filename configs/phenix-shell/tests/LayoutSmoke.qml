// Standalone Qt Quick fixture; requires no Quickshell imports.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../layouts" as Layouts

ApplicationWindow {
    id: window
    visible: true
    width: 760
    height: 700
    title: "Phenix layouts smoke"

    Component {
        id: pageA
        Pane { Label { anchors.centerIn: parent; text: "Overview" } }
    }
    Component {
        id: pageB
        Pane { Label { anchors.centerIn: parent; text: "Details" } }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Layouts.TabbedPane {
            id: horizontalTabs
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            tabs: [
                { label: "Overview", page: pageA },
                { label: "Details", page: pageB }
            ]
            currentIndex: 1
        }

        Layouts.TabbedPane {
            id: verticalTabs
            Layout.fillWidth: true
            Layout.preferredHeight: 140
            orientation: Qt.Vertical
            keepPagesAlive: false
            tabs: [
                { label: "Overview", page: pageA },
                { label: "Details", page: pageB }
            ]
            currentIndex: 1
        }

        Layouts.SplitPane {
            id: split
            Layout.fillWidth: true
            Layout.preferredHeight: 105

            Pane {
                SplitView.preferredWidth: 230
                Label { text: "Master" }
            }
            Pane {
                SplitView.fillWidth: true
                Label { text: "Detail" }
            }
        }

        Layouts.SidebarPane {
            id: sidebar
            Layout.fillWidth: true
            Layout.preferredHeight: 110
            sidebar: pageA
            mainPane: pageB
        }

        Layouts.PageScaffold {
            id: scaffold
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: "Settings"
            description: "Reusable header and content shell"

            Button { text: "Apply"; Layout.alignment: Qt.AlignLeft }
        }
    }

    Timer {
        interval: 600
        repeat: false
        running: true

        onTriggered: {
            if (horizontalTabs.stack.count !== 2
                || verticalTabs.stack.count !== 2
                || horizontalTabs.currentIndex !== 1
                || verticalTabs.currentIndex !== 1
                || split.count !== 2
                || sidebar.splitView.count !== 2) {
                console.error("Layout smoke contract failed");
                Qt.exit(1);
                return;
            }
            Qt.quit();
        }
    }
}
