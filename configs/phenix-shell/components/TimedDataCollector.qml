import QtQuick

DataCollector {
    id: root

    property bool running: false
    property var collect: null

    connects: function (prevPoint, currPoint) {
        const prevX = prevPoint.raw && prevPoint.raw.x !== undefined ? prevPoint.raw.x : prevPoint.x;
        const currX = currPoint.raw && currPoint.raw.x !== undefined ? currPoint.raw.x : currPoint.x;
        return Math.abs(currX - prevX) < root.sampleInterval * 2;
    }

    property Timer _timer: Timer {
        running: root.running && !!root.collect
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const data = root.collect();
            if (data === null || data === undefined)
                return;
            Array.isArray(data) ? root.appendRawPoints(data) : root.appendRaw(data);
        }
    }

    onSampleIntervalChanged: _timer.interval = Math.max(100, root.sampleInterval)
    Component.onCompleted: _timer.interval = Math.max(100, root.sampleInterval)
}
