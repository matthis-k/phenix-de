import QtQuick
import QtQuick.Layouts
import QtQml

DashboardSection {
    id: root

    required property DashboardObservation observation
    property Component overviewDelegate: null
    property Component promotedDelegate: null
    property Component detailedDelegate: null
    property bool domainVisible: true

    showDetailToggle: root.detailedDelegate !== null

    readonly property Component activeDelegate: {
        if (root.detailed)
            return root.detailedDelegate || root.promotedDelegate || root.overviewDelegate;

        switch (root.observation.exposure) {
        case DashboardObservation.Promoted:
            return root.promotedDelegate || root.overviewDelegate;
        case DashboardObservation.Summary:
            return root.overviewDelegate;
        case DashboardObservation.Detailed:
            return root.detailedDelegate || root.promotedDelegate || root.overviewDelegate;
        case DashboardObservation.Hidden:
        default:
            return null;
        }
    }

    visible: root.domainVisible && root.observation.shown

    Binding {
        target: root.observation
        property: "presentationMode"
        value: root.presentationMode
        restoreMode: Binding.RestoreBinding
    }

    Loader {
        active: root.activeDelegate !== null
        sourceComponent: root.activeDelegate
        visible: active
        Layout.fillWidth: true
        Layout.preferredHeight: active && item ? item.implicitHeight : 0
    }
}
