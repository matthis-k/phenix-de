import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell

import qs.services
import qs.components
import qs.animations as Animations

Item {
    id: rowRoot

    required property var network
    property var interactionState: null
    property int contentWidth: 320
    property int itemSpacing: 3
    property int rowHeight: 36
    property int iconSlotWidth: 28
    property int itemIconSize: 22
    property int itemTextSize: 16
    property int itemSubtextSize: 12
    property int iconTextGap: 10
    property int horizontalPadding: 8
    property int verticalPadding: 4

    readonly property bool hasNetwork: !!network
    readonly property string rowKey: rowRoot.interactionState && rowRoot.network ? String(rowRoot.interactionState.networkKey(rowRoot.network) || "") : ""
    readonly property bool expanded: rowRoot.interactionState && rowRoot.rowKey !== "" ? rowRoot.interactionState.interactiveNetworkKey === rowRoot.rowKey : false
    readonly property bool showAdvanced: rowRoot.expanded && rowRoot.interactionState ? !!rowRoot.interactionState.interactiveShowAdvanced : false
    readonly property bool showPasswordInput: rowRoot.expanded && rowRoot.interactionState ? !!rowRoot.interactionState.interactiveShowPasswordInput : false
    readonly property string passwordText: rowRoot.expanded && rowRoot.interactionState ? String(rowRoot.interactionState.interactivePasswordText || "") : ""
    readonly property string errorText: rowRoot.expanded && rowRoot.interactionState ? String(rowRoot.interactionState.interactiveErrorText || "") : ""
    readonly property bool needsPskPrompt: hasNetwork && !network.connected && !NetworkService.isOpenNetwork(network) && NetworkService.securityNeedsPsk(network.security)

    implicitWidth: contentWidth
    implicitHeight: header.implicitHeight + (details.implicitHeight > 0 ? details.implicitHeight + itemSpacing : 0)
    height: implicitHeight

    onHasNetworkChanged: {
        if (!hasNetwork && expanded && interactionState)
            interactionState.unlockInteraction();
    }

    function attemptConnect() {
        if (!hasNetwork) {
            if (rowRoot.interactionState)
                rowRoot.interactionState.unlockInteraction();
            return;
        }

        if (rowRoot.interactionState)
            rowRoot.interactionState.lockInteractionFor(network);
        if (rowRoot.interactionState)
            rowRoot.interactionState.interactiveErrorText = "";

        if (network.connected)
            return;

        if (NetworkService.isOpenNetwork(network) || !NetworkService.securityNeedsPsk(network.security)) {
            NetworkService.connectToNetwork(network.ssid, "");
            return;
        }

        if (rowRoot.interactionState)
            rowRoot.interactionState.interactiveShowPasswordInput = true;

        if (rowRoot.interactionState && !rowRoot.interactionState.interactivePasswordText.length) {
            rowRoot.interactionState.interactiveErrorText = "Password required";
            return;
        }

        NetworkService.connectToNetwork(network.ssid, rowRoot.interactionState ? rowRoot.interactionState.interactivePasswordText : "");
    }

    Connections {
        target: NetworkService

        function onConnectedSsidChanged() {
            if (rowRoot.expanded && rowRoot.hasNetwork && NetworkService.connectedSsid === rowRoot.network.ssid && rowRoot.interactionState) {
                rowRoot.interactionState.interactiveErrorText = "";
                rowRoot.interactionState.interactivePasswordText = "";
                rowRoot.interactionState.interactiveShowPasswordInput = false;
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: itemSpacing

        DashboardListRow {
            id: header
            minimumRowHeight: rowHeight
            active: rowRoot.hasNetwork && rowRoot.network.connected
            accentColor: rowRoot.hasNetwork && rowRoot.network.connected ? Config.colors.blue : Config.styling.activeIndicator
            fillOpacity: rowRoot.hasNetwork && rowRoot.network.connected ? 0.28 : Config.behaviour.hoverBgOpacity
            iconName: NetworkService.wifiIconName(rowRoot.network)
            iconColor: rowRoot.hasNetwork && rowRoot.network.connected ? Config.colors.blue : Config.styling.text0
            title: rowRoot.hasNetwork ? (rowRoot.network.ssid || "Hidden network") : "Unavailable"
            subtitle: rowRoot.hasNetwork
                ? `${rowRoot.securityLabel(rowRoot.network)} | ${rowRoot.network.strength || Math.round((rowRoot.network.signalStrength || 0) * 100)}%`
                : "Network unavailable"
            status: rowRoot.hasNetwork && rowRoot.network.connected
                ? "Connected"
                : rowRoot.hasNetwork && NetworkService.securityNeedsPsk(rowRoot.network.security) && !NetworkService.isOpenNetwork(rowRoot.network)
                    ? "Secured"
                    : "Available"
            statusColor: rowRoot.hasNetwork && rowRoot.network.connected
                ? Config.colors.blue
                : Config.styling.text1
            iconSlotWidth: iconSlotWidth
            iconSize: itemIconSize
            titleSize: itemTextSize
            subtitleSize: itemSubtextSize
            horizontalPadding: horizontalPadding
            verticalPadding: verticalPadding
            contentSpacing: iconTextGap

            onClicked: {
                    if (rowRoot.expanded && rowRoot.interactionState)
                        rowRoot.interactionState.unlockInteraction();
                    else if (rowRoot.hasNetwork && rowRoot.interactionState)
                        rowRoot.interactionState.lockInteractionFor(rowRoot.network);
            }
        }

        Expander {
            id: details

            Layout.fillWidth: true
            expanded: rowRoot.expanded
            slideDistance: Config.spacing.sm

            Rectangle {
                width: parent.width
                height: implicitHeight
                color: Config.styling.bg1
                implicitHeight: detailsColumn.implicitHeight + horizontalPadding * 2

                ColumnLayout {
                    id: detailsColumn
                    anchors.fill: parent
                    anchors.margins: horizontalPadding
                    spacing: Config.spacing.xxs

                    Text {
                        Layout.fillWidth: true
                        text: NetworkService.primaryNetworkInfo(rowRoot.network)
                        color: Config.styling.text1
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }

                    TextField {
                        id: passwordField
                        Layout.fillWidth: true
                        visible: rowRoot.showPasswordInput
                        text: rowRoot.passwordText
                        placeholderText: "Wi-Fi password"
                        echoMode: TextInput.Password
                        color: Config.styling.text0
                        placeholderTextColor: Config.styling.text2
                        selectedTextColor: Config.styling.selectionText
                        selectionColor: Config.styling.selectionBackgroundActive
                        onTextChanged: {
                            if (rowRoot.interactionState)
                                rowRoot.interactionState.interactivePasswordText = text;
                        }
                        onAccepted: rowRoot.attemptConnect()

                        background: Rectangle {
                            color: Config.styling.bg3
                            border.width: 1
                            border.color: Config.styling.bg5
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: rowRoot.errorText !== ""
                        text: rowRoot.errorText
                        color: Config.styling.critical
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        implicitHeight: 28
                        spacing: itemSpacing

                        SmallButton {
                            Layout.fillWidth: true
                            text: rowRoot.hasNetwork && rowRoot.network.connected ? "Disconnect" : "Connect"
                            onClicked: {
                                if (!rowRoot.hasNetwork) {
                                    if (rowRoot.interactionState)
                                        rowRoot.interactionState.unlockInteraction();
                                    return;
                                }

                                if (rowRoot.network.connected) {
                                    NetworkService.disconnectWifi();
                                } else {
                                    rowRoot.attemptConnect();
                                }
                            }
                        }

                        SmallButton {
                            text: rowRoot.showAdvanced ? "Hide Advanced" : "Show Advanced"
                            onClicked: {
                                if (rowRoot.interactionState)
                                    rowRoot.interactionState.interactiveShowAdvanced = !rowRoot.interactionState.interactiveShowAdvanced;
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: rowRoot.showAdvanced
                        text: NetworkService.advancedNetworkInfo(rowRoot.network)
                        color: Config.styling.text2
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }

    function securityLabel(network) {
        if (!network)
            return "Unknown";
        if (NetworkService.isOpenNetwork(network))
            return "Open";
        return network.security;
    }
}
