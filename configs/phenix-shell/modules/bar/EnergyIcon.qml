import qs.services

StatusIcon {
    id: root
    visible: PowerService.hasBattery

    label: qsTr("Battery and Power")
    iconName: PowerService.iconName
    iconColor: PowerService.iconColor
    tabName: "energy"
}
