pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.services
import qs.components

DashboardPage {
    id: root

    title: "Battery"
    scrollable: true
    visible: PowerService.hasBattery

    DashboardSection {
        Layout.fillWidth: true
        title: "Battery and power"
        visible: PowerService.hasBattery

        Battery {
            id: batteryContent
            Layout.fillWidth: true
            graphActive: root.visible
            powerModesFirst: true
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