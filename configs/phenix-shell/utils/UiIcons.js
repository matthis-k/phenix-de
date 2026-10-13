pragma library

// Legacy Freedesktop symbolic names to Material Symbols (Outlined by default).
// New controls should use material:<name> directly.
const names = {
    "network-wireless-symbolic": "wifi",
    "network-wireless-offline-symbolic": "wifi_off",
    "bluetooth-symbolic": "bluetooth",
    "bluetooth-disabled-symbolic": "bluetooth_disabled",
    "audio-volume-high-symbolic": "volume_up",
    "audio-volume-medium-symbolic": "volume_down",
    "audio-volume-low-symbolic": "volume_mute",
    "audio-volume-muted-symbolic": "volume_off",
    "bell-symbolic": "notifications",
    "notifications-disabled-symbolic": "notifications_off",
    "preferences-system-notifications-symbolic": "notifications",
    "utilities-system-monitor-symbolic": "monitoring",
    "drive-harddisk-symbolic": "hard_drive",
    "computer-symbolic": "desktop_windows",
    "video-display-symbolic": "desktop_windows",
    "system-shutdown-symbolic": "power_settings_new",
    "system-reboot-symbolic": "restart_alt",
    "system-suspend-hibernate-symbolic": "bedtime",
    "system-log-out-symbolic": "logout",
    "view-refresh-symbolic": "refresh",
    "go-up-symbolic": "arrow_upward",
    "go-down-symbolic": "arrow_downward",
    "go-next-symbolic": "chevron_right",
    "list-add-symbolic": "add",
    "list-remove-symbolic": "remove",
    "network-wired-symbolic": "lan",
    "network-transmit-receive-symbolic": "swap_vert",
    "network-server-symbolic": "dns",
    "dialog-warning-symbolic": "warning",
    "dialog-warning": "warning",
    "dialog-information-symbolic": "info",
    "audio-speakers-symbolic": "volume_up",
    "audio-card-symbolic": "volume_up",
    "window-close-symbolic": "close",
    "network-wireless-signal-excellent-symbolic": "wifi",
    "battery-good-symbolic": "battery_full",
    "battery-missing-symbolic": "battery_full",
    "screen-brightness-symbolic": "light_mode",
    "display-brightness-symbolic": "light_mode",
    "network-vpn-symbolic": "vpn_lock"
};

function lookup(name) {
    return names[String(name || "")] || "";
}
