import qs.services

StatusIcon {
    id: root
    label: qsTr("System Monitor")
    iconName: "utilities-system-monitor-symbolic"
    iconColor: {
        if (Stats.cpuPercent >= 90 || Stats.memoryPercent >= 90)
            return Config.styling.critical;
        if (Stats.cpuPercent >= 70 || Stats.memoryPercent >= 75)
            return Config.styling.warning;
        return Config.styling.text0;
    }
    tabName: "stats"
}
