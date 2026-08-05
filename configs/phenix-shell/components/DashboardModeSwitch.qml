import QtQuick
import qs.services

DashboardIconButton {
    id: root

    property string mode: "overview"
    readonly property bool detailed: mode === "detailed"
    signal modeRequested(string mode)

    implicitWidth: 28
    implicitHeight: 28
    iconName: root.detailed ? "list-remove-symbolic" : "list-add-symbolic"
    fallbackIconName: root.detailed ? "zoom-out-symbolic" : "zoom-in-symbolic"
    iconColor: root.detailed
        ? Config.styling.primaryAccent
        : (hovered ? Config.styling.text0 : Config.styling.text1)
    backgroundColor: hovered || root.detailed ? Config.styling.bg3 : "transparent"
    borderWidth: root.detailed ? 1 : 0
    borderColor: root.detailed ? Config.styling.primaryAccent : "transparent"
    active: false
    fillOnHover: true
    indicatorOnHover: false

    accessibleName: root.detailed
        ? qsTr("Collapse all dashboard details")
        : qsTr("Expand all dashboard details")
    toolTipText: accessibleName

    onClicked: root.modeRequested(root.detailed ? "overview" : "detailed")
}
