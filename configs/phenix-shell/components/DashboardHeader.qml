import QtQuick
import QtQuick.Layouts

import qs.services

ColumnLayout {
    id: root

    property int level: 1
    property string title: ""
    property string subtitle: ""

    readonly property int titlePixelSize: level === 1 ? 22 : 16
    readonly property int subtitlePixelSize: level === 1 ? 13 : 12
    readonly property int headerSpacing: level === 1 ? Config.spacing.xs : 2

    spacing: root.headerSpacing

    Text {
        visible: text !== ""
        text: root.title
        color: Config.styling.text0
        font.pixelSize: root.titlePixelSize
        font.bold: true
        elide: Text.ElideRight
        Layout.fillWidth: true
    }

    Text {
        visible: text !== ""
        text: root.subtitle
        color: Config.styling.text2
        font.pixelSize: root.subtitlePixelSize
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
}
