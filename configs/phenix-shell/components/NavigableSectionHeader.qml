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
    property bool showDetailToggle: false
    property bool inheritedDetailed: false
    property bool localDetailed: false
    property int sectionPadding: Config.spacing.xs
    property int contentSpacing: Config.spacing.xs

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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.sectionPadding
        spacing: Config.spacing.xs

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

                    Icon {
                        visible: root.navigable
                        iconName: "go-next-symbolic"
                        fallbackIconName: "go-next-symbolic"
                        color: Config.styling.text1
                        implicitSize: 16
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }

            Loader {
                active: root.accessory !== null
                sourceComponent: root.accessory
                Layout.preferredWidth: item ? item.implicitWidth : 0
                Layout.preferredHeight: item ? item.implicitHeight : 0
                Layout.alignment: Qt.AlignVCenter
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
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Config.styling.bg3
        }

        DashboardSectionContent {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignTop
            contentSpacing: root.contentSpacing
        }
    }
}
