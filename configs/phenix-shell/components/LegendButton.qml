import QtQuick
import QtQuick.Layouts

import qs.services

ActionButton {
    id: root

    property var graphView: null
    property string seriesName: ""
    property var seriesFilter: null
    property string accessibleLabel: ""
    property int horizontalPadding: Config.spacing.xs
    required property color color

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

    Rectangle {
        anchors.fill: parent
        z: -0.5
        visible: !root.effectiveChecked
        color: Config.styling.bg0
        opacity: 0.38
        radius: Config.styling.radius
    }

    contentItem: RowLayout {
        id: contentRow

        anchors.fill: parent
        anchors.leftMargin: root.horizontalPadding
        anchors.rightMargin: root.horizontalPadding
        spacing: Config.spacing.xxs
        opacity: root.effectiveChecked ? 1 : 0.8
    }
}
