import QtQuick
import QtQuick.Layouts
import qs.services

ColumnLayout {
    id: root

    spacing: Config.spacing.xs

    component SessionAction: ConfirmActionButton {
        id: control

        required property string operation
        required property color optionColor
        property string confirmLabel: qsTr("Confirm")
        property string iconName: "dialog-warning"

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 40
        accentColor: optionColor
        enabled: !SessionController.busy

        onConfirmed: SessionController.execute(control.operation)

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
                text: {
                    if (control.confirming)
                        return control.confirmLabel;
                    if (SessionController.busy && SessionController.pendingOperation === control.operation)
                        return qsTr("Working…");
                    return control.text;
                }
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
            operation: "shutdown"
            optionColor: Config.colors.red
            iconName: "system-shutdown-symbolic"
            text: qsTr("Shutdown")
        }

        SessionAction {
            Layout.fillWidth: true
            operation: "reboot"
            optionColor: Config.colors.peach
            iconName: "system-reboot-symbolic"
            text: qsTr("Reboot")
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Config.spacing.xs

        SessionAction {
            Layout.fillWidth: true
            operation: "hibernate"
            optionColor: Config.colors.sapphire
            iconName: "system-suspend-hibernate-symbolic"
            text: qsTr("Hibernate")
        }

        SessionAction {
            Layout.fillWidth: true
            operation: "logout"
            optionColor: Config.colors.yellow
            iconName: "system-log-out-symbolic"
            text: qsTr("Logout")
        }
    }

    Text {
        Layout.fillWidth: true
        visible: SessionController.lastError !== ""
        text: SessionController.lastError
        color: Config.styling.critical
        font.pixelSize: 12
        wrapMode: Text.Wrap
    }
}
