pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.services
import qs.components

DashboardPage {
    id: root

    title: qsTr("Power & Display")
    scrollable: true

    DashboardSection {
        id: batterySection
        Layout.fillWidth: true
        title: qsTr("Battery and power")
        visible: PowerService.hasBattery
        showDetailToggle: true

        Battery {
            Layout.fillWidth: true
            graphActive: root.visible
            powerModesFirst: true
            showGraph: batterySection.detailed
        }
    }

    DashboardSection {
        Layout.fillWidth: true
        title: qsTr("Display")
        visible: Brightness.available

        LabeledSlider {
            Layout.fillWidth: true
            label: qsTr("Brightness")
            iconName: Brightness.iconName
            value: Brightness.percent
            from: 0
            to: 100
            valueText: Brightness.available
                ? `${Brightness.percent}%`
                : qsTr("Unavailable")
            enabled: Brightness.available
            onValueCommitted: value => Brightness.setPercent(value)
        }
    }
}
