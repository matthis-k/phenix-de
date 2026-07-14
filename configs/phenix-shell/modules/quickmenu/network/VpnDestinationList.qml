import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell

import qs.services
import qs.components
import qs.animations as Animations

Item {
    id: root

    property string searchText: ""
    property var tabSwipeTarget: null
    property int itemSpacing: 3
    property int rowHeight: 36
    property int itemIconSize: 22
    property int itemTextSize: 16
    property int itemSubtextSize: 12
    property int iconTextGap: 10
    property int horizontalPadding: 8
    property int verticalPadding: 4

    implicitWidth: parent ? parent.width : 320
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout
        anchors.fill: parent
        spacing: itemSpacing

        TextField {
            id: searchField
            Layout.fillWidth: true
            visible: !VpnService.connecting
            text: root.searchText
            placeholderText: "Search countries or groups"
            color: Config.styling.text0
            placeholderTextColor: Config.styling.text2
            selectedTextColor: Config.styling.selectionText
            selectionColor: Config.styling.selectionBackgroundActive
            onTextChanged: root.searchText = text
            onAccepted: root.connectTopMatch()

            background: Rectangle {
                color: Config.styling.bg3
                border.width: 1
                border.color: Config.styling.bg5
            }
        }

        DashboardScrollArea {
            Layout.fillWidth: true
            Layout.preferredHeight: 160
            visible: !VpnService.connecting && searchField.activeFocus
            contentSpacing: itemSpacing
            tabSwipeTarget: root.tabSwipeTarget

            Repeater {
                model: root.filteredDestinations()

                delegate: DashboardListRow {
                    required property var modelData

                    minimumRowHeight: rowHeight
                    enabled: !VpnService.connecting
                    active: VpnService.connected && modelData.kind === "country" && modelData.name === VpnService.country
                    accentColor: Config.styling.good
                    title: VpnService.destinationLabel(modelData)
                    subtitle: VpnService.destinationSubtext(modelData)
                    titleSize: itemTextSize
                    subtitleSize: itemSubtextSize
                    horizontalPadding: horizontalPadding
                    verticalPadding: verticalPadding
                    contentSpacing: iconTextGap
                    onClicked: root.connectDestination(modelData)
                }
            }

            Text {
                visible: root.filteredDestinations().length === 0
                text: "No NordVPN destinations found"
                color: Config.styling.text2
                font.pixelSize: 12
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 160
            visible: VpnService.connecting
            spacing: iconTextGap

            Icon {
                Layout.preferredWidth: itemIconSize
                Layout.preferredHeight: itemIconSize
                iconName: "view-refresh-symbolic"
                color: Config.styling.text1
                implicitSize: itemIconSize
                rotation: VpnService.connecting ? 360 : 0

                Animations.SpinAnimation on rotation {
                    running: VpnService.connecting
                }
            }

            Text {
                Layout.fillWidth: true
                text: "Connecting, please wait..."
                color: Config.styling.text1
                font.pixelSize: itemTextSize
                font.bold: true
                elide: Text.ElideRight
            }
        }
    }

    function filteredDestinations() {
        const query = root.searchText.trim().toLowerCase();
        if (!query)
            return VpnService.destinations;
        return VpnService.destinations.filter(destination => {
            const name = VpnService.destinationLabel(destination).toLowerCase();
            const kind = VpnService.destinationSubtext(destination).toLowerCase();
            return name.includes(query) || kind.includes(query);
        });
    }

    function connectDestination(destination) {
        if (!destination || VpnService.connecting)
            return;
        VpnService.connect(destination.id);
        root.searchText = "";
    }

    function connectTopMatch() {
        const matches = root.filteredDestinations();
        if (matches.length > 0)
            root.connectDestination(matches[0]);
    }
}
