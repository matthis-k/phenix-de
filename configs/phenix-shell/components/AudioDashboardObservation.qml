import QtQml

DashboardObservation {
    id: root

    property var entries: []

    readonly property var allEntries: Array.isArray(root.entries) ? root.entries.slice() : []
    readonly property var promotedEntries: root.allEntries.filter(function(entry) {
        return !!entry && (entry.default === true
            || (Array.isArray(entry.streams) && entry.streams.length > 0)
            || Number(entry.volume || 0) >= 100);
    })
    readonly property var visibleEntries: root.detailed
        ? root.allEntries
        : (root.promotedEntries.length > 0 ? root.promotedEntries : root.allEntries.slice(0, 1))
    readonly property bool hasExceptionalVolume: root.allEntries.some(function(entry) {
        return Number(entry?.volume || 0) >= 100;
    })

    overviewExposure: root.allEntries.length === 0
        ? DashboardObservation.Hidden
        : (root.hasExceptionalVolume ? DashboardObservation.Promoted : DashboardObservation.Summary)
    severity: root.hasExceptionalVolume
        ? DashboardObservation.Warning
        : DashboardObservation.Normal
    priority: root.hasExceptionalVolume ? 100 : 0
    promotionReason: root.hasExceptionalVolume
        ? qsTr("One or more audio devices are at or above 100% volume")
        : ""
}
