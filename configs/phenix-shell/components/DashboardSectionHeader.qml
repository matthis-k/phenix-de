import QtQuick
import QtQuick.Layouts
import qs.services

Item {
    id: root

    property string title: ""
    property string subtitle: ""
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
