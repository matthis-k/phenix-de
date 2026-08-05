import QtQuick
import QtQuick.Layouts

import qs.services
import qs.components

DashboardPage {
    id: root

    title: qsTr("Notifications")
    subtitle: NotificationCenter.doNotDisturbEnabled
        ? qsTr("Toasts paused")
        : qsTr("Toasts enabled")
    fillHeight: true
    headerAccessory: Component {
        RowLayout {
            spacing: Config.spacing.xs

            Text {
                text: qsTr("Do Not Disturb")
                color: Config.styling.text1
                font.pixelSize: 12
                font.bold: true
            }

            DashboardToggleSwitch {
                Accessible.name: qsTr("Do Not Disturb")
                checked: NotificationCenter.doNotDisturbEnabled
                onToggled: NotificationCenter.setDoNotDisturb(checked)
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Config.spacing.xs

        InfoRow {
            Layout.fillWidth: true
            iconName: NotificationCenter.doNotDisturbEnabled
                ? "notifications-disabled-symbolic"
                : "bell-symbolic"
            iconColor: NotificationCenter.doNotDisturbEnabled
                ? Config.colors.mauve
                : (NotificationCenter.count > 0
                    ? Config.colors.yellow
                    : Config.styling.text1)
            labelColor: iconColor
            label: qsTr("Current notifications")
            value: String(NotificationCenter.count)
            valueColor: iconColor
        }

        ConfirmSmallButton {
            enabled: NotificationCenter.count > 0
            text: qsTr("Clear all")
            confirmText: qsTr("Confirm clear")
            onConfirmed: NotificationCenter.clearAll()
        }
    }

    NotificationFeed {
        Layout.fillWidth: true
        Layout.fillHeight: true
        detailed: true
    }
}
