import QtQuick

import qs.services

QtObject {
    id: root

    property string name: ""
    property bool visible: true
    property int z: 0
    property color color: Config.colors.blue
    property real lineWidth: 1.6
    property var colorAt: null
    property var collector: null
    property int revision: 0

    signal dataChanged
    signal configChanged

    function _markDataChanged() {
        root.revision++;
        root.dataChanged();
    }

    function _markConfigChanged() {
        root.revision++;
        root.configChanged();
    }

    Connections {
        target: root.collector
        enabled: root.collector !== null

        function onCollected() {
            root._markDataChanged();
        }
    }

    onVisibleChanged: root._markConfigChanged()
    onZChanged: root._markConfigChanged()
    onColorChanged: root._markConfigChanged()
    onColorAtChanged: root._markConfigChanged()
    onCollectorChanged: root._markDataChanged()
}
