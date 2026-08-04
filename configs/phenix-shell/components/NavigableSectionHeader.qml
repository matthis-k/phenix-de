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
    property int sectionPadding: Config.spacing.xs
    property int contentSpacing: Config.spacing.xs
    default property alias content: body.data

    signal headerClicked

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
                Layout.alignment: Qt.AlignTop
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
