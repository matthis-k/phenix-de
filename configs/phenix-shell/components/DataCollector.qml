import QtQuick

QtObject {
    id: root

    property var rawData: []
    property var points: []
    property var bounds: emptyBounds()
    property var rawBounds: emptyBounds()
    property real xWindow: 1
    property real sampleInterval: 1
    property bool relativeX: true
    property int revision: 0

    property var retentionFilter: null
    property var viewportFilter: null
    property var mapper: null
    property var connects: function (prevPoint, currPoint) {
        return true;
    }

    property string persistFilename: ""
    property int persistEvery: 10
    property int _persistCount: 0
    signal persistReady(string filename, var data)

    signal collected(var data)
    signal calculated(var points)

    function emptyBounds() {
        return {
            minX: 0,
            maxX: 0,
            minY: 0,
            maxY: 0,
            valid: false
        };
    }

    function validNumber(value) {
        return typeof value === "number" && isFinite(value);
    }

    function sourcePoint(raw, index) {
        if (raw === null || raw === undefined)
            return null;
        if (typeof raw === "number")
            return {
                x: index,
                y: raw
            };

        const x = raw.x !== undefined ? raw.x : (raw.time !== undefined ? raw.time : index);
        const y = raw.y !== undefined ? raw.y : (raw.value !== undefined ? raw.value : 0);
        return {
            x: x,
            y: y,
            series: raw.series || raw.name || "",
            raw: raw
        };
    }

    function extendBounds(nextBounds, point) {
        if (!point || !validNumber(point.x) || !validNumber(point.y))
            return nextBounds;

        if (!nextBounds.valid) {
            nextBounds.minX = point.x;
            nextBounds.maxX = point.x;
            nextBounds.minY = point.y;
            nextBounds.maxY = point.y;
            nextBounds.valid = true;
            return nextBounds;
        }

        nextBounds.minX = Math.min(nextBounds.minX, point.x);
        nextBounds.maxX = Math.max(nextBounds.maxX, point.x);
        nextBounds.minY = Math.min(nextBounds.minY, point.y);
        nextBounds.maxY = Math.max(nextBounds.maxY, point.y);
        return nextBounds;
    }

    function calculateBounds(data) {
        let nextBounds = emptyBounds();
        for (let i = 0; i < data.length; i++)
            nextBounds = extendBounds(nextBounds, data[i]);
        return nextBounds;
    }

    function normalized(data) {
        const result = [];
        for (let i = 0; i < data.length; i++) {
            const point = sourcePoint(data[i], i);
            if (point && validNumber(point.x) && validNumber(point.y))
                result.push(point);
        }
        return result;
    }

    function defaultRetentionFilter(data) {
        const normalizedData = normalized(data);
        const bounds = calculateBounds(normalizedData);
        if (!relativeX || !bounds.valid)
            return data.slice();

        const minX = bounds.maxX - Math.max(xWindow, 1) - Math.max(sampleInterval, 1);
        const result = [];
        for (let i = 0; i < data.length; i++) {
            const point = sourcePoint(data[i], i);
            if (point && validNumber(point.x) && validNumber(point.y) && point.x >= minX && point.x <= bounds.maxX)
                result.push(data[i]);
        }
        return result;
    }

    function defaultViewportFilter(data) {
        const bounds = rawBounds.valid ? rawBounds : calculateBounds(normalized(data));
        if (!relativeX || !bounds.valid)
            return data.slice();

        const minX = bounds.maxX - Math.max(xWindow, 1) - Math.max(sampleInterval, 1);
        const result = [];
        for (let i = 0; i < data.length; i++) {
            const point = sourcePoint(data[i], i);
            if (point && validNumber(point.x) && validNumber(point.y) && point.x >= minX && point.x <= bounds.maxX)
                result.push(data[i]);
        }
        return result;
    }

    function defaultMapper(data, viewport, seriesName) {
        const bounds = rawBounds.valid ? rawBounds : calculateBounds(normalized(data));
        const sourceMinX = bounds.valid ? bounds.maxX - Math.max(xWindow, 1) : 0;
        const result = [];

        for (let i = 0; i < data.length; i++) {
            const point = sourcePoint(data[i], i);
            if (!point)
                continue;
            if (seriesName && point.series && point.series !== seriesName)
                continue;

            result.push({
                x: relativeX ? Math.max(0, point.x - sourceMinX) : point.x,
                y: point.y,
                raw: data[i]
            });
        }
        return result;
    }

    function applyRawData(data) {
        const retained = retentionFilter ? retentionFilter(data, root) : defaultRetentionFilter(data);
        rawData = retained || [];
        rawBounds = calculateBounds(normalized(rawData));
        revision++;
        collected(rawData);
        if (persistFilename) {
            _persistCount++;
            if (_persistCount >= persistEvery) {
                persistReady(persistFilename, rawData);
                _persistCount = 0;
            }
        }
    }

    function appendRaw(raw) {
        appendRawPoints([raw]);
    }

    function appendRawPoints(data) {
        applyRawData(rawData.concat(data || []));
    }

    function replaceRawData(data) {
        applyRawData(data || []);
    }

    function clear() {
        rawData = [];
        points = [];
        bounds = emptyBounds();
        rawBounds = emptyBounds();
        revision++;
        collected(rawData);
    }

    function calculate(viewport, seriesName) {
        const filtered = viewportFilter ? viewportFilter(rawData, viewport, root, seriesName) : defaultViewportFilter(rawData, viewport, seriesName);
        const mapped = mapper ? mapper(filtered || [], viewport, root, seriesName) : defaultMapper(filtered || [], viewport, seriesName);
        points = mapped || [];
        bounds = calculateBounds(points);
        calculated(points);
        return {
            points: points,
            bounds: bounds
        };
    }
}
