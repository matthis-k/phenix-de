import QtQuick
import QtQuick.Layouts
import qs.animations as Animations
import qs.services

ActionButton {
    id: root

    property string iconName: ""
    property string fallbackIconName: iconName
    property string title: ""
    property string subtitle: ""
    property string status: ""
    property color iconColor: Config.styling.text0
    property color titleColor: Config.styling.text0
    property color subtitleColor: Config.styling.text2
    property color statusColor: Config.styling.text1
    property int iconSlotWidth: 28
    property int iconSize: 22
    property int titleSize: 16
    property int subtitleSize: 12
    property int statusSize: 12
    property int contentSpacing: Config.spacing.sm
    property int textSpacing: 0
    property int minimumRowHeight: 36
    property int iconAlignment: Qt.AlignVCenter
    property int statusAlignment: Qt.AlignVCenter
    readonly property bool hasIcon: iconName !== ""
    readonly property bool hasStatus: status !== ""

    Layout.fillWidth: true
    horizontalPadding: Config.spacing.xs
    verticalPadding: Config.spacing.xs
    implicitHeight: Math.max(minimumRowHeight, rowContent.implicitHeight + verticalPadding * 2)
    highlightSide: ActiveIndicator.Side.Left
    highlightAnimationMode: ActiveIndicator.AnimationMode.GrowAlong
    highlightThickness: Config.spacing.xxs

    contentItem: Item {
        implicitWidth: rowContent.implicitWidth + root.horizontalPadding * 2
        implicitHeight: root.implicitHeight

        RowLayout {
            id: rowContent
            anchors {
                fill: parent
                leftMargin: root.horizontalPadding
                rightMargin: root.horizontalPadding
                topMargin: root.verticalPadding
                bottomMargin: root.verticalPadding
            }
            spacing: root.contentSpacing

            Item {
                visible: root.hasIcon
                Layout.preferredWidth: root.hasIcon ? root.iconSlotWidth : 0
                Layout.minimumWidth: root.hasIcon ? root.iconSlotWidth : 0
                Layout.maximumWidth: root.hasIcon ? root.iconSlotWidth : 0
                Layout.preferredHeight: root.iconSize
                Layout.alignment: root.iconAlignment

                Loader {
                    anchors.fill: parent
                    active: root.hasIcon

                    sourceComponent: Icon {
                        iconName: root.iconName
                        fallbackIconName: root.fallbackIconName
                    color: root.iconColor
                    implicitSize: root.iconSize

                    Animations.StateColorBehavior on color {
                    }
                }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: root.textSpacing

                Text {
                    Layout.fillWidth: true
                    text: root.title
                    color: root.titleColor
                    font.bold: true
                    font.pixelSize: root.titleSize
                    elide: Text.ElideRight

                    Animations.StateColorBehavior on color {
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.subtitle
                    color: root.subtitleColor
                    font.pixelSize: root.subtitleSize
                    elide: Text.ElideRight

                    Animations.StateColorBehavior on color {
                    }
                }
            }

            Text {
                visible: root.hasStatus
                Layout.alignment: root.statusAlignment
                text: root.status
                color: root.statusColor
                font.pixelSize: root.statusSize
                font.bold: true

                Animations.StateColorBehavior on color {
                }
            }
        }
    }
}
