pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.services
import qs.components

DashboardPage {
    id: root

    title: "Battery"
    subtitle: root.detailed
        ? qsTr("Charge history, power profile, and display controls")
        : qsTr("Current charge, power profile, and brightness")
    scrollable: true
    visible: PowerService.hasBattery

    DashboardSection {
        id: batterySection
        Layout.fillWidth: true
        title: "Battery and power"
        visible: PowerService.hasBattery
        showDetailToggle: true

        Battery {
            id: batteryContent
            Layout.fillWidth: true
            graphActive: root.visible
            powerModesFirst: true
            showGraph: batterySection.detailed
        }
    }

    DashboardSection {
        Layout.fillWidth: true
        title: "Display"
        visible: Brightness.available

        LabeledSlider {
            Layout.fillWidth: true
            label: "Brightness"
            iconName: Brightness.iconName
            value: Brightness.percent
            from: 0
            to: 100
            valueText: Brightness.available ? `${Brightness.percent}%` : "Unavailable"
            enabled: Brightness.available
            onValueCommitted: Brightness.setPercent(value)
        }
    }
}
