import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import qs.components
import qs.services

Item {
    id: root

    property string query: ""
    property bool loading: false
    property bool settled: false
    property int resultCount: 0

    readonly property bool hasQuery: query.trim().length > 0
    readonly property bool showLoading: hasQuery && loading
    readonly property bool showEmpty: hasQuery && settled && !loading && resultCount === 0

    visible: showLoading || showEmpty
    implicitWidth: content.implicitWidth
    implicitHeight: visible ? content.implicitHeight + Config.spacing.sm * 2 : 0

    Accessible.role: Accessible.StaticText
    Accessible.name: showLoading ? qsTr("Searching") : qsTr("No results")

    ColumnLayout {
        id: content

        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        spacing: Config.spacing.xs

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: root.showLoading
            spacing: Config.spacing.xs

            BusyIndicator {
                running: root.showLoading
                implicitWidth: 22
                implicitHeight: 22
            }

            Text {
                text: qsTr("Searching…")
                color: Config.styling.text1
                font.pixelSize: 13
            }
        }

        EmptyState {
            Layout.fillWidth: true
            visible: root.showEmpty
            iconName: "system-search-symbolic"
            title: qsTr("No results")
            description: qsTr("Try a shorter query, or type ? to choose a search source.")
        }
    }
}
