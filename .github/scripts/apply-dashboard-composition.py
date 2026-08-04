#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(rel):
    return (ROOT / rel).read_text()


def write(rel, content):
    target = ROOT / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content.rstrip() + "\n")


def replace_once(rel, old, new):
    content = read(rel)
    count = content.count(old)
    if count != 1:
        raise RuntimeError(f"{rel}: expected one match, found {count}: {old[:80]!r}")
    write(rel, content.replace(old, new, 1))


# Canonical state timing for every InteractiveButton consumer.
replace_once(
    "configs/phenix-shell/components/InteractiveButton.qml",
    "    property int scaleAnimationDuration: 150\n",
    "    property int scaleAnimationDuration: Config.motion.micro\n",
)

# Graph callbacks and timers cannot outlive the view that owns them.
replace_once(
    "configs/phenix-shell/components/GraphView.qml",
    "    property bool _visibilityChangedInBatch: false\n",
    "    property bool _visibilityChangedInBatch: false\n    property bool _destroying: false\n",
)
replace_once(
    "configs/phenix-shell/components/GraphView.qml",
    """    function _handleGraphChanged() {
        root.requestRender(\"\", \"graph\");
    }
""",
    """    function _handleGraphChanged() {
        if (!root || root._destroying)
            return;
        root.requestRender(\"\", \"graph\");
    }
""",
)
replace_once(
    "configs/phenix-shell/components/GraphView.qml",
    """    function requestRender(graphName, reason) {
        const key = graphName || \"view\";
""",
    """    function requestRender(graphName, reason) {
        if (root._destroying)
            return;
        const key = graphName || \"view\";
""",
)
replace_once(
    "configs/phenix-shell/components/GraphView.qml",
    """    onShowLabelsChanged: root.requestRender(\"\", \"labels\")

    Canvas {
""",
    """    onShowLabelsChanged: root.requestRender(\"\", \"labels\")

    Component.onDestruction: {
        root._destroying = true;
        root._disconnectGraphs();
        renderScheduler.stop();
        visibilityNotifier.stop();
        root._renderQueued = false;
        root._renderPending = false;
        root._dirtyReasons = ({});
    }

    Canvas {
""",
)

# The all-details toggle is dashboard chrome, not a page-local accessory.
replace_once(
    "configs/phenix-shell/components/DashboardPage.qml",
    "    property bool showModeSwitch: true\n",
    "    property bool showModeSwitch: false\n",
)
replace_once(
    "configs/phenix-shell/modules/quickmenu/Window.qml",
    "import QtQuick.Controls\n",
    "import QtQuick.Controls\nimport QtQuick.Layouts\n",
)
replace_once(
    "configs/phenix-shell/modules/quickmenu/Window.qml",
    """            SwipeView {
                id: selection
                anchors.fill: parent
""",
    """            Rectangle {
                id: globalToolbar
                z: 2
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: 36
                color: Config.styling.bg1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Config.spacing.md
                    anchors.rightMargin: Config.spacing.md
                    spacing: Config.spacing.xs

                    Item { Layout.fillWidth: true }

                    Text {
                        text: qsTr(\"Details\")
                        color: Config.styling.text2
                        font.pixelSize: 12
                        font.bold: true
                    }

                    DashboardModeSwitch {
                        mode: root.presentationMode
                        onModeRequested: mode => root.setPresentationMode(mode)
                    }
                }

                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }
                    height: 1
                    color: Config.styling.bg3
                }
            }

            SwipeView {
                id: selection
                anchors {
                    fill: parent
                    topMargin: globalToolbar.height
                }
""",
)

# Lists of independently expandable objects do not also get a list-level arrow.
replace_once(
    "configs/phenix-shell/modules/quickmenu/network/WifiSection.qml",
    "        showDetailToggle: connectedNetworks.length > 0\n",
    "",
)
replace_once(
    "configs/phenix-shell/modules/quickmenu/network/WifiSection.qml",
    "        showDetailToggle: disconnectedNetworks.length > 0\n",
    "",
)
replace_once(
    "configs/phenix-shell/modules/quickmenu/bluetooth/BluetoothDeviceSection.qml",
    "    showDetailToggle: root.devices.length > 0\n",
    "",
)

# Row arrow owns metadata; row activation owns temporary connection controls.
network_row = "configs/phenix-shell/modules/quickmenu/network/NetworkRow.qml"
replace_once(
    network_row,
    "    readonly property bool showAdvanced: rowRoot.interactionExpanded && rowRoot.interactionState ? !!rowRoot.interactionState.interactiveShowAdvanced : false\n",
    "",
)
replace_once(
    network_row,
    """                        SmallButton {
                            visible: !rowRoot.detailed
                            text: rowRoot.showAdvanced ? \"Hide Advanced\" : \"Show Advanced\"
                            onClicked: {
                                if (rowRoot.interactionState)
                                    rowRoot.interactionState.interactiveShowAdvanced = !rowRoot.interactionState.interactiveShowAdvanced;
                            }
                        }
""",
    "",
)
replace_once(
    network_row,
    """                    Text {
                        Layout.fillWidth: true
                        visible: rowRoot.showAdvanced && !rowRoot.detailed
                        text: NetworkService.advancedNetworkInfo(rowRoot.network)
                        color: Config.styling.text2
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }
""",
    "",
)

