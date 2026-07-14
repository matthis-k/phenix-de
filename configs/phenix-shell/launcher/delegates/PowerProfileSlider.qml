import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.animations as Animations
import qs.components
import qs.services

ColumnLayout {
    id: root
    spacing: Config.spacing.xxs
    implicitHeight: labelSlot.implicitHeight + sliderRow.implicitHeight + Config.spacing.xxs

    property real value: 1
    signal valueModified(real value)

    function modeIndex() { return Math.round(root.value); }

    function modeLabel() {
        switch (modeIndex()) {
        case 0: return qsTr("Power Saver");
        case 2: return qsTr("Performance");
        default: return qsTr("Balanced");
        }
    }

    function modeColor() {
        switch (modeIndex()) {
        case 0: return Config.styling.good;
        case 2: return Config.styling.critical;
        default: return Config.colors.yellow;
        }
    }

    function modeIcon() {
        switch (modeIndex()) {
        case 0: return "power-profile-power-saver-symbolic";
        case 2: return "power-profile-performance-symbolic";
        default: return "power-profile-balanced-symbolic";
        }
    }

    Item {
        id: labelSlot
        Layout.fillWidth: true
        Layout.preferredHeight: modeLabelText.implicitHeight
        clip: true

        function labelX() {
            var idx = modeIndex();
            if (idx === 0) return 0;
            if (idx === 2) return Math.max(0, width - modeLabelText.implicitWidth);
            return Math.round((width - modeLabelText.implicitWidth) / 2);
        }

        Text {
            id: modeLabelText
            x: labelSlot.labelX()
            text: root.modeLabel()
            color: root.modeColor()
            font.pixelSize: 12
            font.bold: true

            Animations.ShiftBehavior on x {}
            Animations.StateColorBehavior on color {}
        }
    }

    RowLayout {
        id: sliderRow
        spacing: Config.spacing.xs
        Layout.fillWidth: true

        Icon {
            iconName: "power-profile-power-saver-symbolic"
            color: Config.styling.good
            implicitSize: 18
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            Layout.alignment: Qt.AlignVCenter
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: modeSlider.implicitHeight
            Layout.alignment: Qt.AlignVCenter

            StyledSlider {
                id: modeSlider
                anchors.fill: parent
                from: 0
                to: 2
                stepSize: 1
                snapMode: Slider.SnapAlways
                accentColor: root.modeColor()

                Binding {
                    target: modeSlider
                    property: "value"
                    value: root.value
                    when: !modeSlider.pressed
                }

                onMoved: root.valueModified(value)
                onPressedChanged: {
                    if (!pressed)
                        root.valueModified(value);
                }
            }

            Rectangle {
                width: 2
                height: 6
                radius: width / 2
                color: Config.styling.bg8
                x: Math.round(parent.width / 2 - width / 2)
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Icon {
            iconName: "power-profile-performance-symbolic"
            color: Config.styling.critical
            implicitSize: 18
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
