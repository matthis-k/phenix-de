import QtQuick
import QtQuick.Layouts
import qs.services

Item {
    id: root

    property var graphView: null
    property string seriesName: ""
    property var seriesFilter: null
    required property color color

    default property alias content: contentRow.children

    property bool checked: true
    readonly property bool effectiveChecked: checked === undefined ? true : checked
    readonly property var visibilityRevision: graphView && graphView.visibilityRevision !== undefined ? graphView.visibilityRevision : 0

    implicitHeight: 20

    function seriesNames() {
        if (!graphView)
            return [];
        if (seriesFilter)
            return graphView.seriesNames().filter(n => seriesFilter(graphView.series(n)));
        return seriesName ? [seriesName] : [];
    }

    function refreshChecked() {
        if (!graphView || !graphView.isSeriesVisible)
            return;

        const names = root.seriesNames();
        if (names.length === 0)
            return;

        root.checked = names.some(n => graphView.isSeriesVisible(n) === true);
    }

    Component.onCompleted: Qt.callLater(root.refreshChecked)

    onGraphViewChanged: Qt.callLater(root.refreshChecked)
    onVisibilityRevisionChanged: Qt.callLater(root.refreshChecked)
    onSeriesNameChanged: Qt.callLater(root.refreshChecked)
    onSeriesFilterChanged: Qt.callLater(root.refreshChecked)

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 2
        anchors.bottomMargin: 2
        radius: 3
        color: root.color
        opacity: root.effectiveChecked ? 1.0 : 0.5
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const names = root.seriesNames();
            if (names.length === 0)
                return;
            const currentlyVisible = names.some(n => graphView.isSeriesVisible(n) === true);
            const target = !currentlyVisible;
            graphView.batch(() => {
                names.forEach(n => graphView.setSeriesVisible(n, target));
            });
        }
    }

    RowLayout {
        id: contentRow
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 4
    }
}
