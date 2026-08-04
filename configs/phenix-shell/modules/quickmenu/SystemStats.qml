pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.services
import qs.services as Services
import qs.components

DashboardPage {
    id: root

    title: "System stats"
    subtitle: root.detailed
        ? qsTr("Per-core, memory, GPU, storage, and network telemetry")
        : qsTr("Current resource usage with abnormal observations promoted")
    scrollable: true

    readonly property var cpuCoreColors: [Config.colors.green, Config.colors.yellow, Config.colors.red, Config.colors.maroon, Config.colors.peach, Config.colors.mauve, Config.colors.pink, Config.colors.flamingo, Config.colors.rosewater]
    readonly property color ramColor: Config.colors.blue
    readonly property color swapColor: Config.colors.mauve
    readonly property color gpuUsageColor: Config.colors.blue
    readonly property color gpuVramColor: Config.colors.mauve

    CpuDashboardObservation {
        id: cpuObservation
        presentationMode: root.presentationMode
        average: Services.Stats.cpuPercent
        cores: Services.Stats.cpuCorePercents
        revision: Services.Stats.graphRevision
    }

    UsageDashboardObservation {
        id: memoryObservation
        key: "memory"
        presentationMode: root.presentationMode
        primaryLabel: qsTr("RAM")
        secondaryLabel: qsTr("Swap")
        primaryPercent: Services.Stats.memoryPercent
        secondaryPercent: Services.Stats.swapPercent
        secondaryEnabled: Services.Stats.swapTotalMiB > 0
        warningThreshold: 85
        criticalThreshold: 90
    }

    UsageDashboardObservation {
        id: gpuObservation
        key: "gpu"
        presentationMode: root.presentationMode
        available: Services.Stats.gpuAvailable
        primaryLabel: qsTr("GPU compute")
        secondaryLabel: qsTr("VRAM")
        primaryPercent: Services.Stats.gpuUtilPercent
        secondaryPercent: Services.Stats.gpuVramPercent
        warningThreshold: 85
        criticalThreshold: 90
    }

    StorageDashboardObservation {
        id: storageObservation
        presentationMode: root.presentationMode
        partitions: Services.Stats.diskPartitions
    }

    DashboardObservation {
        id: networkObservation
        key: "network-throughput"
        presentationMode: root.presentationMode
        overviewExposure: Services.Stats.primaryInterface !== ""
            ? DashboardObservation.Summary
            : DashboardObservation.Hidden
    }

    function percentColor(percent, normalColor, warningThreshold, criticalThreshold) {
        const value = Number(percent || 0);
        const warning = Number(warningThreshold !== undefined ? warningThreshold : 75);
        const critical = Number(criticalThreshold !== undefined ? criticalThreshold : 90);
        if (value >= critical)
            return Config.styling.critical;
        if (value >= warning)
            return Config.styling.warning;
        return normalColor;
    }

    function observationColor(observation, normalColor) {
        switch (observation.severity) {
        case DashboardObservation.Critical:
            return Config.styling.critical;
        case DashboardObservation.Warning:
            return Config.styling.warning;
        case DashboardObservation.Notice:
            return Config.styling.primaryAccent;
        case DashboardObservation.Normal:
        default:
            return normalColor;
        }
    }

    function cpuGraphSeries() {
        const _ = Services.Stats.graphRevision;
        return Services.Stats.calculateCpuGraphSeries().map(series => Object.assign({}, series, {
                color: series.name === "avg" ? Config.colors.blue : root.cpuCoreColors[parseInt(String(series.name).replace("core", "")) % root.cpuCoreColors.length],
                lineWidth: series.name === "avg" ? 2.5 : 1.2,
                visible: series.name === "avg"
                    || cpuObservation.detailed
                    || cpuObservation.promotedKeys[series.name] === true
            }));
    }

    function memoryGraphSeries() {
        const _ = Services.Stats.graphRevision;
        return Services.Stats.calculateMemoryGraphSeries().map(series => Object.assign({}, series, {
                color: series.name === "RAM" ? root.ramColor : root.swapColor
            }));
    }

    function gpuGraphSeries() {
        const _ = Services.Stats.graphRevision;
        return Services.Stats.calculateGpuGraphSeries().map(series => Object.assign({}, series, {
                color: series.name === "VRAM" ? root.gpuVramColor : root.gpuUsageColor,
                z: series.name === "VRAM" ? 0 : 1
            }));
    }

    AdaptiveDashboardSection {
        observation: cpuObservation
        title: qsTr("CPU usage")
        subtitle: cpuObservation.detailed
            ? qsTr("Average and every logical core over time")
            : (cpuObservation.promoted
                ? qsTr("%1 hot core(s) promoted").arg(cpuObservation.promotedRows.length)
                : qsTr("Current aggregate load"))
        iconName: "processor-symbolic"
        iconColor: root.observationColor(cpuObservation, Config.colors.blue)
        titleColor: cpuObservation.promoted
            ? root.observationColor(cpuObservation, Config.colors.blue)
            : Config.styling.text0
        subtitleColor: cpuObservation.promoted
            ? root.observationColor(cpuObservation, Config.colors.blue)
            : Config.styling.text2
        subtitleBold: cpuObservation.promoted
        collapsible: true
        summary: Component {
            HeaderMetric {
                label: qsTr("AVG")
                value: Services.Stats.cpuPercent
                metricColor: root.observationColor(cpuObservation, Config.colors.blue)
            }
        }
        overviewDelegate: Component { CpuOverview {} }
        promotedDelegate: Component { CpuOverview {} }
        detailedDelegate: Component { CpuTelemetry {} }
        Layout.fillWidth: true
    }

    AdaptiveDashboardSection {
        observation: memoryObservation
        title: qsTr("Memory")
        subtitle: memoryObservation.detailed
            ? qsTr("Allocation and usage history")
            : (memoryObservation.promoted
                ? memoryObservation.promotionReason
                : qsTr("Current RAM and swap pressure"))
        iconName: "computer-symbolic"
        iconColor: root.observationColor(memoryObservation, root.ramColor)
        titleColor: memoryObservation.promoted
            ? root.observationColor(memoryObservation, root.ramColor)
            : Config.styling.text0
        subtitleColor: memoryObservation.promoted
            ? root.observationColor(memoryObservation, root.ramColor)
            : Config.styling.text2
        subtitleBold: memoryObservation.promoted
        collapsible: true
        summary: Component {
            RowLayout {
                spacing: Config.spacing.xs
                HeaderMetric {
                    label: qsTr("RAM")
                    value: Services.Stats.memoryPercent
                    metricColor: root.percentColor(Services.Stats.memoryPercent, root.ramColor, 85, 90)
                }
                HeaderMetric {
                    label: qsTr("SWAP")
                    value: Services.Stats.swapTotalMiB > 0 ? Services.Stats.swapPercent : 0
                    metricColor: root.percentColor(Services.Stats.swapPercent, root.swapColor, 85, 90)
                }
            }
        }
        overviewDelegate: Component { MemoryOverview {} }
        promotedDelegate: Component { MemoryOverview {} }
        detailedDelegate: Component { MemoryTelemetry {} }
        Layout.fillWidth: true
    }

    AdaptiveDashboardSection {
        observation: gpuObservation
        title: qsTr("GPU")
        subtitle: gpuObservation.detailed
            ? qsTr("Compute, VRAM, and usage history")
            : (gpuObservation.promoted
                ? gpuObservation.promotionReason
                : qsTr("Current compute and VRAM pressure"))
        iconName: "video-display-symbolic"
        iconColor: root.observationColor(gpuObservation, root.gpuUsageColor)
        titleColor: gpuObservation.promoted
            ? root.observationColor(gpuObservation, root.gpuUsageColor)
            : Config.styling.text0
        subtitleColor: gpuObservation.promoted
            ? root.observationColor(gpuObservation, root.gpuUsageColor)
            : Config.styling.text2
        subtitleBold: gpuObservation.promoted
        collapsible: true
        summary: Component {
            RowLayout {
                spacing: Config.spacing.xs
                HeaderMetric {
                    label: qsTr("GPU")
                    value: Services.Stats.gpuUtilPercent
                    metricColor: root.percentColor(Services.Stats.gpuUtilPercent, root.gpuUsageColor, 85, 90)
                }
                HeaderMetric {
                    label: qsTr("VRAM")
                    value: Services.Stats.gpuVramPercent
                    metricColor: root.percentColor(Services.Stats.gpuVramPercent, root.gpuVramColor, 85, 90)
                }
            }
        }
        overviewDelegate: Component { GpuOverview {} }
        promotedDelegate: Component { GpuOverview {} }
        detailedDelegate: Component { GpuTelemetry {} }
        Layout.fillWidth: true
    }

    AdaptiveDashboardSection {
        observation: storageObservation
        title: qsTr("Storage")
        subtitle: storageObservation.detailed
            ? qsTr("Every mounted filesystem")
            : (storageObservation.promoted
                ? storageObservation.promotionReason
                : qsTr("Current root filesystem usage"))
        iconName: "drive-harddisk-symbolic"
        iconColor: root.observationColor(storageObservation, Config.colors.peach)
        titleColor: storageObservation.promoted
            ? root.observationColor(storageObservation, Config.colors.peach)
            : Config.styling.text0
        subtitleColor: storageObservation.promoted
            ? root.observationColor(storageObservation, Config.colors.peach)
            : Config.styling.text2
        subtitleBold: storageObservation.promoted
        collapsible: true
        summary: Component {
            HeaderMetric {
                label: "/"
                value: Services.Stats.rootDiskPercent
                metricColor: root.percentColor(Services.Stats.rootDiskPercent, Config.colors.peach, 75, 90)
            }
        }
        overviewDelegate: Component {
            StorageOverview { rows: storageObservation.rootRows }
        }
        promotedDelegate: Component {
            StorageOverview { rows: storageObservation.visibleRows }
        }
        detailedDelegate: Component {
            StorageTable { rows: storageObservation.visibleRows }
        }
        Layout.fillWidth: true
    }

    AdaptiveDashboardSection {
        observation: networkObservation
        title: qsTr("Network throughput")
        iconName: "network-transmit-receive-symbolic"
        iconColor: Config.colors.green
        collapsible: true
        summary: Component {
            RowLayout {
                spacing: Config.spacing.xs
                Text {
                    text: `↓ ${Services.Stats.formatRate(Services.Stats.rxBytesPerSecond)}`
                    color: Config.colors.green
                    font.pixelSize: 12
                    font.bold: true
                    font.family: "monospace"
                }
                Text {
                    text: `↑ ${Services.Stats.formatRate(Services.Stats.txBytesPerSecond)}`
                    color: Config.colors.peach
                    font.pixelSize: 12
                    font.bold: true
                    font.family: "monospace"
                }
            }
        }
        detailedDelegate: Component {
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Config.spacing.xs

                InfoRow {
                    iconName: "go-down-symbolic"
                    iconColor: Config.colors.green
                    labelColor: Config.colors.green
                    label: qsTr("Download")
                    value: Services.Stats.formatRate(Services.Stats.rxBytesPerSecond)
                    valueColor: Config.colors.green
                    Layout.fillWidth: true
                }

                InfoRow {
                    iconName: "go-up-symbolic"
                    iconColor: Config.colors.peach
                    labelColor: Config.colors.peach
                    label: qsTr("Upload")
                    value: Services.Stats.formatRate(Services.Stats.txBytesPerSecond)
                    valueColor: Config.colors.peach
                    Layout.fillWidth: true
                }
            }
        }
        Layout.fillWidth: true
    }

    component MetricGrid: GridLayout {
        Layout.fillWidth: true
        columns: Math.max(1, Math.floor((width + columnSpacing) / (108 + columnSpacing)))
        columnSpacing: Config.spacing.xs
        rowSpacing: Config.spacing.xs
        uniformCellWidths: true
    }

    component CpuOverview: MetricGrid {
        RadialMetric {
            Layout.fillWidth: true
            label: qsTr("Average")
            iconName: "processor-symbolic"
            percent: Services.Stats.cpuPercent
            accentColor: root.percentColor(Services.Stats.cpuPercent, Config.colors.blue, 75, 90)
            detail: qsTr("aggregate")
            emphasized: cpuObservation.promoted
        }

        Repeater {
            model: cpuObservation.promotedRows

            delegate: RadialMetric {
                required property var modelData
                Layout.fillWidth: true
                label: qsTr("Core %1").arg(modelData.index)
                iconName: "processor-symbolic"
                percent: Number(modelData.percent || 0)
                accentColor: modelData.severity === DashboardObservation.Critical
                    ? Config.styling.critical
                    : Config.styling.warning
                detail: qsTr("outlier")
                emphasized: true
            }
        }
    }

    component MemoryOverview: MetricGrid {
        RadialMetric {
            Layout.fillWidth: true
            label: qsTr("RAM")
            iconName: "computer-symbolic"
            percent: Services.Stats.memoryPercent
            accentColor: root.percentColor(Services.Stats.memoryPercent, root.ramColor, 85, 90)
            detail: `${Services.Stats.memoryUsedMiB}/${Services.Stats.memoryTotalMiB} MiB`
            emphasized: Services.Stats.memoryPercent >= memoryObservation.warningThreshold
        }

        RadialMetric {
            visible: Services.Stats.swapTotalMiB > 0
            Layout.fillWidth: true
            label: qsTr("Swap")
            iconName: "drive-harddisk-symbolic"
            percent: Services.Stats.swapPercent
            accentColor: root.percentColor(Services.Stats.swapPercent, root.swapColor, 85, 90)
            detail: `${Services.Stats.swapUsedMiB}/${Services.Stats.swapTotalMiB} MiB`
            emphasized: Services.Stats.swapPercent >= memoryObservation.warningThreshold
        }
    }

    component GpuOverview: MetricGrid {
        RadialMetric {
            Layout.fillWidth: true
            label: qsTr("Compute")
            iconName: "video-display-symbolic"
            percent: Services.Stats.gpuUtilPercent
            accentColor: root.percentColor(Services.Stats.gpuUtilPercent, root.gpuUsageColor, 85, 90)
            detail: Services.Stats.gpuName
            emphasized: Services.Stats.gpuUtilPercent >= gpuObservation.warningThreshold
        }

        RadialMetric {
            Layout.fillWidth: true
            label: qsTr("VRAM")
            iconName: "video-display-symbolic"
            percent: Services.Stats.gpuVramPercent
            accentColor: root.percentColor(Services.Stats.gpuVramPercent, root.gpuVramColor, 85, 90)
            detail: `${Services.Stats.gpuVramUsedMiB}/${Services.Stats.gpuVramTotalMiB} MiB`
            emphasized: Services.Stats.gpuVramPercent >= gpuObservation.warningThreshold
        }
    }

    component StorageOverview: MetricGrid {
        id: storageGrid
        required property var rows

        Repeater {
            model: storageGrid.rows

            delegate: RadialMetric {
                required property var modelData
                Layout.fillWidth: true
                label: modelData.mount || modelData.device || qsTr("Filesystem")
                iconName: "drive-harddisk-symbolic"
                percent: Number(modelData.percent || 0)
                accentColor: root.percentColor(percent, Config.colors.peach, 75, 90)
                detail: `${modelData.usedGiB || 0}/${modelData.totalGiB || 0} GiB`
                emphasized: percent >= storageObservation.warningThreshold
            }
        }
    }

    component CpuTelemetry: ColumnLayout {
        Layout.fillWidth: true
        spacing: Config.spacing.xs

        GraphView {
            id: cpuGraph
            active: root.visible
            yMin: 0
            yMax: 100
            xWindow: 120000
            xMarkerInterval: 60000
            xMarkerLabel: (x, view) => x < view.maxX ? qsTr("%1m").arg(Math.round((view.maxX - x) / 60000)) : ""
            graphs: root.cpuGraphSeries()
            Layout.fillWidth: true
            Layout.preferredHeight: 180
            Layout.minimumHeight: 140
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Item { Layout.fillWidth: true }

            LegendButton {
                Layout.preferredWidth: 100
                Layout.alignment: Qt.AlignHCenter
                graphView: cpuGraph
                seriesName: "avg"
                color: Config.colors.blue

                Text {
                    text: qsTr("average")
                    font.pixelSize: 13
                    font.bold: true
                    color: Config.colors.base
                }
                Item { Layout.fillWidth: true }

                UsageArc {
                    implicitWidth: 14
                    implicitHeight: 14
                    percent: Services.Stats.cpuPercent
                    accentColor: Config.colors.base
                    trackColor: Config.styling.bg4
                    strokeWidth: 2
                }
            }

            LegendButton {
                Layout.preferredWidth: 100
                Layout.alignment: Qt.AlignHCenter
                graphView: cpuGraph
                seriesFilter: (series) => series.name.startsWith("core")
                color: Config.colors.overlay2

                Text {
                    Layout.fillWidth: true
                    text: qsTr("cores")
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 13
                    font.bold: true
                    color: Config.colors.base
                }
            }

            Item { Layout.fillWidth: true }
        }

        GridLayout {
            visible: cpuObservation.visibleRows.length > 0
            Layout.fillWidth: true
            columns: 4
            rowSpacing: 2
            columnSpacing: 8
            uniformCellWidths: true

            Repeater {
                model: cpuObservation.visibleRows

                delegate: LegendButton {
                    required property var modelData
                    readonly property int coreIndex: Number(modelData.index || 0)

                    Layout.fillWidth: true
                    graphView: cpuGraph
                    seriesName: `core${coreIndex}`
                    color: root.cpuCoreColors[coreIndex % root.cpuCoreColors.length]

                    Text {
                        text: `core${coreIndex}`
                        font.pixelSize: 13
                        font.bold: true
                        color: Config.colors.base
                    }
                    Item { Layout.fillWidth: true }

                    UsageArc {
                        implicitWidth: 14
                        implicitHeight: 14
                        percent: Number(modelData.percent || 0)
                        accentColor: Config.colors.base
                        trackColor: Config.styling.bg4
                        strokeWidth: 2
                    }
                }
            }
        }
    }

    component MemoryTelemetry: ColumnLayout {
        Layout.fillWidth: true
        spacing: Config.spacing.xs

        GraphView {
            active: root.visible
            yMin: 0
            yMax: 100
            xWindow: 300000
            xMarkerInterval: 60000
            xMarkerLabel: (x, view) => x < view.maxX ? qsTr("%1m").arg(Math.round((view.maxX - x) / 60000)) : ""
            graphs: root.memoryGraphSeries()
            Layout.fillWidth: true
            Layout.preferredHeight: 160
            Layout.minimumHeight: 120
        }

        StatTableHeader {}

        StatTableRow {
            label: qsTr("RAM")
            valueText: `${Services.Stats.memoryUsedMiB} / ${Services.Stats.memoryTotalMiB} MiB`
            percent: Services.Stats.memoryPercent
            rowColor: root.ramColor
            percentColor: root.percentColor(percent, root.ramColor, 85, 90)
        }

        StatTableRow {
            label: qsTr("Swap")
            valueText: Services.Stats.swapTotalMiB > 0
                ? `${Services.Stats.swapUsedMiB} / ${Services.Stats.swapTotalMiB} MiB`
                : qsTr("Disabled")
            percent: Services.Stats.swapTotalMiB > 0 ? Services.Stats.swapPercent : -1
            rowColor: root.swapColor
            percentColor: root.percentColor(percent, root.swapColor, 85, 90)
        }
    }

    component GpuTelemetry: ColumnLayout {
        Layout.fillWidth: true
        spacing: Config.spacing.xs

        Text {
            text: Services.Stats.gpuName
            color: root.observationColor(gpuObservation, Config.styling.text0)
            font.pixelSize: 13
            font.bold: true
            Layout.fillWidth: true
        }

        GraphView {
            id: gpuGraph
            active: root.visible
            yMin: 0
            yMax: 100
            xWindow: 120000
            xMarkerInterval: 60000
            xMarkerLabel: (x, view) => x < view.maxX ? qsTr("%1m").arg(Math.round((view.maxX - x) / 60000)) : ""
            graphs: root.gpuGraphSeries()
            Layout.fillWidth: true
            Layout.preferredHeight: 180
            Layout.minimumHeight: 140
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Item { Layout.fillWidth: true }

            LegendButton {
                Layout.preferredWidth: 100
                Layout.alignment: Qt.AlignHCenter
                graphView: gpuGraph
                seriesName: "GPU"
                color: root.gpuUsageColor

                Text {
                    text: qsTr("Compute")
                    font.pixelSize: 13
                    font.bold: true
                    color: Config.colors.base
                }
                Item { Layout.fillWidth: true }

                UsageArc {
                    implicitWidth: 14
                    implicitHeight: 14
                    percent: Services.Stats.gpuUtilPercent
                    accentColor: Config.colors.base
                    trackColor: Config.styling.bg4
                    strokeWidth: 2
                }
            }

            LegendButton {
                Layout.preferredWidth: 100
                Layout.alignment: Qt.AlignHCenter
                graphView: gpuGraph
                seriesName: "VRAM"
                color: root.gpuVramColor

                Text {
                    text: qsTr("VRAM")
                    font.pixelSize: 13
                    font.bold: true
                    color: Config.colors.base
                }
                Item { Layout.fillWidth: true }

                UsageArc {
                    implicitWidth: 14
                    implicitHeight: 14
                    percent: Services.Stats.gpuVramPercent
                    accentColor: Config.colors.base
                    trackColor: Config.styling.bg4
                    strokeWidth: 2
                }
            }

            Item { Layout.fillWidth: true }
        }

        StatTableHeader {}

        StatTableRow {
            label: qsTr("VRAM")
            valueText: `${Services.Stats.gpuVramUsedMiB} / ${Services.Stats.gpuVramTotalMiB} MiB`
            percent: Services.Stats.gpuVramPercent
            rowColor: root.gpuVramColor
            percentColor: root.percentColor(percent, root.gpuVramColor, 85, 90)
        }
    }

    component StorageTable: ColumnLayout {
        required property var rows

        Layout.fillWidth: true
        spacing: 0

        StatTableHeader {
            visible: parent.rows.length > 0
        }

        Repeater {
            model: parent.rows
            delegate: PartitionRow {}
        }
    }

    component StatTableHeader: RowLayout {
        Layout.fillWidth: true
        spacing: Config.spacing.xs

        Text {
            Layout.fillWidth: true
            text: qsTr("Name")
            color: Config.colors.blue
            font.pixelSize: 12
            font.bold: true
        }

        Text {
            Layout.preferredWidth: 120
            horizontalAlignment: Text.AlignRight
            text: qsTr("Used / Total")
            color: Config.colors.mauve
            font.pixelSize: 12
            font.bold: true
        }

        Text {
            Layout.preferredWidth: 50
            horizontalAlignment: Text.AlignRight
            text: "%"
            color: Config.colors.peach
            font.pixelSize: 12
            font.bold: true
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Config.styling.bg3
        }
    }

    component StatTableRow: RowLayout {
        Layout.fillWidth: true
        spacing: Config.spacing.xs

        property string label: ""
        property string valueText: ""
        property real percent: 0
        property color rowColor: Config.styling.text0
        property color percentColor: Config.styling.text0
        readonly property bool important: percent >= 75

        Text {
            Layout.fillWidth: true
            text: parent.label
            color: parent.important ? parent.percentColor : parent.rowColor
            font.pixelSize: 13
            font.bold: parent.important
            elide: Text.ElideRight
        }

        Text {
            Layout.preferredWidth: 120
            horizontalAlignment: Text.AlignRight
            text: parent.valueText
            color: parent.rowColor
            font.pixelSize: 13
            font.bold: parent.important
            font.family: "monospace"
        }

        Text {
            Layout.preferredWidth: 50
            horizontalAlignment: Text.AlignRight
            text: parent.percent >= 0 ? `${Math.round(parent.percent)}%` : "-"
            color: parent.percentColor
            font.pixelSize: 13
            font.bold: true
        }
    }

    component HeaderMetric: RowLayout {
        property string label: ""
        property real value: 0
        property color metricColor: Config.styling.text0

        spacing: 4

        Text {
            text: parent.label
            color: parent.metricColor
            font.pixelSize: 12
            font.bold: true
        }

        UsageArc {
            implicitWidth: 14
            implicitHeight: 14
            percent: parent.value
            accentColor: parent.metricColor
            trackColor: Config.styling.bg4
            strokeWidth: 2
        }
    }

    component PartitionRow: StatTableRow {
        required property var modelData

        label: modelData.mount || ""
        valueText: `${modelData.usedGiB || 0} / ${modelData.totalGiB || 0} GiB`
        percent: modelData.percent !== undefined ? modelData.percent : -1
        rowColor: Config.colors.peach
        percentColor: root.percentColor(percent, Config.colors.peach, 75, 90)
    }
}
