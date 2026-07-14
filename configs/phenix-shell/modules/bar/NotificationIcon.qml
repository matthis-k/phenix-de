import qs.services

StatusIcon {
    id: root
    iconName: NotificationCenter.doNotDisturbEnabled ? "bell-disabled-symbolic" : "bell-symbolic"
    fallbackIconName: NotificationCenter.doNotDisturbEnabled ? "notifications-disabled-symbolic" : "preferences-system-notifications-symbolic"
    iconColor: {
        if (NotificationCenter.hasCritical)
            return Config.styling.critical;
        if (NotificationCenter.doNotDisturbEnabled)
            return Config.styling.warning;
        return Config.styling.text0;
    }
    badgeText: NotificationCenter.badgeText
    badgeColor: NotificationCenter.hasCritical ? Config.styling.critical : Config.styling.primaryAccent
    tabName: "notifications"
}