bluetooth_row = "configs/phenix-shell/modules/quickmenu/bluetooth/BluetoothDeviceRow.qml"
replace_once(
    bluetooth_row,
    "    readonly property bool showAdvanced: root.interactionExpanded && root.interactionState ? !!root.interactionState.interactiveShowAdvanced : false\n",
    "",
)
replace_once(
    bluetooth_row,
    """                        SmallButton {
                            visible: !root.detailed
                            text: root.showAdvanced ? \"Hide Advanced\" : \"Show Advanced\"
                            onClicked: {
                                if (root.interactionState)
                                    root.interactionState.interactiveShowAdvanced = !root.interactionState.interactiveShowAdvanced;
                            }
                        }
""",
    "",
)
replace_once(
    bluetooth_row,
    """                    Text {
                        Layout.fillWidth: true
                        visible: root.showAdvanced && !root.detailed
                        text: BluetoothService.advancedDeviceInfo(root.device)
                        color: Config.styling.text2
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }
""",
    "",
)
replace_once(
    bluetooth_row,
    """                        SmallButton {
                            visible: root.detailed && root.hasDevice && (root.device.paired || root.device.bonded)
                            text: \"Forget\"
                            onClicked: {
                                if (!root.hasDevice) {
                                    if (root.interactionState)
                                        root.interactionState.unlockInteraction();
                                    return;
                                }

                                BluetoothService.forgetDevice(root.device);
                                if (root.interactionState)
                                    root.interactionState.unlockInteraction();
                            }
                        }
""",
    """                        ConfirmSmallButton {
                            visible: root.detailed
                                && root.hasDevice
                                && (root.device.paired || root.device.bonded)
                            text: qsTr(\"Forget\")
                            confirmText: qsTr(\"Confirm forget\")
                            onConfirmed: {
                                if (!root.hasDevice) {
                                    if (root.interactionState)
                                        root.interactionState.unlockInteraction();
                                    return;
                                }

                                BluetoothService.forgetDevice(root.device);
                                if (root.interactionState)
                                    root.interactionState.unlockInteraction();
                            }
                        }
""",
)

# Active transport and interface diagnostics no longer compete with a duplicate wired card.
network_page = "configs/phenix-shell/modules/quickmenu/Network.qml"
replace_once(network_page, '        title: "Connection details"\n', '        title: qsTr("Interface diagnostics")\n')
replace_once(
    network_page,
    """        showDetailToggle: true
        summary: Component {
""",
    """        showDetailToggle: true
        headerAccessory: Component {
            SmallButton {
                visible: NetworkService.hasWiredConnection
                text: qsTr(\"Disconnect\")
                accessibleName: qsTr(\"Disconnect wired connection\")
                onClicked: NetworkService.disconnectWired()
            }
        }
        summary: Component {
""",
)
content = read(network_page)
start = content.index("\n    DashboardSection {\n        id: wiredDetails")
end = content.rindex("\n}")
write(network_page, content[:start] + content[end:])

# Overview groups the two highest-frequency direct control domains.
overview = "configs/phenix-shell/modules/quickmenu/Overview.qml"
content = read(overview)
start = content.index("    DashboardSection {\n        id: audioSection")
end = content.index("    NavigableSectionHeader {\n        id: networkSection")
quick_controls = """    DashboardSection {
        id: quickControlsSection
        Layout.fillWidth: true
        title: qsTr(\"Quick controls\")
        iconName: AudioService.outputIconName
        iconColor: AudioService.outputMuted
            ? Config.styling.critical
            : AudioService.outputIconColor
        titleColor: iconColor
        showDetailToggle: !!AudioService.defaultSource

        AudioDeviceCard {
            title: AudioService.outputDeviceName
            iconName: AudioService.outputIconName
            iconColor: AudioService.outputIconColor
            valueText: AudioService.defaultSink ? `${AudioService.outputVolume}%` : \"\"
            from: 0
            to: 100
            value: AudioService.outputVolume
            stepSize: 1
            iconEnabled: !!AudioService.defaultSink
            sliderEnabled: !!AudioService.defaultSink && !AudioService.outputMuted
            accentColor: AudioService.outputMuted
                ? Config.styling.critical
                : Config.colors.blue
            onIconClicked: AudioService.toggleOutputMute()
            onValueModified: value => AudioService.setOutputVolume(value)
        }

        LabeledSlider {
            Layout.fillWidth: true
            visible: Brightness.available
            label: qsTr(\"Brightness\")
            iconName: Brightness.iconName
            value: Brightness.percent
            from: 0
            to: 100
            valueText: `${Brightness.percent}%`
            onValueCommitted: value => Brightness.setPercent(value)
        }

        AudioDeviceCard {
            visible: quickControlsSection.detailed || AudioService.inputMuted
            title: AudioService.inputDeviceName
            iconName: AudioService.inputIconName
            iconColor: AudioService.inputIconColor
            valueText: AudioService.defaultSource ? `${AudioService.inputVolume}%` : \"\"
            from: 0
            to: 100
            value: AudioService.inputVolume
            stepSize: 1
            iconEnabled: !!AudioService.defaultSource
            sliderEnabled: !!AudioService.defaultSource && !AudioService.inputMuted
            accentColor: AudioService.inputMuted
                ? Config.styling.critical
                : Config.colors.blue
            onIconClicked: AudioService.toggleInputMute()
            onValueModified: value => AudioService.setInputVolume(value)
        }
    }

"""
write(overview, content[:start] + quick_controls + content[end:])

