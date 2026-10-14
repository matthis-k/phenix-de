import QtQuick
import QtQuick.Layouts
import qs.services

// Higher-level header+body control composed from the existing Expander.
// Its body is lazy only when callers explicitly insert a Loader.
ColumnLayout {
    id: root

    property string title: ""
    property string description: ""
    property string iconName: ""
    property bool expanded: false
    property int bodySpacing: Config.spacing.xs
    property int bodyPadding: Config.spacing.xs
    default property alias content: body.data
    signal toggled(bool expanded)

    spacing: 0
    Layout.fillWidth: true
    implicitWidth: Math.max(header.implicitWidth, disclosure.implicitWidth)

    ActionButton {
        id: header
        Layout.fillWidth: true
        implicitHeight: Math.max(42, headerContent.implicitHeight + Config.spacing.xs * 2)
        text: root.title
        accessibleName: root.title
        accessibleDescription: root.description
        active: root.expanded
        highlightSide: ActiveIndicator.Side.Left
        indicatorOnHover: false
        onClicked: {
            root.expanded = !root.expanded;
            root.toggled(root.expanded);
        }

        contentItem: RowLayout {
            id: headerContent
            spacing: Config.spacing.xs

            Icon {
                visible: root.iconName !== ""
                iconName: root.iconName
                color: Config.styling.text1
                implicitSize: Config.iconSizes.section
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: root.title
                    color: Config.styling.text0
                    font.family: Config.typography.mono
                    font.pixelSize: Config.typography.label
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    visible: text !== ""
                    Layout.fillWidth: true
                    text: root.description
                    color: Config.styling.text1
                    font.pixelSize: Config.typography.secondary
                    wrapMode: Text.WordWrap
                }
            }

            Icon {
                iconName: root.expanded ? "material:expand_less" : "material:expand_more"
                fallbackIconName: root.expanded ? "go-up-symbolic" : "go-down-symbolic"
                color: Config.styling.text1
                implicitSize: Config.iconSizes.control
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    Expander {
        id: disclosure
        Layout.fillWidth: true
        expanded: root.expanded
        animationEnabled: Config.motion.medium > 0

        Item {
            width: parent.width
            implicitHeight: body.implicitHeight + root.bodyPadding * 2

            ColumnLayout {
                id: body
                width: parent.width
                y: root.bodyPadding
                spacing: root.bodySpacing
            }
        }
    }
}
