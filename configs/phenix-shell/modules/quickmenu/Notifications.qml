import QtQuick
import QtQuick.Layouts

import qs.services
import qs.components

DashboardPage {
    id: root

    title: "Notifications"
    subtitle: NotificationCenter.doNotDisturbEnabled
        ? "Toasts paused"
        : (root.detailed
            ? "Tracked notification history, metadata, and actions"
            : "Notification inbox and primary actions")
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
        subtitle: root.detailed
            ? qsTr("Full retained notification history")
            : qsTr("Current notifications")
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
