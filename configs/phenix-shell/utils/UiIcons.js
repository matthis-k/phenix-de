pragma library

// Explicit shell glyph aliases. Unmapped names use the desktop icon theme.
const names = {
    "network-wireless-symbolic": "wifi",
    "network-wireless-offline-symbolic": "wifi-off",
    "bluetooth-symbolic": "bluetooth",
    "bluetooth-disabled-symbolic": "bluetooth-off",
    "audio-volume-high-symbolic": "volume-2",
    "audio-volume-medium-symbolic": "volume-1",
    "audio-volume-low-symbolic": "volume-1",
    "audio-volume-muted-symbolic": "volume-x",
    "bell-symbolic": "bell",
    "notifications-disabled-symbolic": "bell-off",
    "preferences-system-notifications-symbolic": "bell",
    "utilities-system-monitor-symbolic": "activity",
    "drive-harddisk-symbolic": "hard-drive",
    "computer-symbolic": "monitor",
    "video-display-symbolic": "monitor",
    "system-shutdown-symbolic": "power",
    "system-reboot-symbolic": "refresh-cw",
    "system-suspend-hibernate-symbolic": "moon",
    "system-log-out-symbolic": "log-out",
    "view-refresh-symbolic": "refresh-cw",
    "go-up-symbolic": "arrow-up",
    "go-down-symbolic": "arrow-down",
    "go-next-symbolic": "chevron-right",
    "list-add-symbolic": "plus",
    "list-remove-symbolic": "minus",
    "network-wired-symbolic": "network",
    "network-transmit-receive-symbolic": "arrow-down-up",
    "network-server-symbolic": "server",
    "dialog-warning-symbolic": "triangle-alert",
    "dialog-warning": "triangle-alert",
    "dialog-information-symbolic": "info",
    "audio-speakers-symbolic": "volume-2",
    "audio-card-symbolic": "volume-2",
    "window-close-symbolic": "x",
    "network-wireless-signal-excellent-symbolic": "wifi",
    "battery-good-symbolic": "battery",
    "battery-missing-symbolic": "battery",
    "screen-brightness-symbolic": "sun",
    "display-brightness-symbolic": "sun",
    "network-vpn-symbolic": "shield-check"
};

function lookup(name) {
    return names[String(name || "")] || "";
}
