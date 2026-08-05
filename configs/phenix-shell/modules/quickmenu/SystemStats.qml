pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.services
import qs.services as Services
import qs.components

DashboardPage {
    id: root

    title: qsTr("System stats")
    scrollable: true

    readonly property var cpuCoreColors: [
        Config.colors.green,
        Config.colors.yellow,
        Config.colors.red,
        Config.colors.maroon,
        Config.colors.peach,
        Config.colors.mauve,
        Config.colors.pink,
        Config.colors.flamingo,
        Config.colors.rosewater
    ]
    readonly property color ramColor: Config.colors.blue
    readonly property color swapColor: Config.colors.mauve
    readonly property color gpuUsageColor: Config.colors.blue
    readonly property color gpuVramColor: Config.colors.mauve

    CpuDashboardObservation {
        id: cpuObservation
        presentationMode: root.presentationMode
        average: Services.Stats.cpuPercent
        cores: Services.Stats.cpuCorePercents
        revision: Services.Stats.cpuRevision
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
            color: series.name === "avg"
                ? Config.colors.blue
                : root.cpuCoreColors[parseInt(String(series.name).replace("core", "")) % root.cpuCoreColors.length],
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

    function metricSectionRank(key) {
        const sections = [
            { key: "cpu", order: 0, shown: true, exceptional: cpuObservation.exceptional, priority: cpuObservation.priority },
            { key: "memory", order: 1, shown: true, exceptional: memoryObservation.exceptional, priority: memoryObservation.priority },
            { key: "gpu", order: 2, shown: gpuObservation.shown, exceptional: gpuObservation.exceptional, priority: gpuObservation.priority },
            { key: "storage", order: 3, shown: storageObservation.shown, exceptional: storageObservation.exceptional, priority: storageObservation.priority }
        ];
        sections.sort(function(left, right) {
            if (left.shown !== right.shown)
                return left.shown ? -1 : 1;
            if (left.exceptional !== right.exceptional)
                return left.exceptional ? -1 : 1;
            if (left.exceptional && right.priority !== left.priority)
                return right.priority - left.priority;
            return left.order - right.order;
        });
        return sections.findIndex(section => section.key === key);
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 1
        rowSpacing: root.sectionSpacing
        columnSpacing: 0

    AdaptiveDashboardSection {
        observation: cpuObservation
        localDetailed: true
        title: qsTr("CPU usage")
        subtitle: cpuObservation.detailed
            ? qsTr("Average and every logical core over time")
            : (cpuObservation.promoted
                ? qsTr("%1 hot core(s) promoted").arg(cpuObservation.promotedRows.length)
                : qsTr("Current aggregate load"))
        iconName: "utilities-system-monitor-symbolic"
        iconColor: root.observationColor(cpuObservation, Config.colors.blue)
        titleColor: cpuObservation.promoted ? iconColor : Config.styling.text0
        subtitleColor: cpuObservation.promoted ? iconColor : Config.styling.text2
        subtitleBold: cpuObservation.promoted
        summary: Component {
            HeaderMetric {
                label: qsTr("AVG")
                value: Services.Stats.cpuPercent
                metricColor: root.observationColor(cpuObservation, Config.colors.blue)
            }
        }
        overviewDelegate: null
        promotedDelegate: Component { CpuPromoted {} }
        detailedDelegate: Component { CpuTelemetry {} }
        Layout.fillWidth: true
        Layout.row: root.metricSectionRank("cpu")
    }

    AdaptiveDashboardSection {
        observation: memoryObservation
        localDetailed: true
        title: qsTr("Memory")
        subtitle: memoryObservation.detailed
            ? qsTr("Allocation and usage history")
            : (memoryObservation.promoted
                ? memoryObservation.promotionReason
                : qsTr("Current RAM pressure"))
        iconName: "computer-symbolic"
        iconColor: root.observationColor(memoryObservation, root.ramColor)
        titleColor: memoryObservation.promoted ? iconColor : Config.styling.text0
        subtitleColor: memoryObservation.promoted ? iconColor : Config.styling.text2
        subtitleBold: memoryObservation.promoted
        summary: Component {
            RowLayout {
                spacing: Config.spacing.xs

                HeaderMetric {
                    label: qsTr("RAM")
                    value: Services.Stats.memoryPercent
                    metricColor: root.percentColor(Services.Stats.memoryPercent, root.ramColor, 85, 90)
                }

                HeaderMetric {
                    visible: Services.Stats.swapTotalMiB > 0 && Services.Stats.swapPercent > 0
                    label: qsTr("SWAP")
                    value: Services.Stats.swapPercent
                    metricColor: root.percentColor(Services.Stats.swapPercent, root.swapColor, 85, 90)
                }
            }
        }
        overviewDelegate: null
        promotedDelegate: Component { MemoryPromoted {} }
        detailedDelegate: Component { MemoryTelemetry {} }
        Layout.fillWidth: true
        Layout.row: root.metricSectionRank("memory")
    }

    AdaptiveDashboardSection {
        observation: gpuObservation
        localDetailed: true
        domainVisible: Services.Stats.gpuAvailable
        title: qsTr("GPU")
        subtitle: gpuObservation.detailed
            ? qsTr("Compute, VRAM, and usage history")
            : (gpuObservation.promoted
                ? gpuObservation.promotionReason
                : qsTr("Current GPU pressure"))
        iconName: "video-display-symbolic"
        iconColor: root.observationColor(gpuObservation, root.gpuUsageColor)
        titleColor: gpuObservation.promoted ? iconColor : Config.styling.text0
        subtitleColor: gpuObservation.promoted ? iconColor : Config.styling.text2
        subtitleBold: gpuObservation.promoted
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
        overviewDelegate: null
        promotedDelegate: Component { GpuPromoted {} }
        detailedDelegate: Component { GpuTelemetry {} }
        Layout.fillWidth: true
        Layout.row: root.metricSectionRank("gpu")
    }

    AdaptiveDashboardSection {
        observation: storageObservation
        localDetailed: true
        title: qsTr("Storage")
        subtitle: storageObservation.detailed
            ? qsTr("Every mounted filesystem")
            : (storageObservation.promoted
                ? storageObservation.promotionReason
                : qsTr("Current root filesystem usage"))
        iconName: "drive-harddisk-symbolic"
        iconColor: root.observationColor(storageObservation, Config.colors.peach)
        titleColor: storageObservation.promoted ? iconColor : Config.styling.text0
        subtitleColor: storageObservation.promoted ? iconColor : Config.styling.text2
        subtitleBold: storageObservation.promoted
        summary: Component {
            HeaderMetric {
                label: "/"
                value: Services.Stats.rootDiskPercent
                metricColor: root.percentColor(Services.Stats.rootDiskPercent, Config.colors.peach, 75, 90)
            }
        }
        overviewDelegate: null
        promotedDelegate: Component {
            StorageOverview { rows: storageObservation.exceptionalRows }
        }
        detailedDelegate: Component {
            StorageOverview { rows: storageObservation.visibleRows }
        }
        Layout.fillWidth: true
        Layout.row: root.metricSectionRank("storage")
    }

    }

    DashboardSection {
        Layout.fillWidth: true
        title: qsTr("Network throughput")
        iconName: "network-transmit-receive-symbolic"
        iconColor: Config.colors.green
        visible: Services.Stats.primaryInterface !== ""
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
    }

    component MetricGrid: GridLayout {
        Layout.fillWidth: true
        columns: Math.max(1, Math.floor((width + columnSpacing) / (108 + columnSpacing)))
        columnSpacing: Config.spacing.xs
        rowSpacing: Config.spacing.xs
        uniformCellWidths: true
    }

    component CpuPromoted: MetricGrid {
        Repeater {
            model: cpuObservation.promotedRows

            delegate: RadialMetric {
                required property var modelData
                Layout.fillWidth: true
                label: qsTr("Core %1").arg(Number(modelData.index || 0) + 1)
                iconName: "utilities-system-monitor-symbolic"
                percent: Number(modelData.percent || 0)
                accentColor: modelData.severity === DashboardObservation.Critical
                    ? Config.styling.critical
                    : Config.styling.warning
                detail: qsTr("outlier")
                emphasized: true
            }
        }
    }

    component MemoryPromoted: MetricGrid {
        RadialMetric {
            Layout.fillWidth: true
            label: qsTr("RAM")
            iconName: "computer-symbolic"
            percent: Services.Stats.memoryPercent
            accentColor: root.percentColor(percent, root.ramColor, 85, 90)
            detail: `${Services.Stats.memoryUsedMiB}/${Services.Stats.memoryTotalMiB} MiB`
            emphasized: true
        }

        RadialMetric {
            visible: Services.Stats.swapTotalMiB > 0 && Services.Stats.swapPercent >= memoryObservation.warningThreshold
            Layout.fillWidth: true
            label: qsTr("Swap")
            iconName: "drive-harddisk-symbolic"
            percent: Services.Stats.swapPercent
            accentColor: root.percentColor(percent, root.swapColor, 85, 90)
            detail: `${Services.Stats.swapUsedMiB}/${Services.Stats.swapTotalMiB} MiB`
            emphasized: true
        }
    }

    component GpuPromoted: MetricGrid {
        RadialMetric {
            Layout.fillWidth: true
            label: qsTr("Compute")
            iconName: "video-display-symbolic"
            percent: Services.Stats.gpuUtilPercent
            accentColor: root.percentColor(percent, root.gpuUsageColor, 85, 90)
            detail: Services.Stats.gpuName
            emphasized: true
        }

        RadialMetric {
            Layout.fillWidth: true
            label: qsTr("VRAM")
            iconName: "video-display-symbolic"
            percent: Services.Stats.gpuVramPercent
            accentColor: root.percentColor(percent, root.gpuVramColor, 85, 90)
            detail: `${Services.Stats.gpuVramUsedMiB}/${Services.Stats.gpuVramTotalMiB} MiB`
            emphasized: true
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
                emphasized: true
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
            xMarkerLabel: (x, view) => x < view.maxX
                ? qsTr("%1m").arg(Math.round((view.maxX - x) / 60000))
                : ""
            graphs: root.cpuGraphSeries()
            Layout.fillWidth: true
            Layout.preferredHeight: 220
            Layout.minimumHeight: 180
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Config.spacing.xs
            spacing: Config.spacing.xs

            RowLayout {
                Layout.fillWidth: true
                spacing: Config.spacing.xs

                LegendButton {
                    id: averageLegend

                    Layout.fillWidth: true
                    graphView: cpuGraph
                    seriesName: "avg"
                    accessibleLabel: qsTr("Toggle CPU average graph")
                    color: Config.colors.blue

                    Text {
                        text: qsTr("Average")
                        font.pixelSize: 13
                        font.bold: true
                        color: averageLegend.contentColor
                    }
                }

                LegendButton {
                    id: coresLegend

                    Layout.fillWidth: true
                    graphView: cpuGraph
                    seriesFilter: series => series.name.startsWith("core")
                    accessibleLabel: qsTr("Toggle all CPU core graphs")
                    color: Config.colors.overlay2

                    Text {
                        text: qsTr("Cores")
                        font.pixelSize: 13
                        font.bold: true
                        color: coresLegend.contentColor
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 4
                rowSpacing: Config.spacing.xs
                columnSpacing: Config.spacing.xs
                uniformCellWidths: true

                Repeater {
                    model: Services.Stats.cpuCorePercents.length

                    delegate: LegendButton {
                        id: coreLegend

                        required property int index
                        readonly property int coreIndex: index
                        readonly property real corePercent: {
                            const _ = Services.Stats.cpuRevision;
                            const values = Services.Stats.cpuCorePercents;
                            return Array.isArray(values) && coreLegend.coreIndex < values.length
                                ? Number(values[coreLegend.coreIndex] || 0)
                                : 0;
                        }

                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        implicitHeight: 34
                        contentHorizontalPadding: Config.spacing.xxs
                        graphView: cpuGraph
                        seriesName: `core${coreIndex}`
                        accessibleLabel: qsTr("Toggle CPU core %1 graph").arg(coreIndex + 1)
                        color: root.cpuCoreColors[coreIndex % root.cpuCoreColors.length]

                        Text {
                            text: qsTr("Core %1").arg(coreLegend.coreIndex + 1)
                            font.pixelSize: 10
                            font.bold: true
                            color: coreLegend.contentColor
                        }

                        Item { Layout.fillWidth: true }

                        Item {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            Layout.alignment: Qt.AlignVCenter

                            UsageArc {
                                anchors.fill: parent
                                percent: coreLegend.corePercent
                                accentColor: Config.colors.base
                                trackColor: Config.colorWithOpacity(Config.colors.base, 0.25)
                                strokeWidth: 4
                            }

                            Text {
                                anchors.fill: parent
                                text: `${Math.round(coreLegend.corePercent)}`
                                color: coreLegend.contentColor
                                font.pixelSize: 8
                                font.bold: true
                                font.family: "monospace"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
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
            xMarkerLabel: (x, view) => x < view.maxX
                ? qsTr("%1m").arg(Math.round((view.maxX - x) / 60000))
                : ""
            graphs: root.memoryGraphSeries()
            Layout.fillWidth: true
            Layout.preferredHeight: 200
            Layout.minimumHeight: 160
        }

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
            Layout.fillWidth: true
            text: Services.Stats.gpuName
            color: Config.styling.text0
            font.pixelSize: 13
            font.bold: true
        }

        GraphView {
            active: root.visible
            yMin: 0
            yMax: 100
            xWindow: 120000
            xMarkerInterval: 60000
            xMarkerLabel: (x, view) => x < view.maxX
                ? qsTr("%1m").arg(Math.round((view.maxX - x) / 60000))
                : ""
            graphs: root.gpuGraphSeries()
            Layout.fillWidth: true
            Layout.preferredHeight: 220
            Layout.minimumHeight: 180
        }

        StatTableRow {
            label: qsTr("Compute")
            valueText: `${Math.round(Services.Stats.gpuUtilPercent)}%`
            percent: Services.Stats.gpuUtilPercent
            rowColor: root.gpuUsageColor
            percentColor: root.percentColor(percent, root.gpuUsageColor, 85, 90)
        }

        StatTableRow {
            label: qsTr("VRAM")
            valueText: `${Services.Stats.gpuVramUsedMiB} / ${Services.Stats.gpuVramTotalMiB} MiB`
            percent: Services.Stats.gpuVramPercent
            rowColor: root.gpuVramColor
            percentColor: root.percentColor(percent, root.gpuVramColor, 85, 90)
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
            Layout.preferredWidth: 150
            horizontalAlignment: Text.AlignRight
            text: parent.valueText
            color: parent.rowColor
            font.pixelSize: 13
            font.bold: parent.important
            font.family: "monospace"
        }

        Text {
            Layout.preferredWidth: 48
            horizontalAlignment: Text.AlignRight
            text: parent.percent >= 0 ? `${Math.round(parent.percent)}%` : "-"
            color: parent.percentColor
            font.pixelSize: 13
            font.bold: true
        }
    }

    component HeaderMetric: RowLayout {
        id: headerMetric

        property string label: ""
        property real value: 0
        property color metricColor: Config.styling.text0

        spacing: Config.spacing.xxs
        Layout.minimumHeight: 36

        Text {
            text: headerMetric.label
            color: headerMetric.metricColor
            font.pixelSize: 12
            font.bold: true
        }

        Item {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36

            UsageArc {
                anchors.fill: parent
                percent: headerMetric.value
                accentColor: headerMetric.metricColor
                trackColor: Config.styling.bg4
                strokeWidth: 3
            }

            Text {
                anchors.fill: parent
                text: `${Math.round(headerMetric.value)}%`
                color: headerMetric.metricColor
                font.pixelSize: 12
                font.bold: true
                font.family: "monospace"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

}
