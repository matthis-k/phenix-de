import QtQuick
import QtQuick.Layouts
import QtQml
import qs.services

Item {
    id: root

    property string iconName: "audio-volume-high-symbolic"
    property color iconColor: Config.styling.text0
    property bool showIcon: true
    property string valueText: ""
    property real from: 0
    property real to: 100
    property real value: 0
    property real stepSize: 1
    property bool enabled: true
    property color accentColor: Config.colors.blue
    property real iconSize: 20
    property real valueTextWidth: 42

    signal iconClicked
    signal valueModified(real value)

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: Config.spacing.sm

        Icon {
            visible: root.showIcon
            Layout.preferredWidth: root.iconSize
            Layout.minimumWidth: root.iconSize
            Layout.maximumWidth: root.iconSize
            Layout.preferredHeight: root.iconSize
            iconName: root.iconName
            color: root.iconColor
            implicitSize: root.iconSize

            ActionButton {
                anchors.fill: parent
                visible: root.showIcon
                enabled: root.enabled
                highlightThickness: 0
                onClicked: root.iconClicked()
            }
        }

        StyledSlider {
            id: slider
            Layout.fillWidth: true
            enabled: root.enabled
            from: root.from
            to: root.to
            stepSize: root.stepSize
            accentColor: root.accentColor

            Binding {
                target: slider
                property: "value"
                value: root.value
                when: !slider.pressed
            }

            onMoved: root.valueModified(value)
        }

        Text {
            Layout.preferredWidth: root.valueTextWidth
            Layout.minimumWidth: root.valueTextWidth
            Layout.maximumWidth: root.valueTextWidth
            horizontalAlignment: Text.AlignRight
            text: root.valueText
            color: Config.styling.text2
            font.pixelSize: 11
            font.bold: true
        }
    }
}
