import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import qs.services

FocusScope {
    id: root

    property string title: ""
    property string subtitle: ""
    property Component headerAccessory: null
    property var tabSwipeTarget: null
    property var modeController: null
    property string presentationMode: "overview"
    property bool showModeSwitch: true
    property bool scrollable: false
    property bool fillHeight: false
    property int pagePadding: Config.spacing.md
    property int sectionSpacing: Config.spacing.md
    readonly property bool detailed: presentationMode === "detailed"
    default property alias content: body.data

    property bool _vimChordPending: false

    implicitWidth: 360
    implicitHeight: column.implicitHeight + pagePadding * 2
    focus: visible

    function requestPresentationMode(mode) {
        const normalized = String(mode || "").toLowerCase() === "detailed"
            ? "detailed"
            : "overview";
        if (root.modeController && root.modeController.setPresentationMode)
            root.modeController.setPresentationMode(normalized);
        else
            root.presentationMode = normalized;
    }

    function togglePresentationMode() {
        if (root.modeController && root.modeController.togglePresentationMode)
            root.modeController.togglePresentationMode();
        else
            root.requestPresentationMode(root.detailed ? "overview" : "detailed");
    }

    function focusedItem() {
        return root.Window.window ? root.Window.window.activeFocusItem : null;
    }

    function isTextEditor(item) {
        if (!item)
            return false;
        return item.echoMode !== undefined
            || (item.cursorPosition !== undefined && item.selectedText !== undefined);
    }

    function moveFocus(forward) {
        const current = root.focusedItem() || root;
        const next = current.nextItemInFocusChain(forward);
        if (!next || next === current)
            return false;
        next.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason);
        return true;
    }

    function handleVimKey(event) {
        if (event.modifiers !== Qt.NoModifier || root.isTextEditor(root.focusedItem()))
            return false;

        const key = String(event.text || "").toLowerCase();
        if (root._vimChordPending) {
            root._vimChordPending = false;
            vimChordTimer.stop();
            if (key === "o") {
                root.requestPresentationMode("overview");
                return true;
            }
            if (key === "d") {
                root.requestPresentationMode("detailed");
                return true;
            }
        }

        switch (key) {
        case "g":
            root._vimChordPending = true;
            vimChordTimer.restart();
            return true;
        case "j":
            return root.moveFocus(true);
        case "k":
            return root.moveFocus(false);
        case "h":
            return root.modeController && root.modeController.stepDashboardTab
                ? root.modeController.stepDashboardTab(-1)
                : false;
        case "l":
            return root.modeController && root.modeController.stepDashboardTab
                ? root.modeController.stepDashboardTab(1)
                : false;
        case "d":
            root.togglePresentationMode();
            return true;
        default:
            return false;
        }
    }

    Keys.priority: Keys.AfterItem
    Keys.onPressed: function(event) {
        if (root.handleVimKey(event))
            event.accepted = true;
    }

    Timer {
        id: vimChordTimer
        interval: 750
        repeat: false
        onTriggered: root._vimChordPending = false
    }

    Flickable {
        id: flick
        anchors.fill: parent
        interactive: root.scrollable
        flickableDirection: Flickable.VerticalFlick
        contentWidth: width
        contentHeight: viewport.height
        clip: true

        ScrollBar.vertical: ScrollBar {
            policy: root.scrollable ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        }

        Item {
            id: viewport

            width: flick.width
            height: root.scrollable
                ? Math.max(column.implicitHeight + root.pagePadding * 2, flick.height)
                : flick.height

            ColumnLayout {
                id: column

                anchors {
                    fill: parent
                    margins: root.pagePadding
                }
                spacing: root.sectionSpacing

                DashboardPageHeader {
                    id: header
                    Layout.fillWidth: true
                    visible: root.title !== "" || root.subtitle !== "" || root.headerAccessory !== null || root.showModeSwitch
                    title: root.title
                    subtitle: root.subtitle
                    accessory: composedHeaderAccessory
                }

                ColumnLayout {
                    id: body
                    Layout.fillWidth: true
                    Layout.fillHeight: root.fillHeight
                    Layout.alignment: Qt.AlignTop
                    spacing: root.sectionSpacing
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: !root.fillHeight
                }
            }
        }
    }

    Component {
        id: composedHeaderAccessory

        RowLayout {
            spacing: Config.spacing.xs

            Loader {
                active: root.headerAccessory !== null
                sourceComponent: root.headerAccessory
                Layout.preferredWidth: item ? item.implicitWidth : 0
                Layout.preferredHeight: item ? item.implicitHeight : 0
                Layout.alignment: Qt.AlignVCenter
            }

            DashboardModeSwitch {
                visible: root.showModeSwitch
                mode: root.presentationMode
                onModeRequested: mode => root.requestPresentationMode(mode)
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
