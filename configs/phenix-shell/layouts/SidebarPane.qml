import QtQuick
import QtQuick.Controls as Controls

// Convenience two-pane layout using the real SplitView. Pass Components to
// sidebar and mainPane, not QML Items: the Loaders own their lifetimes.
Item {
    id: root

    property Component sidebar: null
    property Component mainPane: null
    property bool sidebarVisible: true
    property int preferredSidebarWidth: 220
    property int minimumSidebarWidth: 128
    property int maximumSidebarWidth: 480
    property alias splitView: splitter

    implicitWidth: 640
    implicitHeight: 360

    SplitPane {
        id: splitter
        anchors.fill: parent

        Item {
            visible: root.sidebarVisible
            implicitWidth: root.preferredSidebarWidth
            Controls.SplitView.preferredWidth: root.preferredSidebarWidth
            Controls.SplitView.minimumWidth: root.minimumSidebarWidth
            Controls.SplitView.maximumWidth: root.maximumSidebarWidth

            Loader {
                anchors.fill: parent
                active: root.sidebarVisible && root.sidebar !== null
                sourceComponent: root.sidebar
            }
        }

        Item {
            Controls.SplitView.fillWidth: true

            Loader {
                anchors.fill: parent
                active: root.mainPane !== null
                sourceComponent: root.mainPane
            }
        }
    }
}
