import QtQuick.Layouts
import qs.services

ColumnLayout {
    id: root

    property int contentSpacing: Config.spacing.xs

    spacing: root.contentSpacing
}
