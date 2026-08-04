import QtQuick
import QtQuick.Layouts
import qs.services

Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property string iconName: ""
    property color iconColor: Config.styling.text1
    property color titleColor: Config.styling.text0
    property color subtitleColor: Config.styling.text2
    property bool titleBold: true
    property bool subtitleBold: false
    property Component accessory: null

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: Config.spacing.xs

        DashboardHeader {
            Layout.fillWidth: true
            level: 2
            title: root.title
            subtitle: root.subtitle
            iconName: root.iconName
            iconColor: root.iconColor
            titleColor: root.titleColor
            subtitleColor: root.subtitleColor
            titleBold: root.titleBold
            subtitleBold: root.subtitleBold
        }

        Loader {
            id: accessoryLoader
            active: root.accessory !== null
            sourceComponent: root.accessory
            Layout.preferredWidth: item ? item.implicitWidth : 0
            Layout.preferredHeight: item ? item.implicitHeight : 0
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
