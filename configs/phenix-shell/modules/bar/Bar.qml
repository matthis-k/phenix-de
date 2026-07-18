import QtQuick
import QtQuick.Layouts
import qs.animations as Animations
import qs.services
import qs.components
import qs.modules.quickmenu

Rectangle {
    id: root
    property var screenState
    anchors.fill: parent
    color: Config.styling.bg0

    readonly property bool rightExpanded: !!screenState && screenState.barExpandedForDashboard
    readonly property int transitionMs: screenState
        ? screenState.dashboardTransitionMs
        : 0

    RowLayout {
        id: left
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
        }
        HyprlandWidget {}
    }

    RowLayout {
        id: center
        anchors {
            top: parent.top
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
        }
        Clock { format: "HH:mm" }
    }

    RowLayout {
        id: right
        anchors {
            top: parent.top
            bottom: parent.bottom
            right: parent.right
        }
        width: root.rightExpanded ? root.screenState.dashboardWidth : implicitWidth
        spacing: root.rightExpanded ? Config.spacing.xxs : 0
        clip: true

        Animations.PanelBehavior on width {
            duration: root.transitionMs
        }
        Animations.PanelBehavior on spacing {
            duration: root.transitionMs
        }

        NetworkIcon      { screenState: root.screenState; Layout.fillWidth: root.rightExpanded }
        AudioIcon        { screenState: root.screenState; Layout.fillWidth: root.rightExpanded }
        NotificationIcon { screenState: root.screenState; Layout.fillWidth: root.rightExpanded }
        EnergyIcon       { screenState: root.screenState; Layout.fillWidth: root.rightExpanded }
        StatsIcon        { screenState: root.screenState; Layout.fillWidth: root.rightExpanded }
        OverviewIcon     { screenState: root.screenState; Layout.fillWidth: root.rightExpanded }
    }
}
