import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

// Generic app-page structure: optional breadcrumbs, header actions, toolbar,
// layout-managed body, footer. Insert native Qt controls into the body.
Item {
    id: root

    property string title: ""
    property string description: ""
    property Component breadcrumbs: null
    property Component headerActions: null
    property Component toolbar: null
    property Component footer: null
    property int pagePadding: 16
    property int sectionSpacing: 12
    default property alias content: body.data

    implicitWidth: 540
    implicitHeight: column.implicitHeight + pagePadding * 2

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: root.pagePadding
        spacing: root.sectionSpacing

        Loader {
            Layout.fillWidth: true
            active: root.breadcrumbs !== null
            sourceComponent: root.breadcrumbs
            Layout.preferredHeight: item ? item.implicitHeight : 0
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.title !== "" || root.description !== "" || root.headerActions !== null
            spacing: root.sectionSpacing

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Controls.Label {
                    visible: text !== ""
                    Layout.fillWidth: true
                    text: root.title
                    font.pixelSize: 22
                    font.bold: true
                    elide: Text.ElideRight
                }

                Controls.Label {
                    visible: text !== ""
                    Layout.fillWidth: true
                    text: root.description
                    wrapMode: Text.WordWrap
                    opacity: 0.7
                }
            }

            Loader {
                active: root.headerActions !== null
                sourceComponent: root.headerActions
                Layout.preferredWidth: item ? item.implicitWidth : 0
                Layout.preferredHeight: item ? item.implicitHeight : 0
                Layout.alignment: Qt.AlignTop
            }
        }

        Loader {
            Layout.fillWidth: true
            active: root.toolbar !== null
            sourceComponent: root.toolbar
            Layout.preferredHeight: item ? item.implicitHeight : 0
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.sectionSpacing
        }

        Loader {
            Layout.fillWidth: true
            active: root.footer !== null
            sourceComponent: root.footer
            Layout.preferredHeight: item ? item.implicitHeight : 0
        }
    }
}
