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
    property int trailingControlInset: Config.spacing.xs
    property bool navigationEnabled: false
    property string navigationLabel: qsTr("Open %1 details").arg(root.label)

    signal toggled(bool checked)
    signal navigationRequested

    implicitWidth: row.implicitWidth
    implicitHeight: Math.max(44, row.implicitHeight + Config.spacing.xs * 2)
    activeFocusOnTab: enabled

    Accessible.role: Accessible.CheckBox
    Accessible.name: root.label
    Accessible.description: root.subtitle
    Accessible.checked: root.checked

    function requestToggle() {
        if (!root.enabled)
            return;
        root.checked = !root.checked;
        root.toggled(root.checked);
    }

    Keys.onSpacePressed: root.requestToggle()
    Keys.onReturnPressed: root.requestToggle()
    Keys.onEnterPressed: root.requestToggle()

    Rectangle {
        anchors.fill: parent
        color: rowMouse.containsMouse && root.enabled ? Config.styling.bg4 : Config.styling.bg3
        border.color: root.activeFocus ? Config.styling.primaryAccent : "transparent"
        border.width: root.activeFocus ? 1 : 0
        radius: Config.styling.radius

        Animations.StateColorBehavior on color {
        }

        Animations.StateColorBehavior on border.color {
        }
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        anchors.rightMargin: root.navigationEnabled ? 36 : 0
        z: 2
        enabled: root.enabled
        hoverEnabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.forceActiveFocus();
            root.requestToggle();
        }
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: Config.spacing.xs
        anchors.rightMargin: root.trailingControlInset
        anchors.topMargin: Config.spacing.xs
        anchors.bottomMargin: Config.spacing.xs
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
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                onToggled: root.toggled(checked)
            }
        }

        DashboardIconButton {
            visible: root.navigationEnabled
            z: 3
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            Layout.alignment: Qt.AlignVCenter
            iconName: "go-next-symbolic"
            fallbackIconName: "go-next-symbolic"
            iconColor: hovered ? Config.styling.secondaryAccent : Config.styling.text1
            backgroundColor: hovered ? Config.styling.bg4 : "transparent"
            active: hovered
            fillOnHover: true
            indicatorOnHover: false
            accessibleName: root.navigationLabel
            onClicked: root.navigationRequested()
        }
    }
}
