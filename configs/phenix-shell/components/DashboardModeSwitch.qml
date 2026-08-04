import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

import qs.animations as Animations
import qs.services

Control {
    id: root

    property string mode: "overview"
    signal modeRequested(string mode)

    implicitWidth: modeRow.implicitWidth + Config.spacing.xs * 2
    implicitHeight: 30
    padding: 2
    focusPolicy: Qt.StrongFocus

    Accessible.role: Accessible.Grouping
    Accessible.name: qsTr("Dashboard information level")
    Accessible.description: qsTr("Choose overview or detailed system information")

    function requestMode(nextMode) {
        const normalized = String(nextMode || "").toLowerCase() === "detailed"
            ? "detailed"
            : "overview";
        if (root.mode === normalized)
            return;
        root.modeRequested(normalized);
    }

    background: Rectangle {
        color: Config.styling.bg2
        border.color: root.activeFocus ? Config.styling.primaryAccent : Config.styling.bg3
        border.width: 1
        radius: Config.styling.radius

        Animations.StateColorBehavior on border.color {}
    }

    contentItem: RowLayout {
        id: modeRow
        spacing: 2

        ButtonGroup {
            id: modeGroup
            exclusive: true
        }

        ToolButton {
            id: overviewButton
            text: qsTr("Overview")
            checkable: true
            checked: root.mode !== "detailed"
            ButtonGroup.group: modeGroup
            focusPolicy: Qt.StrongFocus
            activeFocusOnTab: true
            Accessible.name: qsTr("Overview mode")
            Accessible.description: qsTr("Show distilled information and promote important outliers")
            onClicked: root.requestMode("overview")
            Keys.onRightPressed: {
                detailedButton.forceActiveFocus();
                root.requestMode("detailed");
            }

            contentItem: Text {
                text: overviewButton.text
                color: overviewButton.checked ? Config.styling.bg0 : Config.styling.text1
                font.pixelSize: 11
                font.bold: overviewButton.checked
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                color: overviewButton.checked
                    ? Config.styling.primaryAccent
                    : (overviewButton.hovered ? Config.styling.bg4 : "transparent")
                radius: Math.max(2, Config.styling.radius - 2)
                border.color: overviewButton.activeFocus ? Config.styling.text0 : "transparent"
                border.width: overviewButton.activeFocus ? 1 : 0

                Animations.StateColorBehavior on color {}
            }

            ToolTip.visible: hovered || activeFocus
            ToolTip.text: qsTr("Overview (g o)")
            ToolTip.delay: 450
        }

        ToolButton {
            id: detailedButton
            text: qsTr("Detailed")
            checkable: true
            checked: root.mode === "detailed"
            ButtonGroup.group: modeGroup
            focusPolicy: Qt.StrongFocus
            activeFocusOnTab: true
            Accessible.name: qsTr("Detailed mode")
            Accessible.description: qsTr("Show all available system and device data")
            onClicked: root.requestMode("detailed")
            Keys.onLeftPressed: {
                overviewButton.forceActiveFocus();
                root.requestMode("overview");
            }

            contentItem: Text {
                text: detailedButton.text
                color: detailedButton.checked ? Config.styling.bg0 : Config.styling.text1
                font.pixelSize: 11
                font.bold: detailedButton.checked
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                color: detailedButton.checked
                    ? Config.styling.primaryAccent
                    : (detailedButton.hovered ? Config.styling.bg4 : "transparent")
                radius: Math.max(2, Config.styling.radius - 2)
                border.color: detailedButton.activeFocus ? Config.styling.text0 : "transparent"
                border.width: detailedButton.activeFocus ? 1 : 0

                Animations.StateColorBehavior on color {}
            }

            ToolTip.visible: hovered || activeFocus
            ToolTip.text: qsTr("Detailed (g d)")
            ToolTip.delay: 450
        }
    }
}
