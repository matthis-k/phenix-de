import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services

ColumnLayout {
    id: root

    spacing: Config.spacing.xs

    component SessionAction: ConfirmActionButton {
        id: control

        required property list<string> command
        required property color optionColor
        property string confirmLabel: "Confirm"
        property string iconName: "dialog-warning"

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 40
        accentColor: optionColor

        Process {
            id: runner
        }

        onConfirmed: runner.exec({
                command: control.command
            })

        contentItem: RowLayout {
            anchors.fill: parent
            anchors.margins: Config.spacing.xs
            spacing: Config.spacing.sm

            Icon {
                Layout.alignment: Qt.AlignVCenter
                iconName: control.iconName
                color: control.confirming ? control.optionColor : Config.styling.text0
                implicitSize: 18
            }

            Text {
                Layout.fillWidth: true
                text: control.confirming ? control.confirmLabel : control.text
                color: control.confirming ? control.optionColor : Config.styling.text0
                font.pixelSize: 14
                font.bold: true
                horizontalAlignment: Text.AlignLeft
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Config.spacing.xs

        SessionAction {
            Layout.fillWidth: true
            command: ["systemctl", "poweroff"]
            optionColor: Config.colors.red
            iconName: "system-shutdown-symbolic"
            text: "Shutdown"
        }

        SessionAction {
            Layout.fillWidth: true
            command: ["systemctl", "reboot"]
            optionColor: Config.colors.peach
            iconName: "system-reboot-symbolic"
            text: "Reboot"
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Config.spacing.xs

        SessionAction {
            Layout.fillWidth: true
            command: ["systemctl", "hibernate"]
            optionColor: Config.colors.sapphire
            iconName: "system-suspend-hibernate-symbolic"
            text: "Hibernate"
        }

        SessionAction {
            Layout.fillWidth: true
            command: ["uwsm", "stop"]
            optionColor: Config.colors.yellow
            iconName: "system-log-out-symbolic"
            text: "Logout"
        }
    }
}
