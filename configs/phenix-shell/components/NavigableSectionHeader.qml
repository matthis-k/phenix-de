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
                color: root.navigable
                    ? (hoverHighlight ? Config.styling.secondaryAccent : root.titleColor)
                    : root.titleColor
                font.pixelSize: 16
                font.bold: true
                elide: Text.ElideRight

                property bool hoverHighlight: false

                Animations.StateColorBehavior on color {
                }

                MouseArea {
                    anchors.fill: parent
                    visible: root.navigable
                    cursorShape: root.navigable ? Qt.PointingHandCursor : Qt.ArrowCursor
                    hoverEnabled: root.navigable

                    onClicked: {
                        if (root.navigable) {
                            root.screenState.openDashboard(root.targetTab);
                            root.headerClicked();
                        }
                    }

                    onEntered: {
                        if (root.navigable)
                            parent.hoverHighlight = true;
                    }
                    onExited: {
                        if (root.navigable)
                            parent.hoverHighlight = false;
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
