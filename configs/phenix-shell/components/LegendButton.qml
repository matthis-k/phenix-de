import QtQuick
import QtQuick.Layouts

import qs.services

ActionButton {
    id: root

    property var graphView: null
    property string seriesName: ""
    property var seriesFilter: null
    property string accessibleLabel: ""
    required property color color

    default property alias content: contentRow.children

    property bool checked: true
    readonly property bool effectiveChecked: checked === undefined ? true : checked
    readonly property var visibilityRevision: graphView && graphView.visibilityRevision !== undefined
        ? graphView.visibilityRevision
        : 0

    implicitHeight: 28
    active: root.effectiveChecked
    accentColor: root.color
    backgroundColor: root.effectiveChecked ? root.color : Config.styling.bg3
    borderWidth: root.visualFocus ? 2 : 1
    borderColor: root.visualFocus ? Config.styling.primaryAccent : root.color
    fillOpacity: root.effectiveChecked ? 0.22 : 0.08
    accessibleName: root.accessibleLabel || root.seriesName || qsTr("Graph series")
    Accessible.role: Accessible.CheckBox
    Accessible.checked: root.effectiveChecked

    function seriesNames() {
        if (!graphView)
            return [];
        if (seriesFilter)
            return graphView.seriesNames().filter(name => seriesFilter(graphView.series(name)));
        return seriesName ? [seriesName] : [];
    }

    function refreshChecked() {
        if (!graphView || !graphView.isSeriesVisible)
            return;

        const names = root.seriesNames();
        if (names.length === 0)
            return;

        root.checked = names.some(name => graphView.isSeriesVisible(name) === true);
    }

    function toggleVisibility() {
        if (!graphView)
            return;
        const names = root.seriesNames();
        if (names.length === 0)
            return;
        const currentlyVisible = names.some(name => graphView.isSeriesVisible(name) === true);
        const target = !currentlyVisible;
        graphView.batch(() => {
            names.forEach(name => graphView.setSeriesVisible(name, target));
        });
    }

    Component.onCompleted: Qt.callLater(root.refreshChecked)
    onGraphViewChanged: Qt.callLater(root.refreshChecked)
    onVisibilityRevisionChanged: Qt.callLater(root.refreshChecked)
    onSeriesNameChanged: Qt.callLater(root.refreshChecked)
    onSeriesFilterChanged: Qt.callLater(root.refreshChecked)
    onClicked: root.toggleVisibility()

    contentItem: RowLayout {
        id: contentRow

        anchors.fill: parent
        anchors.leftMargin: Config.spacing.xs
        anchors.rightMargin: Config.spacing.xs
        spacing: Config.spacing.xxs
        opacity: root.effectiveChecked ? 1 : 0.62
    }
}
