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

    default property alias content: contentRow.children

    readonly property var visibilityRevision: graphView && graphView.visibilityRevision !== undefined
        ? graphView.visibilityRevision
        : 0
    readonly property bool effectiveChecked: {
        const _ = root.visibilityRevision;
        if (!root.graphView || !root.graphView.isSeriesVisible)
            return false;

        const names = root.seriesNames();
        return names.length > 0
            && names.some(name => root.graphView.isSeriesVisible(name) === true);
    }
    readonly property color contentColor: Config.styling.textOnAccent

    checkable: false
    checked: root.effectiveChecked

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
        if (!root.graphView)
            return [];
        if (root.seriesFilter)
            return root.graphView.seriesNames().filter(name => root.seriesFilter(root.graphView.series(name)));
        return root.seriesName ? [root.seriesName] : [];
    }

    function toggleVisibility() {
        if (!root.graphView)
            return;

        const names = root.seriesNames();
        if (names.length === 0)
            return;

        const target = !root.effectiveChecked;
        root.graphView.batch(() => {
            names.forEach(name => root.graphView.setSeriesVisible(name, target));
        });
    }

    onClicked: root.toggleVisibility()

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
