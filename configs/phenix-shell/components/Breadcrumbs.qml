import QtQuick
import QtQuick.Layouts
import qs.services

// A path is an array of labels or { label, iconName, value } objects.
// The last segment is the current location and is not clickable.
RowLayout {
    id: root

    property var items: []
    property int segmentSpacing: Config.spacing.xxs
    property int maximumLabelWidth: 180
    signal activated(int index, var item)

    spacing: segmentSpacing
    Accessible.name: qsTr("Breadcrumbs")

    Repeater {
        model: root.items

        delegate: RowLayout {
            id: crumb
            required property int index
            required property var modelData

            readonly property string label: typeof modelData === "string"
                ? modelData : String((modelData && modelData.label) || "")
            readonly property string iconName: typeof modelData === "string"
                ? "" : String((modelData && modelData.iconName) || "")
            readonly property bool current: index === root.items.length - 1

            spacing: root.segmentSpacing

            ActionButton {
                id: segment
                enabled: !crumb.current
                text: crumb.label
                accessibleName: crumb.current
                    ? qsTr("Current location: %1").arg(crumb.label)
                    : qsTr("Navigate to %1").arg(crumb.label)
                fillOnHover: !crumb.current
                indicatorOnHover: false
                implicitHeight: 30
                implicitWidth: Math.min(root.maximumLabelWidth, content.implicitWidth + Config.spacing.xs * 2)
                onClicked: root.activated(crumb.index, crumb.modelData)

                contentItem: RowLayout {
                    id: content
                    spacing: Config.spacing.xxs

                    Icon {
                        visible: crumb.iconName !== ""
                        iconName: crumb.iconName
                        color: crumb.current ? Config.styling.text0 : Config.styling.text1
                        implicitSize: Config.iconSizes.inline
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        Layout.fillWidth: true
                        text: crumb.label
                        elide: Text.ElideMiddle
                        color: crumb.current ? Config.styling.text0 : Config.styling.text1
                        font.pixelSize: Config.typography.label
                        font.family: Config.typography.mono
                        font.bold: crumb.current
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Text {
                visible: !crumb.current
                text: "/"
                color: Config.styling.text1
                font.pixelSize: Config.typography.label
                Accessible.ignored: true
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
