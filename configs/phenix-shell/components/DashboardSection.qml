import QtQuick
import QtQuick.Layouts
import qs.animations as Animations
import qs.services

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property string iconName: ""
    property color iconColor: Config.styling.text1
    property color titleColor: Config.styling.text0
    property color subtitleColor: Config.styling.text2
    property bool titleBold: true
    property bool subtitleBold: false
    property bool collapsible: false
    property bool collapsed: false
    property bool showDetailToggle: false
    property bool inheritedDetailed: false
    property bool localDetailed: false
    property Component summary: null
    property Component headerAccessory: null
    property bool showHeader: title !== ""
        || subtitle !== ""
        || iconName !== ""
        || summary !== null
        || headerAccessory !== null
        || collapsible
        || showDetailToggle
    property int sectionPadding: Config.spacing.xs
    property int contentSpacing: Config.spacing.xs

    readonly property bool globalDetailed: DashboardPresentation.detailed
    readonly property bool forcedDetailed: globalDetailed || inheritedDetailed
    readonly property bool detailed: forcedDetailed || localDetailed
    readonly property string presentationMode: detailed
        ? DashboardPresentation.detailedMode
        : DashboardPresentation.overviewMode
    readonly property real bodyHeight: bodyClip.implicitHeight
    readonly property bool showingBody: bodyHeight > 0
    readonly property int separatorHeight: showHeader && showingBody ? 1 : 0
    readonly property int bodyTopGap: showHeader && showingBody ? Config.spacing.xs : 0
    default property alias content: body.data

    function toggleLocalDetails() {
        if (!root.showDetailToggle || root.forcedDetailed)
            return;
        root.localDetailed = !root.localDetailed;
    }

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
        iconName: root.iconName
        iconColor: root.iconColor
        titleColor: root.titleColor
        subtitleColor: root.subtitleColor
        titleBold: root.titleBold
        subtitleBold: root.subtitleBold
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
                Layout.maximumWidth: Math.max(root.width - 136, 0)
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
                visible: root.showDetailToggle
                enabled: !root.forcedDetailed
                opacity: enabled ? 1 : 0.5
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                Layout.alignment: Qt.AlignVCenter
                iconName: root.detailed ? "go-down-symbolic" : "go-next-symbolic"
                fallbackIconName: iconName
                iconColor: root.localDetailed
                    ? Config.styling.primaryAccent
                    : (hovered && enabled ? Config.styling.text0 : Config.styling.text2)
                backgroundColor: hovered && enabled ? Config.styling.bg3 : "transparent"
                fillOnHover: true
                indicatorOnHover: false
                active: false
                accessibleName: root.localDetailed
                    ? qsTr("Hide details for %1").arg(root.title)
                    : qsTr("Show details for %1").arg(root.title)
                toolTipText: root.forcedDetailed
                    ? qsTr("Details are expanded by a parent or global toggle")
                    : accessibleName
                onClicked: root.toggleLocalDetails()
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
                accessibleName: root.collapsed
                    ? qsTr("Show %1").arg(root.title)
                    : qsTr("Hide %1").arg(root.title)
                onClicked: root.collapsed = !root.collapsed

                Animations.StateColorBehavior on iconColor {
                }
            }
        }
    }
}
