import qs.services

StatusIcon {
    id: root
    visible: PowerService.hasBattery

    iconName: PowerService.iconName
    iconColor: PowerService.iconColor
    tabName: "energy"
}