# Stats headers are summaries; normal body content appears only when promoted or detailed.
stats = "configs/phenix-shell/modules/quickmenu/SystemStats.qml"
replace_once(stats, "        overviewDelegate: Component { CpuOverview {} }\n        promotedDelegate: Component { CpuOverview {} }\n", "        overviewDelegate: null\n        promotedDelegate: Component { CpuOverview {} }\n")
replace_once(stats, "        overviewDelegate: Component { MemoryOverview {} }\n        promotedDelegate: Component { MemoryOverview {} }\n", "        overviewDelegate: null\n        promotedDelegate: Component { MemoryOverview {} }\n")
replace_once(stats, "        overviewDelegate: Component { GpuOverview {} }\n        promotedDelegate: Component { GpuOverview {} }\n", "        overviewDelegate: null\n        promotedDelegate: Component { GpuOverview {} }\n")
replace_once(
    stats,
    """        overviewDelegate: Component {
            StorageOverview { rows: storageObservation.rootRows }
        }
        promotedDelegate: Component {
            StorageOverview { rows: storageObservation.visibleRows }
        }
""",
    """        overviewDelegate: null
        promotedDelegate: Component {
            StorageOverview { rows: storageObservation.exceptionalRows }
        }
""",
)
content = read(stats)
network_start = content.index('    AdaptiveDashboardSection {\n        observation: networkObservation')
detail_start = content.index('        detailedDelegate: Component {', network_start)
section_end_marker = '\n        Layout.fillWidth: true\n    }\n\n    component MetricGrid'
detail_end = content.index(section_end_marker, detail_start)
content = content[:detail_start] + '        detailedDelegate: null\n' + content[detail_end:]
cpu_start = content.index('    component CpuOverview: MetricGrid {')
repeater_start = content.index('        Repeater {\n            model: cpuObservation.promotedRows', cpu_start)
content = content[:cpu_start] + '    component CpuOverview: MetricGrid {\n' + content[repeater_start:]
write(stats, content)

write(
    "docs/ui-design.md",
    """# Phenix shell UI composition contract

This is the implementation contract for the Quickshell dashboard. It combines
its source audit with the composition review.

## Scope

Controls belong to exactly one scope: dashboard chrome, page header, section
header, object row, or temporary interaction tray. A control must not look local
while changing a broader scope.

## Disclosure

A detail arrow always means “show more information about this object.” Global
detail forces informational detail open. Lists of independent objects use row
arrows rather than another list-level arrow. Connection, pairing, password, and
confirmation trays remain operational state and do not open diagnostics.

## Composition

Overview exposes primary controls and exceptional state. Dedicated pages own
management, history, and diagnostics. Active objects are not repeated in
multiple competing cards. Device pages use one principal scroll surface.

## Interaction

Every pointer action has a keyboard path and an accessible name. Pressed is
visually distinct from hover, and focus remains visible on active controls.
Compact icon actions are at least 32 by 32 pixels; ordinary rows are at least 36
pixels high.

Clear, forget, logout, reboot, shutdown, and comparable actions require a second
activation or reliable undo. Confirmation times out and is cancelled by Escape
or focus loss.

## Motion

Use only the canonical motion tokens: micro 100 ms, short 160 ms, medium 220 ms,
and long 320 ms. Enter uses OutCubic, exit uses InCubic, and layout movement uses
InOutCubic. Fast-input mode may shorten a transition but does not change its
semantic direction. Motion remains interruptible and safe with animations off.

## Lifecycle

Signal connections, timers, queued callbacks, and render requests must not
survive their visual owner. Dynamic connections are disconnected before
destruction and callbacks become harmless while teardown is active.

## Catppuccin depth

Use crust for the lowest underlay, mantle for persistent chrome, base for the
page canvas, surface0 for cards, surface1 for nested or hover state, and surface2
for pressed or strong selection. Accent colors remain semantic rather than
purely decorative.
""",
)

print("dashboard composition transformations applied")
