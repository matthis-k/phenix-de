import QtQml

DashboardObservation {
    id: root

    property bool available: true
    property real primaryPercent: 0
    property real secondaryPercent: 0
    property bool secondaryEnabled: true
    property real warningThreshold: 85
    property real criticalThreshold: 90
    property string primaryLabel: ""
    property string secondaryLabel: ""

    readonly property real maximum: Math.max(
        Number(root.primaryPercent || 0),
        root.secondaryEnabled ? Number(root.secondaryPercent || 0) : 0
    )

    overviewExposure: !root.available
        ? DashboardObservation.Hidden
        : (root.maximum >= root.warningThreshold
            ? DashboardObservation.Promoted
            : DashboardObservation.Summary)
    severity: root.severityForPercent(root.maximum, root.warningThreshold, root.criticalThreshold)
    priority: Math.round(root.maximum)
    promotionReason: root.maximum >= root.warningThreshold
        ? qsTr("%1 usage requires attention").arg(
            Number(root.secondaryPercent || 0) > Number(root.primaryPercent || 0)
                ? root.secondaryLabel
                : root.primaryLabel
        )
        : ""
}
