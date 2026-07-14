import QtQuick
import QtQuick.Layouts
import qs.animations as Animations
import qs.services

ActionButton {
    id: root

    property string labelText: ""
    property string iconName: ""
    property string fallbackIconName: iconName
    property color iconColor: Config.styling.text0
    property bool expanded: hasLabel && (hovered || active)
    property int compactWidth: parent ? parent.height : 32
    property int expandedWidth: 160
    readonly property bool hasLabel: labelText.length > 0
    readonly property bool expandedWithLabel: hasLabel && (expanded || active)

    implicitWidth: expandedWithLabel ? expandedWidth : compactWidth
    implicitHeight: parent ? parent.height : 32

    Animations.ExpandBehavior on implicitWidth {
    }

    contentItem: Item {
        RowLayout {
            id: contentRow
            spacing: root.hasLabel ? Config.spacing.xxs : 0
            width: root.expandedWithLabel ? Math.max(0, parent.width - Config.spacing.xs * 2) : implicitWidth
            height: parent.height
            x: root.expandedWithLabel ? Config.spacing.xs : Math.round((parent.width - width) / 2)
            anchors.verticalCenter: parent.verticalCenter

            Animations.ShiftBehavior on x {
            }

            Icon {
                id: buttonIcon
                iconName: root.iconName
                fallbackIconName: root.fallbackIconName
                color: root.active ? Config.styling.primaryAccent : root.iconColor
                implicitSize: root.height * 0.7
                Layout.alignment: Qt.AlignVCenter

                Animations.StateColorBehavior on color {
                }
            }

            Text {
                id: buttonLabel
                text: root.labelText
                color: root.active ? Config.styling.primaryAccent : Config.styling.text0
                font.pixelSize: 13
                font.bold: root.active
                elide: Text.ElideRight
                opacity: root.expandedWithLabel ? 1 : 0
                visible: root.hasLabel && (root.expandedWithLabel || opacity > 0)
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter

                Animations.RevealBehavior on opacity {
                }
            }
        }
    }
}
