import QtQml

DashboardObservation {
    id: root

    key: "cpu"

    property real average: 0
    property var cores: []
    property int revision: 0
    property int maxPromoted: 4
    property real warningThreshold: 75
    property real criticalThreshold: 90
    property real deviationThreshold: 25

    readonly property var allRows: root.buildRows(false)
    readonly property var promotedRows: root.buildRows(true)
    readonly property var visibleRows: root.detailed ? root.allRows : root.promotedRows
    readonly property var promotedKeys: {
        const result = {};
        for (const row of root.promotedRows)
            result[row.key] = true;
        return result;
    }
    readonly property real maximum: root.allRows.reduce(function(current, row) {
        return Math.max(current, Number(row.percent || 0));
    }, 0)

    overviewExposure: root.promotedRows.length > 0
        ? DashboardObservation.Promoted
        : DashboardObservation.Summary
    severity: root.severityForPercent(root.maximum, root.warningThreshold, root.criticalThreshold)
    priority: Math.round(root.maximum)
    promotionReason: root.promotedRows.length > 0
        ? qsTr("%1 logical core(s) materially exceed aggregate CPU usage").arg(root.promotedRows.length)
        : ""

    function isOutlier(value) {
        const normalized = Number(value || 0);
        return normalized >= root.criticalThreshold
            || (normalized >= root.warningThreshold
                && normalized - Number(root.average || 0) >= root.deviationThreshold);
    }

    function buildRows(promotedOnly) {
        const _ = root.revision;
        const values = Array.isArray(root.cores) ? root.cores : [];
        const rows = [];
        for (let index = 0; index < values.length; index += 1) {
            const percent = Number(values[index] || 0);
            const promoted = root.isOutlier(percent);
            if (promotedOnly && !promoted)
                continue;
            rows.push({
                index: index,
                key: `core${index}`,
                percent: percent,
                severity: root.severityForPercent(percent, root.warningThreshold, root.criticalThreshold),
                promoted: promoted
            });
        }
        rows.sort(function(left, right) {
            if (promotedOnly && right.percent !== left.percent)
                return right.percent - left.percent;
            return left.index - right.index;
        });
        return promotedOnly ? rows.slice(0, Math.max(1, root.maxPromoted)) : rows;
    }
}
