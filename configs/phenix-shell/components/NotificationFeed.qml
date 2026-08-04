import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications

import qs.animations as Animations
import qs.services

Item {
    id: root

    property bool showControls: false
    property bool compact: false
    property bool detailed: false
    property int maxEntries: -1
    property string emptyTitle: qsTr("No notifications")
    property string emptyDescription: NotificationCenter.doNotDisturbEnabled
        ? qsTr("Do Not Disturb is currently enabled.")
        : qsTr("You are all caught up.")
    property string expandedKey: ""

    readonly property var orderedNotifications: {
        const items = NotificationCenter.notifications.slice().reverse();
        return maxEntries > 0 ? items.slice(0, maxEntries) : items;
    }

    function notificationKey(notification, index) {
        if (!notification)
            return `notification-${index}`;
        return String(notification.id
            || notification.replacesId
            || notification.timestamp
            || `${notification.appName}:${notification.summary}:${index}`);
    }

    implicitWidth: parent ? parent.width : 320
    implicitHeight: controls.implicitHeight + listContainer.implicitHeight

    ColumnLayout {
        anchors.fill: parent
        spacing: Config.spacing.xs

        RowLayout {
            id: controls
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? clearAllButton.implicitHeight : 0
            visible: root.showControls
            spacing: Config.spacing.xs

            Item { Layout.fillWidth: true }

            ConfirmSmallButton {
                id: clearAllButton
                enabled: NotificationCenter.count > 0
                text: qsTr("Clear all")
                confirmText: qsTr("Confirm clear")
                onConfirmed: NotificationCenter.clearAll()
            }
        }

        Item {
            id: listContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitHeight: emptyState.visible ? 120 : Math.min(feedColumn.implicitHeight, 320)

            Flickable {
                anchors.fill: parent
                flickableDirection: Flickable.VerticalFlick
                contentWidth: width
                contentHeight: feedColumn.implicitHeight
                clip: true

                ColumnLayout {
                    id: feedColumn
                    width: parent.width
                    spacing: Config.spacing.xs

                    Repeater {
                        model: root.orderedNotifications

                        delegate: Rectangle {
                            id: notificationCard

                            required property var modelData
                            required property int index
                            readonly property var notification: modelData
                            readonly property string notificationKey: root.notificationKey(notification, index)
                            readonly property bool expanded: root.detailed
                                || root.expandedKey === notificationKey
                            readonly property bool hovered: cardHover.hovered

                            Layout.fillWidth: true
                            color: hovered ? Config.styling.bg3 : Config.styling.bg2
                            radius: Config.styling.radius
                            implicitWidth: feedColumn.width
                            implicitHeight: body.implicitHeight + Config.spacing.xs * 2

                            Animations.StateColorBehavior on color {}

                            HoverHandler {
                                id: cardHover
                                cursorShape: Qt.ArrowCursor
                            }

                            ColumnLayout {
                                id: body
                                anchors.fill: parent
                                anchors.margins: Config.spacing.xs
                                spacing: Config.spacing.xs

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Config.spacing.xs

                                    ActionButton {
                                        id: inspectionAction

                                        Layout.fillWidth: true
                                        Layout.minimumHeight: 36
                                        backgroundColor: "transparent"
                                        active: notificationCard.expanded
                                        accessibleName: notificationCard.expanded
                                            ? qsTr("Collapse %1").arg(notification.summary || notification.appName || qsTr("notification"))
                                            : qsTr("Inspect %1").arg(notification.summary || notification.appName || qsTr("notification"))
                                        onClicked: {
                                            root.expandedKey = notificationCard.expanded && !root.detailed
                                                ? ""
                                                : notificationCard.notificationKey;
                                        }

                                        contentItem: RowLayout {
                                            spacing: Config.spacing.xs

                                            Icon {
                                                iconName: notification.appIcon
                                                    || "preferences-system-notifications-symbolic"
                                                color: NotificationCenter.urgencyColor(notification)
                                                implicitSize: 18
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: notification.summary
                                                        || notification.appName
                                                        || qsTr("Notification")
                                                    color: Config.styling.text0
                                                    font.pixelSize: root.compact ? 13 : 14
                                                    font.bold: true
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    visible: notification.appName
                                                        && notification.appName !== notification.summary
                                                    text: notification.appName
                                                    color: Config.styling.text2
                                                    font.pixelSize: 11
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            Badge {
                                                visible: notification.urgency === NotificationUrgency.Critical
                                                text: qsTr("Urgent")
                                                badgeColor: Config.styling.critical
                                            }

                                            Icon {
                                                iconName: notificationCard.expanded
                                                    ? "go-down-symbolic"
                                                    : "go-next-symbolic"
                                                color: Config.styling.text1
                                                implicitSize: 16
                                            }
                                        }
                                    }

                                    ActionButton {
                                        implicitWidth: 32
                                        implicitHeight: 32
                                        backgroundColor: "transparent"
                                        accessibleName: qsTr("Dismiss %1").arg(
                                            notification.summary
                                                || notification.appName
                                                || qsTr("notification"))
                                        onClicked: NotificationCenter.dismiss(notification)

                                        contentItem: Icon {
                                            iconName: "window-close-symbolic"
                                            color: Config.styling.text1
                                            implicitSize: 16
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: notification.body !== ""
                                    text: NotificationCenter.renderBody(notification.body)
                                    textFormat: Text.RichText
                                    color: Config.styling.text1
                                    font.pixelSize: root.compact ? 12 : 13
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: notificationCard.expanded
                                        ? -1
                                        : (root.compact ? 3 : 4)
                                    elide: notificationCard.expanded
                                        ? Text.ElideNone
                                        : Text.ElideRight
                                    onLinkActivated: link => Qt.openUrlExternally(link)

                                    TapHandler {
                                        acceptedButtons: Qt.LeftButton
                                        onTapped: {
                                            if (!root.detailed) {
                                                root.expandedKey = notificationCard.expanded
                                                    ? ""
                                                    : notificationCard.notificationKey;
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    visible: notificationCard.expanded
                                    spacing: Config.spacing.xs

                                    ActionButton {
                                        Layout.fillWidth: true
                                        implicitHeight: 32
                                        text: qsTr("Open")
                                        accessibleName: qsTr("Open %1").arg(
                                            notification.summary
                                                || notification.appName
                                                || qsTr("notification"))
                                        accentColor: Config.styling.primaryAccent
                                        onClicked: NotificationCenter.invokeDefaultAction(notification)

                                        contentItem: Text {
                                            text: parent.text
                                            color: Config.styling.text0
                                            font.pixelSize: 12
                                            font.bold: true
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }

                                    Repeater {
                                        model: notification.actions

                                        delegate: ActionButton {
                                            required property var modelData
                                            readonly property var notificationAction: modelData

                                            Layout.fillWidth: true
                                            implicitHeight: 32
                                            text: notificationAction.text
                                            accessibleName: notificationAction.text
                                            accentColor: Config.styling.primaryAccent
                                            onClicked: notificationAction.invoke()

                                            contentItem: Text {
                                                text: parent.text
                                                color: Config.styling.text0
                                                font.pixelSize: 12
                                                font.bold: true
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            EmptyState {
                id: emptyState
                anchors.fill: parent
                visible: root.orderedNotifications.length === 0
                opacity: visible ? 1 : 0
                title: root.emptyTitle
                description: root.emptyDescription

                Animations.RevealBehavior on opacity {}
            }
        }
    }
}
