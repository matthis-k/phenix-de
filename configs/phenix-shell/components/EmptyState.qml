import QtQuick
import QtQuick.Layouts
import qs.services

Item {
    id: root

    property string iconName: "dialog-information-symbolic"
    property string title: "Nothing here"
    property string description: ""

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
        }
        spacing: Config.spacing.xs

        Icon {
            Layout.alignment: Qt.AlignHCenter
            iconName: root.iconName
            color: Config.styling.text2
            implicitSize: 28
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.title
            color: Config.styling.text0
            font.pixelSize: 16
            font.bold: true
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: text !== ""
            text: root.description
            color: Config.styling.text2
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }
}
