import QtQuick
import QtQuick.Layouts
import qs.animations as Animations
import qs.services

Item {
    id: root

    property string label: ""
    property string subtitle: ""
    property string iconName: ""
    property color iconColor: Config.styling.text0
    property bool checked: false
    property int switchSlotWidth: 58

    signal toggled(bool checked)

    implicitWidth: row.implicitWidth
    implicitHeight: Math.max(44, row.implicitHeight + Config.spacing.xs * 2)

    Rectangle {
        anchors.fill: parent
        color: rowMouse.containsMouse && root.enabled ? Config.styling.bg4 : Config.styling.bg3
        radius: Config.styling.radius

        Animations.StateColorBehavior on color {
        }
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        z: 2
        enabled: root.enabled
        hoverEnabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.checked = !root.checked;
            root.toggled(root.checked);
        }
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: Config.spacing.xs
        spacing: Config.spacing.sm

        Icon {
            visible: root.iconName !== ""
            iconName: root.iconName
            color: root.iconColor
            implicitSize: 18
        }

        ColumnLayout {
            spacing: 2
            Layout.fillWidth: true

            Text {
                text: root.label
                color: Config.styling.text0
                font.pixelSize: 14
                font.bold: true
            }

            Text {
                visible: text !== ""
                text: root.subtitle
                color: Config.styling.text2
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }

        Item {
            Layout.preferredWidth: root.switchSlotWidth
            Layout.minimumWidth: root.switchSlotWidth
            Layout.maximumWidth: root.switchSlotWidth
            Layout.preferredHeight: 28
            Layout.alignment: Qt.AlignVCenter

            DashboardToggleSwitch {
                checked: root.checked
                enabled: root.enabled
                anchors {
                    right: parent.right
                    rightMargin: 2
                    verticalCenter: parent.verticalCenter
                }
                onToggled: root.toggled(checked)
            }
        }
    }
}
