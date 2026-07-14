import QtQuick
import QtQuick.Layouts
import qs.animations as Animations
import qs.services

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property bool collapsible: false
    property bool collapsed: false
    property Component summary: null
    property Component headerAccessory: null
    property bool showHeader: title !== "" || subtitle !== "" || summary !== null || headerAccessory !== null || collapsible
    property int sectionPadding: Config.spacing.xs
    property int contentSpacing: Config.spacing.xs
    readonly property real bodyHeight: bodyClip.implicitHeight
    readonly property bool showingBody: bodyHeight > 0
    readonly property int separatorHeight: showHeader && showingBody ? 1 : 0
    readonly property int bodyTopGap: showHeader && showingBody ? Config.spacing.xs : 0
    default property alias content: body.data

    color: Config.styling.bg1
    radius: Config.styling.radius
    clip: true
    Layout.fillWidth: true
    implicitWidth: Math.max(header.implicitWidth, body.implicitWidth) + sectionPadding * 2
    implicitHeight: sectionPadding * 2
        + (showHeader ? header.implicitHeight : 0)
        + bodyTopGap
        + separatorHeight
        + bodyTopGap
        + bodyHeight

    DashboardSectionHeader {
        id: header
        x: root.sectionPadding
        y: root.sectionPadding
        width: Math.max(0, root.width - root.sectionPadding * 2)
        visible: root.showHeader
        title: root.title
        subtitle: root.subtitle
        accessory: headerAccessoryComponent
    }

    Rectangle {
        id: separator
        x: root.sectionPadding
        y: header.y + (root.showHeader ? header.implicitHeight : 0) + root.bodyTopGap
        width: Math.max(0, root.width - root.sectionPadding * 2)
        height: root.separatorHeight
        visible: root.showHeader && (height > 0 || bodyClip.progress > 0)
        color: Config.styling.bg3
        opacity: bodyClip.progress

        Animations.RevealBehavior on opacity {
            duration: Config.motion.micro
        }
    }

    Expander {
        id: bodyClip

        x: root.sectionPadding
        y: separator.y + separator.height + root.bodyTopGap
        width: Math.max(0, root.width - root.sectionPadding * 2)
        expanded: !root.collapsed
        slideDistance: Config.spacing.sm

        DashboardSectionContent {
            id: body
            width: parent.width
            contentSpacing: root.contentSpacing
        }
    }

    Component {
        id: headerAccessoryComponent

        RowLayout {
            spacing: Config.spacing.xs

            Loader {
                active: root.summary !== null
                sourceComponent: root.summary
                Layout.preferredWidth: item ? item.implicitWidth : 0
                Layout.maximumWidth: Math.max(root.width - 112, 0)
                Layout.preferredHeight: item ? item.implicitHeight : 0
                Layout.alignment: Qt.AlignVCenter
            }

            Loader {
                active: root.headerAccessory !== null
                sourceComponent: root.headerAccessory
                Layout.preferredWidth: item ? item.implicitWidth : 0
                Layout.preferredHeight: item ? item.implicitHeight : 0
                Layout.alignment: Qt.AlignVCenter
            }

            DashboardIconButton {
                visible: root.collapsible
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                Layout.alignment: Qt.AlignVCenter
                iconName: root.collapsed ? "go-next-symbolic" : "go-down-symbolic"
                fallbackIconName: iconName
                iconColor: hovered ? Config.styling.activeIndicator : Config.styling.text0
                backgroundColor: hovered ? Config.styling.bg3 : Config.styling.bg2
                active: hovered
                fillOnHover: true
                indicatorOnHover: false
                onClicked: root.collapsed = !root.collapsed

                Animations.StateColorBehavior on iconColor {
                }
            }
        }
    }
}
