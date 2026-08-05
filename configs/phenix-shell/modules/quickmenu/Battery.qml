pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.services
import qs.services as Services
import qs.components

ColumnLayout {
    id: root

    property bool showPowerModes: true
    property bool showGraph: true
    property bool graphActive: true
    property bool compact: false
    readonly property bool hasBattery: PowerService.hasBattery
    readonly property color stateColor: PowerService.iconColor

    function formatDuration(seconds, prefix) {
        if (!seconds || seconds <= 0)
            return "";

        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor(seconds / 60) % 60;
        return `${prefix}${hours}h${minutes}m`;
    }

    readonly property string batteryDetail: {
        if (!PowerService.hasBattery)
            return "";
        if (PowerService.charging)
            return formatDuration(PowerService.timeToFull, qsTr("Full in "));
        return formatDuration(PowerService.timeToEmpty, qsTr("Empty in "));
    }

    function batteryGraphSeries() {
        const _ = Services.Stats.graphRevision;
        return Services.Stats.calculateBatteryGraphSeries().map(series => Object.assign({}, series, {
            color: root.stateColor
        }));
    }

    implicitWidth: 320
    width: parent ? parent.width : implicitWidth
    spacing: Config.spacing.xs

    component SummaryBlock: ColumnLayout {
        Layout.fillWidth: true
        spacing: Config.spacing.xxs

        RowLayout {
            Layout.fillWidth: true
            spacing: Config.spacing.sm

            Icon {
                iconName: PowerService.iconName
                color: root.stateColor
                implicitSize: 20
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
            }

            Text {
                text: PowerService.hasBattery
                    ? qsTr("Charge level")
                    : qsTr("Battery unavailable")
                color: Config.styling.text0
                font.pixelSize: 16
                font.bold: true
            }

            Item { Layout.fillWidth: true }

            Text {
                visible: PowerService.hasBattery
                text: `${PowerService.batteryPercent}%`
                color: root.stateColor
                font.pixelSize: 18
                font.bold: true
            }
        }

        Text {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.batteryDetail
            color: Config.styling.text2
            font.pixelSize: 12
        }
    }

    component PowerModesBlock: ColumnLayout {
        Layout.fillWidth: true
        spacing: Config.spacing.xs

        Text {
            Layout.fillWidth: true
            text: qsTr("Power profile")
            color: Config.styling.text1
            font.pixelSize: 13
            font.bold: true
        }

        ProfileButtons {
            Layout.fillWidth: true
        }
    }

    component ProfileButtons: RowLayout {
        id: profileButtons

        property bool iconsOnly: false

        spacing: Config.spacing.xxs

        Repeater {
            model: PowerService.profiles

            delegate: ActionButton {
                id: profileButton

                required property var modelData
                readonly property bool selected: String(modelData) === String(PowerService.profile)

                Layout.fillWidth: true
                Layout.minimumWidth: profileButtons.iconsOnly ? 32 : 0
                Layout.maximumWidth: profileButtons.iconsOnly ? 38 : 16777215
                Layout.minimumHeight: profileButtons.iconsOnly ? 32 : 36
                active: selected
                accentColor: PowerService.profileColor(modelData)
                backgroundColor: selected
                    ? PowerService.profileColor(modelData)
                    : Config.styling.bg3
                accessibleName: qsTr("Use %1 power profile").arg(PowerService.profileLabel(modelData))
                onClicked: {
                    if (!selected)
                        PowerService.setProfile(modelData);
                }

                contentItem: Item {
                    Icon {
                        visible: profileButtons.iconsOnly
                        anchors.centerIn: parent
                        iconName: PowerService.profileIconName(profileButton.modelData)
                        fallbackIconName: iconName
                        color: profileButton.selected
                            ? Config.styling.textOnAccent
                            : PowerService.profileColor(profileButton.modelData)
                        implicitSize: 17
                    }

                    Text {
                        visible: !profileButtons.iconsOnly
                        anchors.fill: parent
                        text: PowerService.profileLabel(profileButton.modelData)
                        color: profileButton.selected
                            ? Config.styling.textOnAccent
                            : Config.styling.text0
                        font.pixelSize: 12
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    component CompactBlock: RowLayout {
        Layout.fillWidth: true
        spacing: Config.spacing.xs

        Icon {
            iconName: PowerService.iconName
            fallbackIconName: "battery-missing-symbolic"
            color: root.stateColor
            implicitSize: 20
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: qsTr("Battery %1%").arg(PowerService.batteryPercent)
                color: root.stateColor
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: root.batteryDetail !== ""
                text: root.batteryDetail
                color: Config.styling.text2
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        ProfileButtons {
            visible: root.showPowerModes
            iconsOnly: true
            Layout.alignment: Qt.AlignVCenter
        }
    }

    CompactBlock {
        Layout.fillWidth: true
        visible: root.compact && root.hasBattery
    }

    SummaryBlock {
        Layout.fillWidth: true
        visible: !root.compact && root.hasBattery
    }

    Rectangle {
        Layout.fillWidth: true
        visible: !root.compact && root.showPowerModes && root.hasBattery
        implicitHeight: 1
        color: Config.styling.bg3
    }

    PowerModesBlock {
        Layout.fillWidth: true
        visible: !root.compact && root.showPowerModes && root.hasBattery
    }

    Rectangle {
        Layout.fillWidth: true
        visible: !root.compact && root.showGraph && root.hasBattery
        implicitHeight: 1
        color: Config.styling.bg3
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: !root.compact && root.showGraph && root.hasBattery
        spacing: Config.spacing.xs

        Text {
            Layout.fillWidth: true
            text: qsTr("Battery history (5h)")
            color: Config.styling.text1
            font.pixelSize: 14
            font.bold: true
        }

        GraphView {
            active: root.graphActive && root.showGraph
            yMin: 0
            yMax: 100
            xWindow: 18000000
            xMarkerInterval: 3600000
            xMarkerLabel: (x, view) => x < view.maxX
                ? qsTr("%1h").arg(Math.round((view.maxX - x) / 3600000))
                : ""
            graphs: root.batteryGraphSeries()
            Layout.fillWidth: true
            Layout.preferredHeight: 160
            Layout.minimumHeight: 120
        }
    }
}
