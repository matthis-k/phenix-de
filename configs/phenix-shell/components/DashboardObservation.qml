import QtQml

QtObject {
    id: root

    enum Severity {
        Normal,
        Notice,
        Warning,
        Critical
    }

    enum Exposure {
        Hidden,
        Summary,
        Promoted,
        Detailed
    }

    required property string key
    property string presentationMode: "overview"
    property int severity: DashboardObservation.Normal
    property int overviewExposure: DashboardObservation.Summary
    property string promotionReason: ""
    property int priority: 0

    readonly property bool requestedDetailed: String(root.presentationMode || "").toLowerCase() === "detailed"
    readonly property int exposure: root.overviewExposure === DashboardObservation.Hidden
        ? DashboardObservation.Hidden
        : (root.requestedDetailed ? DashboardObservation.Detailed : root.overviewExposure)
    readonly property bool shown: root.exposure !== DashboardObservation.Hidden
    readonly property bool detailed: root.exposure === DashboardObservation.Detailed
    readonly property bool promoted: root.exposure === DashboardObservation.Promoted
    readonly property bool exceptional: root.severity >= DashboardObservation.Warning

    function severityForPercent(value, warningThreshold, criticalThreshold) {
        const normalized = Number(value || 0);
        const warning = Number(warningThreshold !== undefined ? warningThreshold : 75);
        const critical = Number(criticalThreshold !== undefined ? criticalThreshold : 90);
        if (normalized >= critical)
            return DashboardObservation.Critical;
        if (normalized >= warning)
            return DashboardObservation.Warning;
        return DashboardObservation.Normal;
    }
}
