import QtQuick
import qs.services

DashboardIconButton {
    id: root

    required property bool detailed
    required property bool forcedDetailed
    required property bool localDetailed
    property string subject: qsTr("component")

    signal toggleRequested()

    enabled: !root.forcedDetailed
    opacity: enabled ? 1 : 0.5
    implicitWidth: 24
    implicitHeight: 24
    iconName: root.detailed ? "list-remove-symbolic" : "list-add-symbolic"
    fallbackIconName: iconName
    iconColor: root.localDetailed
        ? Config.styling.primaryAccent
        : (hovered && enabled ? Config.styling.text0 : Config.styling.text2)
    backgroundColor: hovered && enabled ? Config.styling.bg3 : "transparent"
    fillOnHover: true
    indicatorOnHover: false
    active: false
    accessibleName: root.localDetailed
        ? qsTr("Hide details for %1").arg(root.subject)
        : qsTr("Show details for %1").arg(root.subject)
    toolTipText: root.forcedDetailed
        ? qsTr("Details are expanded by a parent or global toggle")
        : accessibleName

    onClicked: root.toggleRequested()
}
