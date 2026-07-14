import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications

import qs.animations as Animations
import qs.services

Item {
    id: root

    property bool showControls: false
    property bool compact: false
    property int maxEntries: -1
    property string emptyTitle: "No notifications"
    property string emptyDescription: NotificationCenter.doNotDisturbEnabled ? "Do Not Disturb is currently enabled." : "You are all caught up."

    readonly property var orderedNotifications: {
        const items = NotificationCenter.notifications.slice().reverse();
        return maxEntries > 0 ? items.slice(0, maxEntries) : items;
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

            Item {
                Layout.fillWidth: true
            }

            SmallButton {
                id: clearAllButton
                enabled: NotificationCenter.count > 0
                accentColor: Config.styling.good
                onClicked: NotificationCenter.clearAll()
                text: "Clear all"
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
                            required property var modelData
                            readonly property var notification: modelData
                            readonly property bool hovered: rowHover.hovered

                            Layout.fillWidth: true
                            color: hovered ? Config.styling.bg3 : Config.styling.bg2
                            radius: Config.styling.radius
                            implicitWidth: feedColumn.width
                            implicitHeight: body.implicitHeight + Config.spacing.xs * 2

                            Animations.StateColorBehavior on color {
                            }

                            HoverHandler {
                                id: rowHover
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                acceptedButtons: Qt.LeftButton
                                onTapped: NotificationCenter.invokeDefaultAction(notification)
                            }

                            ColumnLayout {
                                id: body
                                anchors.fill: parent
                                anchors.margins: Config.spacing.xs
                                spacing: Config.spacing.xs

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Config.spacing.xs

                                    Icon {
                                        iconName: notification.appIcon || "preferences-system-notifications-symbolic"
                                        color: NotificationCenter.urgencyColor(notification)
                                        implicitSize: 18
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: notification.summary || notification.appName || "Notification"
                                        color: Config.styling.text0
                                        font.pixelSize: root.compact ? 13 : 14
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Badge {
                                        text: notification.urgency === NotificationUrgency.Critical ? "Urgent" : ""
                                        badgeColor: Config.styling.critical
                                    }

                                    ActionButton {
                                        implicitWidth: 20
                                        implicitHeight: 20
                                        backgroundColor: "transparent"
                                        highlightThickness: 0
                                        onClicked: NotificationCenter.dismiss(notification)

                                        contentItem: Icon {
                                            iconName: "window-close-symbolic"
                                            color: Config.styling.text1
                                            implicitSize: 14
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
                                    maximumLineCount: root.compact ? 4 : -1
                                    elide: root.compact ? Text.ElideRight : Text.ElideNone
                                    onLinkActivated: link => Qt.openUrlExternally(link)
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    visible: !root.compact && notification.actions.length > 0
                                    spacing: Config.spacing.xs

                                    Repeater {
                                        model: notification.actions

                                        delegate: ActionButton {
                                            required property var modelData
                                            readonly property var notificationAction: modelData

                                            Layout.fillWidth: true
                                            accentColor: Config.styling.primaryAccent
                                            onClicked: notificationAction.invoke()

                                            contentItem: Text {
                                                text: notificationAction.text
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

                Animations.RevealBehavior on opacity {
                }
            }
        }
    }
}
