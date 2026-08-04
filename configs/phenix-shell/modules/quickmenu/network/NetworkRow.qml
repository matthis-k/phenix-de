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
    property bool inheritedDetailed: false
    property bool localDetailed: false
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
    readonly property string rowKey: rowRoot.interactionState && rowRoot.network
        ? String(rowRoot.interactionState.networkKey(rowRoot.network) || "")
        : ""
    readonly property bool interactionExpanded: rowRoot.interactionState && rowRoot.rowKey !== ""
        ? rowRoot.interactionState.interactiveNetworkKey === rowRoot.rowKey
        : false
    readonly property bool forcedDetailed: DashboardPresentation.detailed || rowRoot.inheritedDetailed
    readonly property bool detailed: rowRoot.forcedDetailed || rowRoot.localDetailed
    readonly property bool detailExpanded: rowRoot.interactionExpanded || rowRoot.detailed
    readonly property var activeInterface: {
        const _ = NetworkInterfaces.revision;
        return NetworkInterfaces.activeInterface();
    }
    readonly property bool showPasswordInput: rowRoot.interactionExpanded && rowRoot.interactionState
        ? !!rowRoot.interactionState.interactiveShowPasswordInput
        : false
    readonly property string passwordText: rowRoot.interactionExpanded && rowRoot.interactionState
        ? String(rowRoot.interactionState.interactivePasswordText || "")
        : ""
    readonly property string errorText: rowRoot.interactionExpanded && rowRoot.interactionState
        ? String(rowRoot.interactionState.interactiveErrorText || "")
        : ""

    implicitWidth: contentWidth
    implicitHeight: header.implicitHeight + (details.implicitHeight > 0 ? details.implicitHeight + itemSpacing : 0)
    height: implicitHeight

    onHasNetworkChanged: {
        if (!hasNetwork && interactionExpanded && interactionState)
            interactionState.unlockInteraction();
    }

    function toggleLocalDetails() {
        if (rowRoot.forcedDetailed)
            return;
        rowRoot.localDetailed = !rowRoot.localDetailed;
    }

    function attemptConnect() {
        if (!hasNetwork) {
            if (rowRoot.interactionState)
                rowRoot.interactionState.unlockInteraction();
            return;
        }

        if (rowRoot.interactionState) {
            rowRoot.interactionState.lockInteractionFor(network);
            rowRoot.interactionState.interactiveErrorText = "";
        }

        if (network.connected)
            return;

        if (NetworkService.isOpenNetwork(network) || !NetworkService.securityNeedsPsk(network.security)) {
            NetworkService.connectToNetwork(network.ssid, "");
            return;
        }

        if (rowRoot.interactionState)
            rowRoot.interactionState.interactiveShowPasswordInput = true;

        if (rowRoot.interactionState && !rowRoot.interactionState.interactivePasswordText.length) {
            rowRoot.interactionState.interactiveErrorText = qsTr("Password required");
            return;
        }

        NetworkService.connectToNetwork(
            network.ssid,
            rowRoot.interactionState ? rowRoot.interactionState.interactivePasswordText : "");
    }

    Connections {
        target: NetworkService

        function onConnectedSsidChanged() {
            if (rowRoot.interactionExpanded
                    && rowRoot.hasNetwork
                    && NetworkService.connectedSsid === rowRoot.network.ssid
                    && rowRoot.interactionState) {
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
            accentColor: rowRoot.hasNetwork && rowRoot.network.connected
                ? Config.colors.blue
                : Config.styling.activeIndicator
            fillOpacity: rowRoot.hasNetwork && rowRoot.network.connected
                ? 0.28
                : Config.behaviour.hoverBgOpacity
            iconName: NetworkService.wifiIconName(rowRoot.network)
            iconColor: rowRoot.hasNetwork && rowRoot.network.connected
                ? Config.colors.blue
                : Config.styling.text0
            title: rowRoot.hasNetwork
                ? (rowRoot.network.ssid || qsTr("Hidden network"))
                : qsTr("Unavailable")
            subtitle: rowRoot.hasNetwork
                ? `${rowRoot.securityLabel(rowRoot.network)} | ${rowRoot.network.strength || Math.round((rowRoot.network.signalStrength || 0) * 100)}%`
                : qsTr("Network unavailable")
            status: rowRoot.hasNetwork && rowRoot.network.connected
                ? qsTr("Connected")
                : rowRoot.hasNetwork
                    && NetworkService.securityNeedsPsk(rowRoot.network.security)
                    && !NetworkService.isOpenNetwork(rowRoot.network)
                    ? qsTr("Secured")
                    : qsTr("Available")
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
            accessory: Component {
                DashboardDetailToggle {
                    detailed: rowRoot.detailed
                    forcedDetailed: rowRoot.forcedDetailed
                    localDetailed: rowRoot.localDetailed
                    subject: rowRoot.hasNetwork
                        ? (rowRoot.network.ssid || qsTr("network"))
                        : qsTr("network")
                    onToggleRequested: rowRoot.toggleLocalDetails()
                }
            }

            onClicked: {
                if (rowRoot.interactionExpanded && rowRoot.interactionState)
                    rowRoot.interactionState.unlockInteraction();
                else if (rowRoot.hasNetwork && rowRoot.interactionState)
                    rowRoot.interactionState.lockInteractionFor(rowRoot.network);
            }
        }

        Expander {
            id: details
            Layout.fillWidth: true
            expanded: rowRoot.detailExpanded
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

                    InfoRow {
                        Layout.fillWidth: true
                        visible: rowRoot.detailed && rowRoot.network.connected && !!rowRoot.activeInterface
                        iconName: "network-server-symbolic"
                        label: qsTr("Interface")
                        value: rowRoot.activeInterface ? rowRoot.activeInterface.name : ""
                    }

                    InfoRow {
                        Layout.fillWidth: true
                        visible: rowRoot.detailed && rowRoot.network.connected
                            && !!rowRoot.activeInterface && rowRoot.activeInterface.mac !== ""
                        iconName: "network-server-symbolic"
                        label: qsTr("Interface MAC")
                        value: rowRoot.activeInterface ? rowRoot.activeInterface.mac : ""
                    }

                    InfoRow {
                        Layout.fillWidth: true
                        visible: rowRoot.detailed && rowRoot.network.connected && !!rowRoot.activeInterface
                        iconName: "dialog-information-symbolic"
                        label: qsTr("Link state / MTU")
                        value: rowRoot.activeInterface
                            ? `${rowRoot.activeInterface.state} · ${rowRoot.activeInterface.mtu}`
                            : ""
                    }

                    InfoRow {
                        Layout.fillWidth: true
                        visible: rowRoot.detailed && rowRoot.network.connected
                            && !!rowRoot.activeInterface && rowRoot.activeInterface.ipv4.length > 0
                        iconName: "network-server-symbolic"
                        label: qsTr("IPv4")
                        value: rowRoot.activeInterface
                            ? NetworkInterfaces.formatAddresses(rowRoot.activeInterface.ipv4)
                            : ""
                    }

                    InfoRow {
                        Layout.fillWidth: true
                        visible: rowRoot.detailed && rowRoot.network.connected
                            && !!rowRoot.activeInterface && rowRoot.activeInterface.ipv6.length > 0
                        iconName: "network-server-symbolic"
                        label: qsTr("IPv6")
                        value: rowRoot.activeInterface
                            ? NetworkInterfaces.formatAddresses(rowRoot.activeInterface.ipv6)
                            : ""
                    }

                    InfoRow {
                        Layout.fillWidth: true
                        visible: rowRoot.detailed && rowRoot.network.connected
                        iconName: "network-transmit-receive-symbolic"
                        label: qsTr("Connectivity")
                        value: NetworkService.connectivity
                    }

                    InfoRow {
                        Layout.fillWidth: true
                        visible: rowRoot.detailed && rowRoot.network.connected
                            && NetworkInterfaces.lastError !== ""
                        iconName: "dialog-warning-symbolic"
                        label: qsTr("Diagnostics")
                        value: NetworkInterfaces.lastError
                        valueColor: Config.styling.warning
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: rowRoot.detailed
                        text: NetworkService.advancedNetworkInfo(rowRoot.network)
                        color: Config.styling.text2
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }

                    TextField {
                        id: passwordField
                        Layout.fillWidth: true
                        visible: rowRoot.showPasswordInput
                        text: rowRoot.passwordText
                        placeholderText: qsTr("Wi-Fi password")
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
                        Layout.preferredHeight: visible ? 32 : 0
                        implicitHeight: visible ? 32 : 0
                        visible: rowRoot.interactionExpanded
                        spacing: itemSpacing

                        SmallButton {
                            Layout.fillWidth: true
                            text: rowRoot.hasNetwork && rowRoot.network.connected
                                ? qsTr("Disconnect")
                                : qsTr("Connect")
                            onClicked: {
                                if (!rowRoot.hasNetwork) {
                                    if (rowRoot.interactionState)
                                        rowRoot.interactionState.unlockInteraction();
                                    return;
                                }

                                if (rowRoot.network.connected)
                                    NetworkService.disconnectWifi();
                                else
                                    rowRoot.attemptConnect();
                            }
                        }
                    }
                }
            }
        }
    }

    function securityLabel(network) {
        if (!network)
            return qsTr("Unknown");
        if (NetworkService.isOpenNetwork(network))
            return qsTr("Open");
        return network.security;
    }
}
