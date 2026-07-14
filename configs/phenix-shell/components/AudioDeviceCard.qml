import QtQuick
import QtQuick.Layouts
import qs.animations as Animations
import qs.services

Rectangle {
    id: root

    property string title: ""
    property string iconName: "audio-volume-high-symbolic"
    property color iconColor: Config.styling.text0
    property string valueText: ""
    property real from: 0
    property real to: 100
    property real value: 0
    property real stepSize: 1
    property bool sliderEnabled: true
    property color accentColor: Config.colors.blue
    property bool showDefaultBadge: false
    property string defaultBadgeText: "Default"
    property bool iconEnabled: true

    signal iconClicked
    signal valueModified(real value)

    Layout.fillWidth: true
    color: Config.styling.bg3
    radius: Config.styling.radius
    implicitHeight: content.implicitHeight + Config.spacing.xs * 2

    Animations.StateColorBehavior on color {
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Config.spacing.xs
        spacing: Config.spacing.xs

        RowLayout {
            Layout.fillWidth: true
            spacing: Config.spacing.xs

            ActionButton {
                Layout.preferredWidth: 18
                Layout.minimumWidth: 18
                Layout.maximumWidth: 18
                Layout.preferredHeight: 18
                Layout.alignment: Qt.AlignTop
                implicitWidth: 18
                implicitHeight: 18
                enabled: root.iconEnabled
                highlightThickness: 0
                onClicked: root.iconClicked()

                contentItem: Icon {
                    iconName: root.iconName
                    color: root.iconColor
                    implicitSize: 18

                    Animations.StateColorBehavior on color {
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Config.styling.text0
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                visible: root.showDefaultBadge
                text: root.defaultBadgeText
                color: Config.colors.blue
                font.pixelSize: 12
                font.bold: true

                Animations.RevealBehavior on opacity {
                }
            }
        }

        AudioLevelSlider {
            Layout.fillWidth: true
            showIcon: false
            valueText: root.valueText
            from: root.from
            to: root.to
            value: root.value
            stepSize: root.stepSize
            enabled: root.sliderEnabled
            accentColor: root.accentColor
            onValueModified: (value) => root.valueModified(value)
        }
    }
}
