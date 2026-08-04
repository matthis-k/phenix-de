import QtQml

DashboardObservation {
    id: root

    key: "storage"

    property var partitions: []
    property real warningThreshold: 85
    property real criticalThreshold: 95

    readonly property var allRows: Array.isArray(root.partitions) ? root.partitions.slice() : []
    readonly property var rootRows: root.allRows.filter(function(partition) {
        return String(partition?.mount || "") === "/";
    })
    readonly property var exceptionalRows: root.allRows.filter(function(partition) {
        return Number(partition?.percent || 0) >= root.warningThreshold;
    })
    readonly property var overviewRows: root.mergeRows(root.rootRows, root.exceptionalRows)
    readonly property var visibleRows: root.detailed ? root.allRows : root.overviewRows
    readonly property real maximum: root.allRows.reduce(function(current, partition) {
        return Math.max(current, Number(partition?.percent || 0));
    }, 0)

    overviewExposure: root.exceptionalRows.length > 0
        ? DashboardObservation.Promoted
        : (root.allRows.length > 0 ? DashboardObservation.Summary : DashboardObservation.Hidden)
    severity: root.severityForPercent(root.maximum, root.warningThreshold, root.criticalThreshold)
    priority: Math.round(root.maximum)
    promotionReason: root.exceptionalRows.length > 0
        ? qsTr("%1 filesystem(s) exceed %2% usage").arg(root.exceptionalRows.length).arg(root.warningThreshold)
        : ""

    function mergeRows(primary, secondary) {
        const rows = [];
        const seen = {};
        function append(partition) {
            if (!partition)
                return;
            const key = String(partition.mount || partition.device || rows.length);
            if (seen[key])
                return;
            seen[key] = true;
            rows.push(partition);
        }
        for (const partition of primary || [])
            append(partition);
        for (const partition of secondary || [])
            append(partition);
        return rows;
    }
}
