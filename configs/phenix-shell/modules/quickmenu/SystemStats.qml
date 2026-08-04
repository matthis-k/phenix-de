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
        : qsTr("Aggregate telemetry with abnormal cores and devices promoted")
    scrollable: true

    readonly property var cpuCoreColors: [Config.colors.green, Config.colors.yellow, Config.colors.red, Config.colors.maroon, Config.colors.peach, Config.colors.mauve, Config.colors.pink, Config.colors.flamingo, Config.colors.rosewater]
    readonly property color ramColor: Config.colors.blue
    readonly property color swapColor: Config.colors.mauve
    readonly property color gpuUsageColor: Config.colors.blue
    readonly property color gpuVramColor: Config.colors.mauve

    PresentationPolicy {
        id: presentationPolicy
    }

    readonly property var cpuOutliers: {
        const _ = Services.Stats.graphRevision;
        return presentationPolicy.cpuCoreOutliers(
            Services.Stats.cpuCorePercents,
            Services.Stats.cpuPercent,
            4
        );
    }

    readonly property var visibleCpuRows: {
        const _ = Services.Stats.graphRevision;
        return presentationPolicy.cpuRows(
            Services.Stats.cpuCorePercents,
            Services.Stats.cpuPercent,
            root.presentationMode
        );
    }

    readonly property var cpuOutlierKeys: {
        const result = {};
        for (const row of root.cpuOutliers)
            result[row.key] = true;
        return result;
    }

    readonly property var visiblePartitions: presentationPolicy.partitionRows(
        Services.Stats.diskPartitions,
        root.presentationMode
    )

    readonly property bool memoryOutlier: Services.Stats.memoryPercent >= 85
        || Services.Stats.swapPercent >= 85
    readonly property bool gpuOutlier: Services.Stats.gpuUtilPercent >= 85
        || Services.Stats.gpuVramPercent >= 85

    function cpuGraphSeries() {
        const _ = Services.Stats.graphRevision;
        return Services.Stats.calculateCpuGraphSeries().map(series => Object.assign({}, series, {
                color: series.name === "avg" ? Config.colors.blue : root.cpuCoreColors[parseInt(String(series.name).replace("core", "")) % root.cpuCoreColors.length],
                lineWidth: series.name === "avg" ? 2.5 : 1.2,
                visible: series.name === "avg" || root.detailed || root.cpuOutlierKeys[series.name] === true
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

    DashboardSection {
        title: "CPU Usage"
        subtitle: root.detailed
            ? qsTr("Average and every logical core")
            : (root.cpuOutliers.length > 0
                ? qsTr("Average plus %1 promoted core outlier(s)").arg(root.cpuOutliers.length)
                : qsTr("Average; no per-core outliers"))
        collapsible: true
        summary: Component {
            HeaderMetric {
                label: "avg"
                value: Services.Stats.cpuPercent
                metricColor: Config.colors.blue
            }
        }
        Layout.fillWidth: true

        ColumnLayout {
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
                Item {
                    Layout.fillWidth: true
                }
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
                    visible: root.detailed
                    Layout.preferredWidth: visible ? 100 : 0
                    Layout.alignment: Qt.AlignHCenter
                    graphView: cpuGraph
                    seriesFilter: (s) => s.name.startsWith("core")
                    color: Config.colors.overlay2

                    Text {
                        Layout.fillWidth: true
                        text: "cores"
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 13
                        color: Config.colors.base
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
            }

            Text {
                visible: !root.detailed && root.visibleCpuRows.length === 0
                Layout.fillWidth: true
                text: qsTr("No core is above 90% or materially above the CPU average.")
                color: Config.styling.text2
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            GridLayout {
                visible: root.visibleCpuRows.length > 0
                Layout.fillWidth: true
                columns: 4
                rowSpacing: 2
                columnSpacing: 8
                uniformCellWidths: true

                Repeater {
                    model: root.visibleCpuRows
                    CpuLegendDelegate {}
                }
            }
        }
    }

    DashboardSection {
        title: "Memory"
        subtitle: root.detailed
            ? qsTr("Usage history and exact allocation")
            : qsTr("Aggregate RAM and swap usage")
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
        Layout.fillWidth: true

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Config.spacing.xs

            GraphView {
                id: memGraph
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

            StatTableHeader {
                visible: root.detailed || root.memoryOutlier
            }

            StatTableRow {
                visible: root.detailed || Services.Stats.memoryPercent >= 85
                label: "RAM"
                valueText: `${Services.Stats.memoryUsedMiB} / ${Services.Stats.memoryTotalMiB} MiB`
                percent: Services.Stats.memoryPercent
                rowColor: root.ramColor
                percentColor: Services.Stats.memoryPercent >= 90 ? Config.styling.critical : root.ramColor
            }

            StatTableRow {
                visible: root.detailed || Services.Stats.swapPercent >= 85
                label: "Swap"
                valueText: Services.Stats.swapTotalMiB > 0 ? `${Services.Stats.swapUsedMiB} / ${Services.Stats.swapTotalMiB} MiB` : "Disabled"
                percent: Services.Stats.swapTotalMiB > 0 ? Services.Stats.swapPercent : -1
                rowColor: root.swapColor
                percentColor: Services.Stats.swapPercent >= 90 ? Config.styling.critical : root.swapColor
            }
        }
    }

    DashboardSection {
        title: "GPU"
        visible: Services.Stats.gpuAvailable
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
        Layout.fillWidth: true

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Config.spacing.xs

            Text {
                visible: root.detailed || root.gpuOutlier
                text: Services.Stats.gpuName
                color: Config.styling.text0
                font.pixelSize: 13
                font.bold: true
                Layout.fillWidth: true
            }

            GraphView {
                id: gpuGraph
                visible: root.detailed || root.gpuOutlier
                active: root.visible && visible
                yMin: 0
                yMax: 100
                xWindow: 120000
                xMarkerInterval: 60000
                xMarkerLabel: (x, view) => x < view.maxX ? qsTr("%1m").arg(Math.round((view.maxX - x) / 60000)) : ""
                graphs: root.gpuGraphSeries()
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 180 : 0
                Layout.minimumHeight: visible ? 140 : 0
            }

            RowLayout {
                visible: root.detailed || root.gpuOutlier
                Layout.fillWidth: true
                spacing: 8
                Item {
                    Layout.fillWidth: true
                }
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
                Item {
                    Layout.fillWidth: true
                }
            }

            StatTableHeader {
                visible: root.detailed || Services.Stats.gpuVramPercent >= 85
            }

            StatTableRow {
                visible: root.detailed || Services.Stats.gpuVramPercent >= 85
                label: "VRAM"
                valueText: `${Services.Stats.gpuVramUsedMiB} / ${Services.Stats.gpuVramTotalMiB} MiB`
                percent: Services.Stats.gpuVramPercent
                rowColor: root.gpuVramColor
                percentColor: Services.Stats.gpuVramPercent >= 90 ? Config.styling.critical : root.gpuVramColor
            }
        }
    }

    DashboardSection {
        title: "Storage"
        visible: Services.Stats.diskPartitions.length > 0
        collapsible: true
        summary: Component {
            HeaderMetric {
                label: "/"
                value: Services.Stats.rootDiskPercent
                metricColor: Services.Stats.rootDiskPercent >= 90 ? Config.styling.critical : (Services.Stats.rootDiskPercent >= 75 ? Config.styling.warning : Config.styling.text0)
            }
        }
        Layout.fillWidth: true

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StatTableHeader {}

            Repeater {
                model: root.visiblePartitions

                PartitionRow {}
            }
        }
    }

    DashboardSection {
        title: "Network throughput"
        visible: Services.Stats.primaryInterface !== ""
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
        Layout.fillWidth: true

        InfoRow {
            visible: root.detailed
            iconName: "go-down-symbolic"
            label: "Download"
            value: Services.Stats.formatRate(Services.Stats.rxBytesPerSecond)
            Layout.fillWidth: true
        }

        InfoRow {
            visible: root.detailed
            iconName: "go-up-symbolic"
            label: "Upload"
            value: Services.Stats.formatRate(Services.Stats.txBytesPerSecond)
            Layout.fillWidth: true
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

    component CpuLegendDelegate: LegendButton {
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
        percentColor: percent >= 90 ? Config.styling.critical : (percent >= 75 ? Config.styling.warning : Config.styling.text0)
    }
}
