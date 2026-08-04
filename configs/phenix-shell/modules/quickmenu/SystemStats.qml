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
        : qsTr("Aggregate telemetry with abnormal observations promoted")
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
        title: "CPU Usage"
        subtitle: cpuObservation.detailed
            ? qsTr("Average and every logical core")
            : (cpuObservation.promoted
                ? qsTr("Average plus %1 promoted core outlier(s)").arg(cpuObservation.promotedRows.length)
                : qsTr("Average; no per-core outliers"))
        collapsible: true
        summary: Component {
            HeaderMetric {
                label: "avg"
                value: Services.Stats.cpuPercent
                metricColor: Config.colors.blue
            }
        }
        overviewDelegate: Component {
            Text {
                Layout.fillWidth: true
                text: qsTr("No core is above 90% or materially above the CPU average.")
                color: Config.styling.text2
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }
        promotedDelegate: Component {
            CpuTelemetry {}
        }
        detailedDelegate: Component {
            CpuTelemetry {}
        }
        Layout.fillWidth: true
    }

    AdaptiveDashboardSection {
        observation: memoryObservation
        title: "Memory"
        subtitle: memoryObservation.detailed
            ? qsTr("Usage history and exact allocation")
            : (memoryObservation.promoted
                ? memoryObservation.promotionReason
                : qsTr("Aggregate RAM and swap usage"))
        collapsible: true
        summary: Component {
            RowLayout {
                spacing: Config.spacing.xs
                HeaderMetric {
                    label: "RAM"
                    value: Services.Stats.memoryPercent
                    metricColor: root.ramColor
                }
                HeaderMetric {
                    label: "Swap"
                    value: Services.Stats.swapTotalMiB > 0 ? Services.Stats.swapPercent : 0
                    metricColor: root.swapColor
                }
            }
        }
        promotedDelegate: Component {
            MemoryTelemetry {}
        }
        detailedDelegate: Component {
            MemoryTelemetry {}
        }
        Layout.fillWidth: true
    }

    AdaptiveDashboardSection {
        observation: gpuObservation
        title: "GPU"
        subtitle: gpuObservation.detailed
            ? qsTr("Compute, VRAM, and usage history")
            : (gpuObservation.promoted
                ? gpuObservation.promotionReason
                : qsTr("Aggregate compute and VRAM usage"))
        collapsible: true
        summary: Component {
            RowLayout {
                spacing: Config.spacing.xs
                HeaderMetric {
                    label: "Compute"
                    value: Services.Stats.gpuUtilPercent
                    metricColor: root.gpuUsageColor
                }
                HeaderMetric {
                    label: "VRAM"
                    value: Services.Stats.gpuVramPercent
                    metricColor: root.gpuVramColor
                }
            }
        }
        promotedDelegate: Component {
            GpuTelemetry {}
        }
        detailedDelegate: Component {
            GpuTelemetry {}
        }
        Layout.fillWidth: true
    }

    AdaptiveDashboardSection {
        observation: storageObservation
        title: "Storage"
        subtitle: storageObservation.detailed
            ? qsTr("Every mounted filesystem")
            : (storageObservation.promoted
                ? storageObservation.promotionReason
                : qsTr("Root filesystem usage"))
        collapsible: true
        summary: Component {
            HeaderMetric {
                label: "/"
                value: Services.Stats.rootDiskPercent
                metricColor: Services.Stats.rootDiskPercent >= 90
                    ? Config.styling.critical
                    : (Services.Stats.rootDiskPercent >= 75
                        ? Config.styling.warning
                        : Config.styling.text0)
            }
        }
        overviewDelegate: Component {
            StorageTable {
                rows: storageObservation.rootRows
            }
        }
        promotedDelegate: Component {
            StorageTable {
                rows: storageObservation.visibleRows
            }
        }
        detailedDelegate: Component {
            StorageTable {
                rows: storageObservation.visibleRows
            }
        }
        Layout.fillWidth: true
    }

    AdaptiveDashboardSection {
        observation: networkObservation
        title: "Network throughput"
        collapsible: true
        summary: Component {
            RowLayout {
                spacing: Config.spacing.xs
                Text {
                    text: Services.Stats.formatRate(Services.Stats.rxBytesPerSecond)
                    color: Config.styling.text0
                    font.pixelSize: 12
                    font.family: "monospace"
                }
                Text {
                    text: Services.Stats.formatRate(Services.Stats.txBytesPerSecond)
                    color: Config.styling.text2
                    font.pixelSize: 12
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
                    label: "Download"
                    value: Services.Stats.formatRate(Services.Stats.rxBytesPerSecond)
                    Layout.fillWidth: true
                }

                InfoRow {
                    iconName: "go-up-symbolic"
                    label: "Upload"
                    value: Services.Stats.formatRate(Services.Stats.txBytesPerSecond)
                    Layout.fillWidth: true
                }
            }
        }
        Layout.fillWidth: true
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
                    text: "average"
                    font.pixelSize: 13
                    color: Config.colors.base
                }
                Item { Layout.fillWidth: true }

                UsagePie {
                    percent: Services.Stats.cpuPercent
                    fillColor: Config.colors.base
                }
            }

            LegendButton {
                visible: cpuObservation.detailed
                Layout.preferredWidth: visible ? 100 : 0
                Layout.alignment: Qt.AlignHCenter
                graphView: cpuGraph
                seriesFilter: (series) => series.name.startsWith("core")
                color: Config.colors.overlay2

                Text {
                    Layout.fillWidth: true
                    text: "cores"
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 13
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
                        color: Config.colors.base
                    }
                    Item { Layout.fillWidth: true }

                    UsagePie {
                        percent: Number(modelData.percent || 0)
                        fillColor: Config.colors.base
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
            visible: memoryObservation.detailed || Services.Stats.memoryPercent >= memoryObservation.warningThreshold
            label: "RAM"
            valueText: `${Services.Stats.memoryUsedMiB} / ${Services.Stats.memoryTotalMiB} MiB`
            percent: Services.Stats.memoryPercent
            rowColor: root.ramColor
            percentColor: Services.Stats.memoryPercent >= 90 ? Config.styling.critical : root.ramColor
        }

        StatTableRow {
            visible: memoryObservation.detailed || Services.Stats.swapPercent >= memoryObservation.warningThreshold
            label: "Swap"
            valueText: Services.Stats.swapTotalMiB > 0
                ? `${Services.Stats.swapUsedMiB} / ${Services.Stats.swapTotalMiB} MiB`
                : "Disabled"
            percent: Services.Stats.swapTotalMiB > 0 ? Services.Stats.swapPercent : -1
            rowColor: root.swapColor
            percentColor: Services.Stats.swapPercent >= 90 ? Config.styling.critical : root.swapColor
        }
    }

    component GpuTelemetry: ColumnLayout {
        Layout.fillWidth: true
        spacing: Config.spacing.xs

        Text {
            text: Services.Stats.gpuName
            color: Config.styling.text0
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
                    text: "Compute"
                    font.pixelSize: 13
                    color: Config.colors.base
                }
                Item { Layout.fillWidth: true }

                UsagePie {
                    percent: Services.Stats.gpuUtilPercent
                    fillColor: Config.colors.base
                }
            }

            LegendButton {
                Layout.preferredWidth: 100
                Layout.alignment: Qt.AlignHCenter
                graphView: gpuGraph
                seriesName: "VRAM"
                color: root.gpuVramColor

                Text {
                    text: "VRAM"
                    font.pixelSize: 13
                    color: Config.colors.base
                }
                Item { Layout.fillWidth: true }

                UsagePie {
                    percent: Services.Stats.gpuVramPercent
                    fillColor: Config.colors.base
                }
            }

            Item { Layout.fillWidth: true }
        }

        StatTableHeader {
            visible: gpuObservation.detailed || Services.Stats.gpuVramPercent >= gpuObservation.warningThreshold
        }

        StatTableRow {
            visible: gpuObservation.detailed || Services.Stats.gpuVramPercent >= gpuObservation.warningThreshold
            label: "VRAM"
            valueText: `${Services.Stats.gpuVramUsedMiB} / ${Services.Stats.gpuVramTotalMiB} MiB`
            percent: Services.Stats.gpuVramPercent
            rowColor: root.gpuVramColor
            percentColor: Services.Stats.gpuVramPercent >= 90 ? Config.styling.critical : root.gpuVramColor
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
            text: "Name"
            color: Config.styling.text2
            font.pixelSize: 12
            font.bold: true
        }

        Text {
            Layout.preferredWidth: 120
            horizontalAlignment: Text.AlignRight
            text: "Used / Total"
            color: Config.styling.text2
            font.pixelSize: 12
            font.bold: true
        }

        Text {
            Layout.preferredWidth: 50
            horizontalAlignment: Text.AlignRight
            text: "%"
            color: Config.styling.text2
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

        Text {
            Layout.fillWidth: true
            text: parent.label
            color: parent.rowColor
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        Text {
            Layout.preferredWidth: 120
            horizontalAlignment: Text.AlignRight
            text: parent.valueText
            color: parent.rowColor
            font.pixelSize: 13
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
        }

        UsagePie {
            percent: parent.value
            fillColor: parent.metricColor
        }
    }

    component PartitionRow: StatTableRow {
        required property var modelData

        label: modelData.mount || ""
        valueText: `${modelData.usedGiB || 0} / ${modelData.totalGiB || 0} GiB`
        percent: modelData.percent !== undefined ? modelData.percent : -1
        percentColor: percent >= 90
            ? Config.styling.critical
            : (percent >= 75 ? Config.styling.warning : Config.styling.text0)
    }
}
