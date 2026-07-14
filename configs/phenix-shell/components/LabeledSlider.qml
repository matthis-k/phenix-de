import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml
import qs.services

Item {
    id: root

    property string label: ""
    property string valueText: ""
    property string iconName: ""
    property color iconColor: Config.styling.text0
    property real from: 0
    property real to: 100
    property real value: 0
    property real stepSize: 1
    property bool enabled: true

    signal valueModified(real value)
    signal valueCommitted(real value)

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout
        anchors.fill: parent
        spacing: Config.spacing.xxs

        RowLayout {
            Layout.fillWidth: true
            spacing: Config.spacing.xs

            Icon {
                visible: root.iconName !== ""
                iconName: root.iconName
                color: root.iconColor
                implicitSize: 16
            }

            Text {
                text: root.label
                color: Config.styling.text1
                font.pixelSize: 13
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: root.valueText
                color: Config.styling.text0
                font.pixelSize: 13
                font.bold: true
            }
        }

        StyledSlider {
            id: slider
            Layout.fillWidth: true
            enabled: root.enabled
            from: root.from
            to: root.to
            stepSize: root.stepSize

            Binding {
                target: slider
                property: "value"
                value: root.value
                when: !slider.pressed
            }

            onMoved: root.valueModified(value)
            onPressedChanged: {
                if (!pressed)
                    root.valueCommitted(value);
            }
        }
    }
}
