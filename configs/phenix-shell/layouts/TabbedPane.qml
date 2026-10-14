import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

// Native tabs + StackLayout. Entries are { label, page: Component, enabled? }.
// Set orientation to Qt.Vertical for a left-side tab rail.
// The page Component is loaded once by default, preserving its local state.
Item {
    id: root

    property var tabs: []
    property int currentIndex: 0
    property int orientation: Qt.Horizontal
    property bool keepPagesAlive: true
    property int railWidth: 168

    readonly property bool vertical: orientation === Qt.Vertical
    readonly property alias stack: stack

    signal tabSelected(int index)

    implicitWidth: 440
    implicitHeight: 320

    function titleOf(entry) {
        return typeof entry === "string"
            ? entry : String((entry && entry.label) || "");
    }

    function pageOf(entry) {
        return entry && typeof entry === "object" ? entry.page || null : null;
    }

    function enabledOf(entry) {
        return !entry || typeof entry !== "object" || entry.enabled !== false;
    }

    function select(index) {
        if (index < 0 || index >= tabs.length || !enabledOf(tabs[index]))
            return;
        if (currentIndex !== index) {
            currentIndex = index;
            tabSelected(index);
        }
    }

    onTabsChanged: {
        if (currentIndex >= tabs.length)
            currentIndex = Math.max(0, tabs.length - 1);
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        ColumnLayout {
            id: rail
            visible: root.vertical
            Layout.preferredWidth: root.railWidth
            Layout.fillHeight: true
            spacing: 0

            Repeater {
                model: root.vertical ? root.tabs : []

                delegate: Controls.TabButton {
                    required property int index
                    required property var modelData

                    text: root.titleOf(modelData)
                    enabled: root.enabledOf(modelData)
                    checked: index === root.currentIndex
                    Layout.fillWidth: true
                    onClicked: root.select(index)
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Controls.TabBar {
                id: tabBar
                visible: !root.vertical
                Layout.fillWidth: true
                currentIndex: root.currentIndex

                onCurrentIndexChanged: {
                    if (!root.vertical && currentIndex !== root.currentIndex)
                        root.select(currentIndex);
                }

                Repeater {
                    model: root.vertical ? [] : root.tabs

                    delegate: Controls.TabButton {
                        required property int index
                        required property var modelData

                        text: root.titleOf(modelData)
                        enabled: root.enabledOf(modelData)
                        onClicked: root.select(index)
                    }
                }
            }

            Controls.Frame {
                Layout.fillWidth: true
                Layout.fillHeight: true
                padding: 0

                contentItem: StackLayout {
                    id: stack
                    currentIndex: root.tabs.length ? root.currentIndex : -1

                    Repeater {
                        model: root.tabs

                        delegate: Loader {
                            required property var modelData

                            active: root.keepPagesAlive || StackLayout.isCurrentItem
                            sourceComponent: root.pageOf(modelData)
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                        }
                    }
                }
            }
        }
    }
}
