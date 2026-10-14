import QtQuick
import QtQuick.Controls as Controls
import qs.services

// Extend the real Qt TextField: preserve selection, IME, focus, completion,
// validation and native shortcuts instead of embedding a second editor.
Controls.TextField {
    id: root

    property string searchIconName: "material:search"
    property string clearIconName: "material:close"
    property bool showClearButton: true
    property int accessoryWidth: 28
    readonly property bool clearVisible: showClearButton && text.length > 0

    implicitWidth: 220
    leftPadding: accessoryWidth + Config.spacing.xs
    rightPadding: (clearVisible ? accessoryWidth : 0) + Config.spacing.xs
    placeholderText: qsTr("Search")

    Icon {
        anchors.left: parent.left
        anchors.leftMargin: Config.spacing.xs
        anchors.verticalCenter: parent.verticalCenter
        iconName: root.searchIconName
        implicitSize: Config.iconSizes.inline
        color: root.enabled ? Config.styling.text1 : Config.styling.bg7
        enabled: false
    }

    ActionButton {
        visible: root.clearVisible
        enabled: root.enabled && root.clearVisible
        anchors.right: parent.right
        anchors.rightMargin: Config.spacing.xxs
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: root.accessoryWidth - Config.spacing.xxs
        implicitHeight: implicitWidth
        indicatorOnHover: false
        backgroundColor: "transparent"
        accessibleName: qsTr("Clear search")
        onClicked: {
            root.clear();
            root.forceActiveFocus();
        }

        contentItem: Icon {
            iconName: root.clearIconName
            color: Config.styling.text1
            implicitSize: Config.iconSizes.inline
        }
    }
}
