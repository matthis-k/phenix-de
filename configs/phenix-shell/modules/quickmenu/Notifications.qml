import QtQuick
import QtQuick.Layouts

import qs.services
import qs.components

DashboardPage {
    id: root

    title: "Notifications"
    subtitle: NotificationCenter.doNotDisturbEnabled ? "Toasts paused" : "Tracked notification history and actions"
    headerAccessory: Component {
        DashboardToggleSwitch {
            checked: NotificationCenter.toastsEnabled
            onToggled: NotificationCenter.toastsEnabled = checked
        }
    }
    fillHeight: true

    DashboardSection {
        Layout.fillWidth: true
        Layout.fillHeight: true
        title: "Inbox"
        headerAccessory: Component {
            SmallButton {
                enabled: NotificationCenter.count > 0
                accentColor: Config.styling.good
                text: "Clear all"
                onClicked: NotificationCenter.clearAll()
            }
        }

        NotificationFeed {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
