import QtQuick
import QtQuick.Layouts

import qs.services

ActionButton {
    id: root

    property var graphView: null
    property string seriesName: ""
    property var seriesFilter: null
    property string accessibleLabel: ""
    property int contentHorizontalPadding: Config.spacing.xs
    required property color color

    property bool _destroying: false

    default property alias content: contentRow.children

    checkable: true
    checked: true
    readonly property bool effectiveChecked: root.checked
    readonly property color contentColor: Config.styling.textOnAccent
    readonly property var visibilityRevision: graphView && graphView.visibilityRevision !== undefined
        ? graphView.visibilityRevision
        : 0

    implicitHeight: 28
    active: false
    accentColor: root.color
    backgroundColor: root.color
    borderWidth: root.visualFocus ? 2 : 1
    borderColor: root.visualFocus ? Config.styling.primaryAccent : root.color
    fillOpacity: 0
    accessibleName: root.accessibleLabel || root.seriesName || qsTr("Graph series")
    Accessible.role: Accessible.CheckBox
    Accessible.checked: root.effectiveChecked

    function seriesNames() {
        if (root._destroying || !root.graphView)
            return [];
        if (root.seriesFilter)
            return root.graphView.seriesNames().filter(name => root.seriesFilter(root.graphView.series(name)));
        return root.seriesName ? [root.seriesName] : [];
    }

    function refreshChecked() {
        if (root._destroying || !root.graphView || !root.graphView.isSeriesVisible)
            return;

        const names = root.seriesNames();
        if (names.length === 0)
            return;

        root.checked = names.some(name => root.graphView.isSeriesVisible(name) === true);
    }

    function scheduleRefresh() {
        if (!root._destroying)
            refreshTimer.restart();
    }

    function toggleVisibility() {
        if (root._destroying || !root.graphView)
            return;
        const names = root.seriesNames();
        if (names.length === 0)
            return;
        const currentlyVisible = names.some(name => root.graphView.isSeriesVisible(name) === true);
        const target = !currentlyVisible;
        root.graphView.batch(() => {
            names.forEach(name => root.graphView.setSeriesVisible(name, target));
        });
    }

    Component.onCompleted: root.scheduleRefresh()
    Component.onDestruction: {
        root._destroying = true;
        refreshTimer.stop();
    }

    onGraphViewChanged: root.scheduleRefresh()
    onVisibilityRevisionChanged: root.scheduleRefresh()
    onSeriesNameChanged: root.scheduleRefresh()
    onSeriesFilterChanged: root.scheduleRefresh()
    onClicked: root.toggleVisibility()

    Timer {
        id: refreshTimer

        interval: 0
        repeat: false
        onTriggered: {
            if (!root._destroying)
                root.refreshChecked();
        }
    }

    Rectangle {
        anchors.fill: parent
        z: 0.5
        visible: !root.effectiveChecked
        color: Config.styling.bg0
        opacity: 0.34
        radius: Config.styling.radius
    }

    contentItem: RowLayout {
        id: contentRow

        z: 1
        anchors.fill: parent
        anchors.leftMargin: root.contentHorizontalPadding
        anchors.rightMargin: root.contentHorizontalPadding
        spacing: Config.spacing.xxs
        opacity: 1
    }
}
