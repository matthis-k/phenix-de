import QtQuick
import QtQuick.Layouts

import qs.animations as Animations
import qs.services
import qs.components

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property string iconName: ""
    property color iconColor: Config.styling.primaryAccent
    property color titleColor: Config.styling.primaryAccent
    property Component accessory: null
    property var screenState: null
    property string targetTab: ""
    property bool navigable: targetTab !== "" && screenState !== null
    property bool compact: false
    property bool showDetailToggle: false
    property bool inheritedDetailed: false
    property bool localDetailed: false
    property int sectionPadding: Config.spacing.xs
    property int contentSpacing: Config.spacing.xs
    property int trailingControlInset: Config.spacing.xs
    property int navigationSlotWidth: 28

    readonly property bool globalDetailed: DashboardPresentation.detailed
    readonly property bool forcedDetailed: globalDetailed || inheritedDetailed
    readonly property bool detailed: forcedDetailed || localDetailed
    readonly property string presentationMode: detailed
        ? DashboardPresentation.detailedMode
        : DashboardPresentation.overviewMode

    default property alias content: body.data

    signal headerClicked

    function toggleLocalDetails() {
        if (!root.showDetailToggle || root.forcedDetailed)
            return;
        root.localDetailed = !root.localDetailed;
    }

    function navigate() {
        if (!root.navigable)
            return;
        root.screenState.openDashboard(root.targetTab);
        root.headerClicked();
    }

    Accessible.description: root.subtitle
    color: Config.styling.bg1
    radius: Config.styling.radius
    clip: true
    implicitHeight: contentColumn.implicitHeight + root.sectionPadding * 2

    ColumnLayout {
        id: contentColumn

        anchors.fill: parent
        anchors.margins: root.sectionPadding
        spacing: root.compact ? 0 : Config.spacing.xs

        RowLayout {
            Layout.fillWidth: true
            spacing: Config.spacing.xs

            ActionButton {
                id: navigationAction

                Layout.fillWidth: true
                Layout.minimumHeight: 36
                focusPolicy: root.navigable
                    ? Qt.TabFocus | Qt.ClickFocus
                    : Qt.NoFocus
                hoverEnabled: root.navigable
                cursorShape: root.navigable ? Qt.PointingHandCursor : Qt.ArrowCursor
                fillOnHover: root.navigable
                indicatorOnHover: root.navigable
                active: false
                backgroundColor: "transparent"
                accessibleName: root.navigable
                    ? qsTr("Open %1").arg(root.title)
                    : root.title
                accessibleDescription: root.subtitle
                onClicked: root.navigate()

                contentItem: RowLayout {
                    spacing: Config.spacing.xs

                    Icon {
                        visible: root.iconName !== ""
                        iconName: root.iconName
                        fallbackIconName: root.iconName
                        color: root.iconColor
                        implicitSize: 18
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.title
                        color: navigationAction.hovered && root.navigable
                            ? Config.styling.secondaryAccent
                            : root.titleColor
                        font.pixelSize: 16
                        font.bold: true
                        elide: Text.ElideRight

                        Animations.StateColorBehavior on color {}
                    }
                }
            }

            Item {
                id: accessorySlot

                visible: root.accessory !== null
                Layout.preferredWidth: accessoryLoader.item
                    ? accessoryLoader.item.implicitWidth + root.trailingControlInset
                    : 0
                Layout.minimumWidth: Layout.preferredWidth
                Layout.maximumWidth: Layout.preferredWidth
                Layout.preferredHeight: accessoryLoader.item
                    ? accessoryLoader.item.implicitHeight
                    : 0
                Layout.minimumHeight: Layout.preferredHeight
                Layout.maximumHeight: Layout.preferredHeight
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                Loader {
                    id: accessoryLoader

                    active: root.accessory !== null
                    sourceComponent: root.accessory
                    width: item ? item.implicitWidth : 0
                    height: item ? item.implicitHeight : 0
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            DashboardDetailToggle {
                visible: root.showDetailToggle
                Layout.alignment: Qt.AlignVCenter
                detailed: root.detailed
                forcedDetailed: root.forcedDetailed
                localDetailed: root.localDetailed
                subject: root.title
                onToggleRequested: root.toggleLocalDetails()
            }

            DashboardIconButton {
                visible: root.navigable
                Layout.preferredWidth: root.navigationSlotWidth
                Layout.minimumWidth: root.navigationSlotWidth
                Layout.maximumWidth: root.navigationSlotWidth
                Layout.preferredHeight: 28
                Layout.alignment: Qt.AlignVCenter
                iconName: "go-next-symbolic"
                fallbackIconName: iconName
                iconColor: hovered ? Config.styling.secondaryAccent : Config.styling.text1
                backgroundColor: hovered ? Config.styling.bg3 : "transparent"
                active: hovered
                fillOnHover: true
                indicatorOnHover: false
                accessibleName: qsTr("Open %1").arg(root.title)
                onClicked: root.navigate()
            }
        }

        Rectangle {
            visible: !root.compact
            Layout.fillWidth: true
            implicitHeight: visible ? 1 : 0
            color: Config.styling.bg3
        }

        DashboardSectionContent {
            id: body
            visible: !root.compact
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignTop
            contentSpacing: root.contentSpacing
        }
    }
}
