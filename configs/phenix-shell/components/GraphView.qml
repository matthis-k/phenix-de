import QtQuick
import qs.services

Item {
    id: root

    implicitWidth: 400
    implicitHeight: 180

    property var graphs: []
    property var markers: []
    property real xMarkerInterval: 0
    property var xMarkerLabel: null
    property real yMin: 0
    property real yMax: 100
    property real xWindow: 300000
    property bool active: true
    property string yLabelFormat: "%1"
    property bool showXAxis: true
    property bool showYAxis: true
    property bool showLabels: true
    property string viewportMode: "manual"
    property var viewport: ({
            minX: 0,
            maxX: 1,
            minY: 0,
            maxY: 100
        })
    property var globalBounds: ({
            minX: 0,
            maxX: 1,
            minY: 0,
            maxY: 100,
            valid: false
        })
    property var padding: ({
            top: 8,
            right: 4,
            bottom: 8,
            left: -1
        })

    property bool relativeX: true
    property var visibilityRevision: 0

    signal visibilityChanged

    property var _visibleOverrides: ({})
    property int _batchDepth: 0
    property bool _renderQueued: false
    property bool _renderPending: false
    property bool _visibilityChangedInBatch: false
    property var _dirtyReasons: ({})
    property var _connectedGraphs: []
    property var _connectedCollectors: []
    property var _plotArea: ({
            x: 0,
            y: 0,
            width: 1,
            height: 1,
            viewport: ({
                    minX: 0,
                    maxX: 1,
                    minY: 0,
                    maxY: 100
                })
        })

    function _handleGraphChanged() {
        root.requestRender("", "graph");
    }

    function _xWindow() {
        return Math.max(root.xWindow, 1);
    }

    function _disconnectGraphs() {
        const graphs = root._connectedGraphs.slice();
        for (let i = 0; i < graphs.length; i++) {
            const graph = graphs[i];
            if (graph.dataChanged)
                graph.dataChanged.disconnect(root._handleGraphChanged);
            if (graph.configChanged)
                graph.configChanged.disconnect(root._handleGraphChanged);
        }
        root._connectedGraphs = [];

        const collectors = root._connectedCollectors.slice();
        for (let i = 0; i < collectors.length; i++) {
            const collector = collectors[i];
            if (collector && collector.collected)
                collector.collected.disconnect(root._handleGraphChanged);
        }
        root._connectedCollectors = [];
    }

    function _connectGraphs() {
        root._disconnectGraphs();

        const graphs = root._graphs();
        const connectedGraphs = [];
        const connectedCollectors = [];

        for (let i = 0; i < graphs.length; i++) {
            const graph = graphs[i];
            if (!graph)
                continue;

            let connected = false;
            if (graph.dataChanged) {
                graph.dataChanged.connect(root._handleGraphChanged);
                connected = true;
            }
            if (graph.configChanged) {
                graph.configChanged.connect(root._handleGraphChanged);
                connected = true;
            }
            if (connected)
                connectedGraphs.push(graph);

            if (!graph.dataChanged && graph.collector && graph.collector.collected) {
                graph.collector.collected.connect(root._handleGraphChanged);
                connectedCollectors.push(graph.collector);
            }
        }

        root._connectedGraphs = connectedGraphs;
        root._connectedCollectors = connectedCollectors;
    }

    function _validNumber(value) {
        return typeof value === "number" && isFinite(value);
    }

    function _resolveName(nameOrIndex) {
        if (typeof nameOrIndex === "number")
            return root.seriesNames()[nameOrIndex] || "";
        return String(nameOrIndex || "");
    }

    function _graph(name) {
        const graphs = root._graphs();
        for (let i = 0; i < graphs.length; i++) {
            const item = graphs[i];
            if (item && item.name === name)
                return item;
        }
        return null;
    }

    function _graphs() {
        const result = [];
        for (let i = 0; i < root.graphs.length; i++)
            result.push(root.graphs[i]);
        return result;
    }

    function _series(name) {
        return root._graph(name);
    }

    function _applyVisibleOverrides() {
        const graphs = root._graphs();
        for (let i = 0; i < graphs.length; i++) {
            const graph = graphs[i];
            if (graph && graph.name && root._visibleOverrides[graph.name] !== undefined)
                graph.visible = root._visibleOverrides[graph.name];
        }
    }

    function _seriesUsesCollector(series) {
        return !!(series && series.collector && series.collector.calculate);
    }

    function _compareNames(left, right) {
        const leftSeries = root._series(left);
        const rightSeries = root._series(right);
        const leftZ = leftSeries && leftSeries.z !== undefined ? leftSeries.z : 0;
        const rightZ = rightSeries && rightSeries.z !== undefined ? rightSeries.z : 0;
        if (leftZ !== rightZ)
            return leftZ - rightZ;
        return String(left).localeCompare(String(right));
    }

    function requestRender(graphName, reason) {
        const key = graphName || "view";
        const next = Object.assign({}, root._dirtyReasons);
        next[key] = reason || true;
        root._dirtyReasons = next;
        root._renderPending = true;

        if (!root.active)
            return;

        if (root._batchDepth > 0 || root._renderQueued)
            return;

        root._renderQueued = true;
        renderScheduler.restart();
    }

    function notifyVisibilityChanged() {
        root.visibilityRevision = (root.visibilityRevision || 0) + 1;
        root.visibilityChanged();
    }

    function batch(fn) {
        root._batchDepth++;
        try {
            if (fn)
                fn();
        } finally {
            root._batchDepth--;
            if (root._batchDepth === 0 && root._visibilityChangedInBatch) {
                root._visibilityChangedInBatch = false;
                root.notifyVisibilityChanged();
            }
            if (root._batchDepth === 0 && root._renderPending)
                root.requestRender("", "batch");
        }
    }

    function seriesNames() {
        const names = {};
        const graphs = root._graphs();
        for (let i = 0; i < graphs.length; i++) {
            if (graphs[i] && graphs[i].name)
                names[String(graphs[i].name)] = true;
        }

        return Object.keys(names).sort((left, right) => String(left).localeCompare(String(right)));
    }

    function renderNames() {
        return root.seriesNames().sort(root._compareNames);
    }

    function series(nameOrIndex) {
        const name = root._resolveName(nameOrIndex);
        return root._graph(name);
    }

    function currentValue(nameOrIndex) {
        const item = root.series(nameOrIndex);
        const points = root._seriesPoints(item, root._plotArea.viewport);
        return points.length > 0 ? Math.round(points[points.length - 1].y) : 0;
    }

    function isSeriesVisible(nameOrIndex) {
        const name = root._resolveName(nameOrIndex);
        if (!name)
            return false;

        const item = root._series(name);
        return item ? item.visible !== false : false;
    }

    function setSeriesVisible(nameOrIndex, visible) {
        const name = root._resolveName(nameOrIndex);
        if (!name)
            return;

        const item = root._series(name);
        if (!item)
            return;

        const enabled = !!visible;
        const next = Object.assign({}, root._visibleOverrides);
        next[name] = enabled;
        root._visibleOverrides = next;
        item.visible = enabled;
        if (root._batchDepth > 0)
            root._visibilityChangedInBatch = true;
        else
            root.notifyVisibilityChanged();
        root.requestRender(name, "visibility");
    }

    function toggleSeries(nameOrIndex) {
        const name = root._resolveName(nameOrIndex);
        if (!name)
            return;

        root.setSeriesVisible(name, !root.isSeriesVisible(name));
    }

    function _collectorPoints(series, view) {
        if (!root._seriesUsesCollector(series))
            return [];
        const result = series.collector.calculate(view || root.viewport, series.name) || {};
        return result.points || [];
    }

    function _seriesPoints(series, view) {
        if (!series)
            return [];
        if (root._seriesUsesCollector(series))
            return root._collectorPoints(series, view);
        return [];
    }

    function _extendBounds(bounds, point) {
        if (!point)
            return bounds;
        if (!bounds.valid) {
            bounds.minX = point.x;
            bounds.maxX = point.x;
            bounds.minY = point.y;
            bounds.maxY = point.y;
            bounds.valid = true;
            return bounds;
        }
        bounds.minX = Math.min(bounds.minX, point.x);
        bounds.maxX = Math.max(bounds.maxX, point.x);
        bounds.minY = Math.min(bounds.minY, point.y);
        bounds.maxY = Math.max(bounds.maxY, point.y);
        return bounds;
    }

    function _computeGlobalBounds(fallbackMaxX) {
        const bounds = {
            minX: 0,
            maxX: 1,
            minY: root.yMin,
            maxY: root.yMax,
            valid: false
        };
        const names = root.seriesNames();
        const entries = [];
        let maxX = null;

        for (let n = 0; n < names.length; n++) {
            if (!root.isSeriesVisible(names[n]))
                continue;

            const series = root.series(names[n]);
            if (!series)
                continue;

            const collector = root._seriesUsesCollector(series) ? series.collector : null;
            const collectorBounds = collector && collector.rawBounds && collector.rawBounds.valid ? collector.rawBounds : null;
            if (collectorBounds && (maxX === null || collectorBounds.maxX > maxX))
                maxX = collectorBounds.maxX;

            const rawData = root._seriesPoints(series, root.viewport);
            const points = [];
            for (let i = 0; i < rawData.length; i++) {
                const point = rawData[i];
                if (!point)
                    continue;
                points.push(point);
                if (!collectorBounds && (maxX === null || point.x > maxX))
                    maxX = point.x;
            }
            entries.push({
                points: points,
                viewReady: !!collector
            });
        }

        const resolvedMaxX = maxX !== null ? maxX : fallbackMaxX;
        const windowStart = root.relativeX ? (resolvedMaxX - root._xWindow()) : 0;

        for (let n = 0; n < entries.length; n++) {
            const entry = entries[n];
            const points = entry.points;
            for (let i = 0; i < points.length; i++) {
                const point = points[i];
                if (root.relativeX && !entry.viewReady && (point.x < windowStart || point.x > resolvedMaxX))
                    continue;
                root._extendBounds(bounds, point);
            }
        }

        if (!bounds.valid) {
            bounds.minX = root.relativeX ? windowStart : 0;
            bounds.maxX = root.relativeX ? resolvedMaxX : 1;
            bounds.minY = root.yMin;
            bounds.maxY = root.yMax;
        } else if (root.relativeX) {
            bounds.minX = windowStart;
            bounds.maxX = resolvedMaxX;
        }
        return bounds;
    }

    function _currentViewport() {
        if (root.relativeX && !(root.viewport && root.viewport.manual === true)) {
            const sourceMaxX = root.globalBounds.valid ? root.globalBounds.maxX : root.viewport.maxX;
            const width = root._xWindow();
            return {
                minX: 0,
                maxX: width,
                minY: root.yMin,
                maxY: root.yMax,
                sourceMinX: sourceMaxX - width,
                sourceMaxX: sourceMaxX
            };
        }

        if (root.viewportMode === "auto") {
            const bounds = root.globalBounds.valid ? root.globalBounds : root._computeGlobalBounds(root.viewport.maxX);
            const xPad = Math.max(1, (bounds.maxX - bounds.minX) * 0.02);
            const yPad = Math.max(1, (bounds.maxY - bounds.minY) * 0.08);
            return {
                minX: bounds.minX - xPad,
                maxX: bounds.maxX + xPad,
                minY: bounds.minY - yPad,
                maxY: bounds.maxY + yPad
            };
        }

        if (root.viewport && root.viewport.manual === true)
            return root.viewport;

        return {
            minX: root.viewport.minX,
            maxX: root.viewport.maxX,
            minY: root.yMin,
            maxY: root.yMax
        };
    }

    function toScreen(x, y) {
        const area = root._plotArea;
        const view = area.viewport;
        const xRange = Math.max(1, view.maxX - view.minX);
        const yRange = Math.max(1, view.maxY - view.minY);
        return {
            x: area.x + ((x - view.minX) / xRange) * area.width,
            y: area.y + area.height - ((y - view.minY) / yRange) * area.height
        };
    }

    onGraphsChanged: {
        root._applyVisibleOverrides();
        root._connectGraphs();
        root.requestRender("", "graphs");
        visibilityNotifier.restart();
    }
    onMarkersChanged: root.requestRender("", "markers")
    onViewportChanged: root.requestRender("", "viewport")
    onViewportModeChanged: root.requestRender("", "viewport")
    onShowXAxisChanged: root.requestRender("", "axis")
    onShowYAxisChanged: root.requestRender("", "axis")
    onShowLabelsChanged: root.requestRender("", "labels")

    Canvas {
        id: canvas
        anchors.fill: parent
        anchors.margins: 4

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();

            const w = width;
            const h = height;
            root.globalBounds = root._computeGlobalBounds(root.viewport.maxX);
            const view = root._currentViewport();

            ctx.font = "10px sans-serif";
            const padTop = root.padding.top !== undefined ? root.padding.top : 8;
            const markerLabelSpace = root.showLabels && root.xMarkerLabel ? 14 : 0;
            const padBottom = (root.padding.bottom !== undefined ? root.padding.bottom : 8) + markerLabelSpace;
            const padRight = root.padding.right !== undefined ? root.padding.right : 4;
            const padLeft = root.padding.left >= 0 ? root.padding.left : (root.showLabels ? ctx.measureText(root.yLabelFormat.arg(Math.round(view.maxY))).width + 8 : 4);
            const graphW = Math.max(1, w - padLeft - padRight);
            const graphH = Math.max(1, h - padTop - padBottom);
            const yRange = Math.max(1, view.maxY - view.minY);
            const xRange = Math.max(1, view.maxX - view.minX);
            root._plotArea = {
                x: padLeft,
                y: padTop,
                width: graphW,
                height: graphH,
                viewport: view
            };

            ctx.fillStyle = Config.colors.surface0;
            ctx.fillRect(padLeft, padTop, graphW, graphH);

            if (root.showYAxis) {
                ctx.strokeStyle = Config.colors.overlay0;
                ctx.lineWidth = 1;
                ctx.fillStyle = Config.styling.text0;
                ctx.textAlign = "right";
                ctx.textBaseline = "middle";

                for (let i = 0; i <= 5; i++) {
                    const val = view.minY + (yRange * i / 5);
                    const y = padTop + graphH - ((val - view.minY) / yRange) * graphH;
                    ctx.beginPath();
                    ctx.moveTo(padLeft, y);
                    ctx.lineTo(w - padRight, y);
                    ctx.stroke();
                    if (root.showLabels)
                        ctx.fillText(root.yLabelFormat.arg(Math.round(val)), padLeft - 4, y);
                }
            }

            if (root.showXAxis) {
                ctx.strokeStyle = Config.colors.overlay0;
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.moveTo(padLeft, padTop + graphH);
                ctx.lineTo(w - padRight, padTop + graphH);
                ctx.stroke();
            }

            if (root.xMarkerInterval > 0) {
                const firstX = Math.ceil(view.minX / root.xMarkerInterval) * root.xMarkerInterval;
                ctx.strokeStyle = Config.colors.overlay1;
                ctx.lineWidth = 1;
                ctx.globalAlpha = 0.45;
                for (let xValue = firstX; xValue <= view.maxX; xValue += root.xMarkerInterval) {
                    const x = padLeft + ((xValue - view.minX) / xRange) * graphW;
                    ctx.beginPath();
                    ctx.moveTo(x, padTop);
                    ctx.lineTo(x, padTop + graphH);
                    ctx.stroke();
                    if (root.showLabels && root.xMarkerLabel) {
                        const label = root.xMarkerLabel(xValue, view);
                        if (label) {
                            ctx.fillStyle = Config.styling.text2;
                            ctx.textAlign = "center";
                            ctx.textBaseline = "top";
                            ctx.fillText(label, x, padTop + graphH + 4);
                        }
                    }
                }
                ctx.globalAlpha = 1;
            }

            const names = root.renderNames();
            for (let n = 0; n < names.length; n++) {
                const item = root.series(names[n]);
                const data = root._seriesPoints(item, view);
                if (!item || !root.isSeriesVisible(names[n]) || data.length === 0)
                    continue;

                ctx.strokeStyle = item.color || Config.colors.blue;
                ctx.lineWidth = item.lineWidth !== undefined ? item.lineWidth : 1.6;
                ctx.beginPath();

                let drawn = 0;
                let lastX = 0;
                let lastY = 0;
                let lastViewPoint = null;

                for (let i = 0; i < data.length; i++) {
                    const viewPoint = data[i];
                    if (!viewPoint || viewPoint.x < view.minX || viewPoint.x > view.maxX)
                        continue;

                    const color = item.colorAt ? item.colorAt(viewPoint.x, viewPoint.y, i) : null;
                    if (color)
                        ctx.strokeStyle = color;

                    const x = padLeft + ((viewPoint.x - view.minX) / xRange) * graphW;
                    const y = padTop + graphH - ((Math.max(view.minY, Math.min(view.maxY, viewPoint.y)) - view.minY) / yRange) * graphH;

                    if (drawn === 0) {
                        ctx.moveTo(x, y);
                    } else {
                        const collector = root._seriesUsesCollector(item) ? item.collector : null;
                        const connect = collector ? collector.connects(lastViewPoint, viewPoint) : true;
                        if (connect) {
                            ctx.lineTo(x, y);
                        } else {
                            ctx.stroke();
                            ctx.beginPath();
                            ctx.moveTo(x, y);
                            drawn = 0;
                        }
                    }

                    lastX = x;
                    lastY = y;
                    lastViewPoint = viewPoint;
                    drawn++;
                }

                if (drawn === 1)
                    ctx.arc(lastX, lastY, 2, 0, Math.PI * 2);
                ctx.stroke();
            }

            const markers = (root.markers || []).slice().sort((left, right) => (left.z || 0) - (right.z || 0));
            for (let i = 0; i < markers.length; i++) {
                const marker = markers[i];
                if (!marker || marker.visible === false)
                    continue;

                ctx.strokeStyle = marker.color || Config.colors.overlay2;
                ctx.fillStyle = marker.color || Config.colors.overlay2;
                ctx.lineWidth = 1;

                if (marker.type === "xLine" && root._validNumber(marker.x)) {
                    const p = root.toScreen(marker.x, view.minY);
                    ctx.beginPath();
                    ctx.moveTo(p.x, padTop);
                    ctx.lineTo(p.x, padTop + graphH);
                    ctx.stroke();
                } else if (marker.type === "yLine" && root._validNumber(marker.y)) {
                    const p = root.toScreen(view.minX, marker.y);
                    ctx.beginPath();
                    ctx.moveTo(padLeft, p.y);
                    ctx.lineTo(padLeft + graphW, p.y);
                    ctx.stroke();
                } else if (marker.type === "point" && root._validNumber(marker.x) && root._validNumber(marker.y)) {
                    const p = root.toScreen(marker.x, marker.y);
                    ctx.beginPath();
                    ctx.arc(p.x, p.y, 2.5, 0, Math.PI * 2);
                    ctx.fill();
                } else if (marker.type === "rangeX" && root._validNumber(marker.min) && root._validNumber(marker.max)) {
                    const left = root.toScreen(marker.min, view.minY).x;
                    const right = root.toScreen(marker.max, view.minY).x;
                    ctx.globalAlpha = 0.14;
                    ctx.fillRect(Math.min(left, right), padTop, Math.abs(right - left), graphH);
                    ctx.globalAlpha = 1;
                } else if (marker.type === "rangeY" && root._validNumber(marker.min) && root._validNumber(marker.max)) {
                    const top = root.toScreen(view.minX, marker.max).y;
                    const bottom = root.toScreen(view.minX, marker.min).y;
                    ctx.globalAlpha = 0.14;
                    ctx.fillRect(padLeft, Math.min(top, bottom), graphW, Math.abs(bottom - top));
                    ctx.globalAlpha = 1;
                }

                if (root.showLabels && marker.label && marker.labelVisible !== false) {
                    const labelX = root._validNumber(marker.x) ? root.toScreen(marker.x, view.minY).x + 4 : padLeft + 4;
                    const labelY = root._validNumber(marker.y) ? root.toScreen(view.minX, marker.y).y - 4 : padTop + 12;
                    ctx.textAlign = "left";
                    ctx.textBaseline = "bottom";
                    ctx.fillText(marker.label, labelX, labelY);
                }
            }

            root._dirtyReasons = {};
            root._renderPending = false;
        }
    }

    Timer {
        id: renderScheduler
        interval: 0
        repeat: false
        onTriggered: {
            root._renderQueued = false;
            canvas.requestPaint();
        }
    }

    Timer {
        id: visibilityNotifier
        interval: 0
        repeat: false
        onTriggered: root.notifyVisibilityChanged()
    }

    onActiveChanged: root.requestRender("", "active")
    onYMinChanged: root.requestRender("", "viewport")
    onYMaxChanged: root.requestRender("", "viewport")
    onXMarkerIntervalChanged: root.requestRender("", "markers")
    onXMarkerLabelChanged: root.requestRender("", "markers")
}
