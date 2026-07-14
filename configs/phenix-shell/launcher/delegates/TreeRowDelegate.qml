import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs.animations as Animations
import qs.components
import qs.services

Rectangle {
    id: root

    required property TreeView treeView
    required property bool isTreeNode
    required property bool expanded
    required property bool hasChildren
    required property int depth
    required property int row
    required property int column
    required property bool current

    property var controller: null
    property int rowHeight: 40
    readonly property string title: cell(0) || ""
    readonly property string subtitle: cell(1) || ""
    readonly property string iconName: cell(2) || ""
    readonly property var iconColor: cell(3) || undefined
    readonly property bool isPipewireControl: !!root.control && root.control.target === "pipewire"
    readonly property bool isPowerProfileControl: !!root.control && root.control.target === "power-profile"
    readonly property string effectiveIconName: root.isPowerProfileControl
        ? PowerService.profileIconName(PowerService.profile)
        : (root.isPipewireControl && root.sliderNode ? root.sliderIconName() : root.iconName)
    readonly property var effectiveIconColor: root.isPowerProfileControl
        ? PowerService.profileColor(PowerService.profile)
        : (root.isPipewireControl && root.sliderNode && root.sliderNode.audio)
        ? (root.sliderNode.audio.muted ? Config.styling.critical : Config.styling.secondaryAccent)
        : root.iconColor
    readonly property var switchState: cell(4)
    readonly property bool hasActions: !!cell(5)
    readonly property bool hasSwitchActions: !!cell(6)
    readonly property string defaultActionLabel: cell(7) || ""
    readonly property string key: cell(9) || ""
    readonly property bool lazy: !!cell(11)
    readonly property var control: cell(12) || null
    readonly property bool alwaysExpanded: !!cell(13)
    readonly property var labelMatches: cell(15) || []
    readonly property var subtitleMatches: cell(16) || []
    readonly property bool hasSlider: !!control && control.kind === "slider"
    readonly property var sliderNode: sliderNodeFor(control)
    readonly property real sliderValue: sliderValueFor(control, sliderNode)
    readonly property bool liveSwitchState: switchStateFor(control, sliderNode)
    readonly property bool active: root.controller && root.controller.activeNodeKey === root.key
    readonly property real revealProgress: root.treeView && typeof root.treeView.rowRevealProgress === "function" ? root.treeView.rowRevealProgress(root.row) : 1
    readonly property real revealSlideOffset: -Config.spacing.sm * (1 - revealProgress)
    readonly property int depthInset: root.depth * Config.spacing.xs
    readonly property real rowPanelHeight: Math.max(0, root.height - Math.max(Config.spacing.xxs, root.depthGap(root.depth) - Config.spacing.xxs))
    readonly property real rowPanelY: root.height <= 0 ? 0 : (root.height - root.rowPanelHeight) / 2
    readonly property real contentInsetY: Config.spacing.xxs
    property bool animateEntry: false
    property bool entryAnimationActive: false
    property bool entryReady: false

    function cell(column) {
        if (!root.treeView || !root.treeView.model)
            return null;
        if (root.row < 0 || root.row >= root.treeView.rows)
            return null;
        var idx = root.treeView.index(root.row, column);
        if (!idx.valid)
            return null;
        return root.treeView.model.data(idx, "display");
    }

    function depthGap(depth) {
        return Math.max(Config.spacing.xxs, Config.spacing.xs - depth * 2);
    }

    implicitHeight: root.rowHeight
    opacity: !entryAnimationActive || entryReady ? 1 : 0
    clip: true
    z: root.depth

    Component.onCompleted: {
        if (root.animateEntry && Config.behaviour.animation.enabled) {
            root.entryAnimationActive = true;
            Qt.callLater(function() { root.entryReady = true; });
        }
    }

    Animations.RevealBehavior on opacity {
    }

    onCurrentChanged: {
        if (root.current && root.controller) {
            root.controller.currentTreeView = root.treeView;
            root.controller.treeVisualRow = root.row;
            root.controller.currentTreeKey = root.key;
            root.controller.activeNodeKey = root.key;
        }
    }
    color: "transparent"
    border.width: 0

    Rectangle {
        id: depthPanel
        x: root.depthInset
        y: root.rowPanelY + root.revealSlideOffset
        width: root.width - root.depthInset * 2
        height: root.rowPanelHeight
        color: root.active ? Config.styling.selectionBackground : (root.depth % 2 === 0 ? Config.styling.bg3 : Config.styling.bg4)
        border.color: root.active ? Config.styling.primaryAccent : Config.styling.bg5
        border.width: 1
        radius: Config.styling.radius

        Animations.StateColorBehavior on color {
        }

        Animations.StateColorBehavior on border.color {
        }
    }

    Item {
        id: contentFrame
        x: Config.spacing.xs
        y: root.rowPanelY + root.revealSlideOffset
        width: parent.width - Config.spacing.xs * 2
        height: root.rowPanelHeight

        RowLayout {
            anchors.fill: parent
            anchors.topMargin: root.contentInsetY
            anchors.bottomMargin: root.contentInsetY
            spacing: Config.spacing.sm

            Item {
                implicitWidth: 12
                implicitHeight: 12
                Layout.alignment: Qt.AlignVCenter

                Icon {
                    anchors.fill: parent
                    visible: root.hasChildren
                    iconName: root.expanded ? "pan-down-symbolic" : "pan-end-symbolic"
                    color: Config.styling.text1

                    Animations.StateColorBehavior on color {
                    }
                }

                TapHandler {
                    onSingleTapped: {
                        if (!root.hasChildren)
                            return;
                        root.selectThisRow();
                        if (root.lazy && !root.expanded) {
                            if (root.controller)
                                root.controller.loadLazyChildren(root.key);
                        } else {
                            if (root.treeView && typeof root.treeView.toggleExpandedAnimated === "function")
                                root.treeView.toggleExpandedAnimated(root.row);
                            else
                                root.treeView.toggleExpanded(root.row);
                        }
                    }
                }
            }

            Icon {
                visible: !!root.effectiveIconName && root.effectiveIconName !== "system-search"
                iconName: root.effectiveIconName
                fallbackIconName: "system-search"
                color: root.effectiveIconColor
                implicitSize: 20
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                Layout.alignment: Qt.AlignVCenter

                Animations.StateColorBehavior on color {
                }
            }

            ColumnLayout {
                spacing: Config.spacing.xxs
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter

                Text {
                    text: root.buildHighlightedText(root.title, root.labelMatches)
                    color: Config.styling.text0
                    font.pixelSize: 13
                    font.bold: false
                    textFormat: root.labelMatches.length > 0 ? Text.StyledText : Text.PlainText
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    Layout.fillWidth: true
                }

                Text {
                    text: root.buildHighlightedText(root.subtitle, root.subtitleMatches)
                    visible: !!root.subtitle
                    color: Config.styling.text2
                    font.pixelSize: 11
                    textFormat: root.subtitleMatches.length > 0 ? Text.StyledText : Text.PlainText
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    Layout.fillWidth: true
                }
            }

            Text {
                text: root.defaultActionLabel
                readonly property bool hintVisible: root.hasActions && text.length > 0 && !switchColumn.visible && !sliderColumn.visible
                visible: hintVisible || opacity > 0
                opacity: hintVisible ? 1 : 0
                color: Config.styling.text1
                font.pixelSize: 12
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 92
                Layout.alignment: Qt.AlignVCenter

                Animations.RevealBehavior on opacity {
                }
            }

            ColumnLayout {
                id: switchColumn
                visible: root.hasSwitchActions && !sliderColumn.visible
                spacing: Config.spacing.xxs
                Layout.alignment: Qt.AlignVCenter
                Layout.minimumWidth: 132
                Layout.preferredWidth: 132
                Layout.maximumWidth: 132

                Item {
                    Layout.alignment: Qt.AlignRight
                    Layout.preferredWidth: switchControl.implicitWidth
                    Layout.preferredHeight: switchControl.implicitHeight

                    DashboardToggleSwitch {
                        id: switchControl
                        checked: root.liveSwitchState
                        anchors.fill: parent
                        onToggled: {
                            if (root.controller)
                                root.controller.activateTreeRowByKey(root.key, "toggle");
                        }
                    }
                }
            }

            RowLayout {
                id: sliderColumn
                visible: root.hasSlider
                spacing: Config.spacing.xs
                Layout.alignment: Qt.AlignVCenter
                Layout.minimumWidth: 160
                Layout.preferredWidth: 160
                Layout.maximumWidth: 160

                AudioLevelSlider {
                    id: sliderControl
                    visible: !root.control || root.control.target !== "power-profile"
                    from: root.control ? root.control.from || 0 : 0
                    to: root.control ? root.control.to || 100 : 100
                    stepSize: root.control ? root.control.step || 1 : 1
                    value: root.sliderValue
                    valueText: Math.round(root.sliderValue) + "%"
                    showIcon: false
                    iconName: root.sliderIconName()
                    iconColor: root.sliderNode && root.sliderNode.audio && root.sliderNode.audio.muted ? Config.styling.critical : Config.styling.text0
                    accentColor: root.sliderNode && root.sliderNode.audio && root.sliderNode.audio.muted ? Config.styling.critical : Config.colors.blue
                    valueTextWidth: 34
                    iconSize: 18
                    enabled: root.sliderEnabled()
                    Layout.fillWidth: true
                    onIconClicked: {
                        if (root.sliderNode && root.sliderNode.audio)
                            root.sliderNode.audio.muted = !root.sliderNode.audio.muted;
                    }
                    onValueModified: root.applySliderValue(value)
                }

                PowerProfileSlider {
                    visible: root.control && root.control.target === "power-profile"
                    value: root.sliderValue
                    onValueModified: root.applySliderValue(value)
                    Layout.fillWidth: true
                }
            }

        }
    }

    function sliderNodeFor(control) {
        if (!control || (control.target !== "pipewire" && control.target !== "pipewire-mute"))
            return null;
        for (const node of Pipewire.nodes.values || []) {
            if (String(node.id) === String(control.nodeId))
                return node;
        }
        return null;
    }

    function switchStateFor(control, node) {
        if (control && (control.target === "pipewire-mute" || control.target === "pipewire") && node && node.audio)
            return node.audio.muted === true;
        return root.switchState === true;
    }

    function sliderIconName() {
        if (!root.sliderNode || !root.sliderNode.audio)
            return "audio-volume-muted-symbolic";
        if (root.sliderNode.audio.muted)
            return "audio-volume-muted-symbolic";
        var vol = root.sliderNode.audio.volume || 0;
        if (vol <= 0.001)
            return "audio-volume-muted-symbolic";
        if (vol < 0.34)
            return "audio-volume-low-symbolic";
        if (vol < 0.67)
            return "audio-volume-medium-symbolic";
        return "audio-volume-high-symbolic";
    }

    function sliderValueFor(control, node) {
        if (!control || control.kind !== "slider")
            return 0;
        if (control.target === "brightness")
            return Brightness.percent;
        if (control.target === "pipewire" && node && node.audio)
            return Math.round((node.audio.volume || 0) * 100);
        if (control.target === "power-profile")
            return root.modeIndex(PowerProfiles.profile);
        return control.value || 0;
    }

    function sliderEnabled() {
        if (!root.control || root.control.kind !== "slider")
            return false;
        if (root.control.target === "brightness")
            return Brightness.available;
        if (root.control.target === "power-profile")
            return true;
        return !!(root.sliderNode && root.sliderNode.audio);
    }

    function applySliderValue(value) {
        if (!root.control || root.control.kind !== "slider")
            return;
        if (root.control.target === "brightness") {
            Brightness.setPercent(value);
            return;
        }
        if (root.control.target === "pipewire" && root.sliderNode && root.sliderNode.audio)
            root.sliderNode.audio.volume = Math.max(0, Math.min((root.control.to || 100) / 100, value / 100));
        if (root.control.target === "power-profile") {
            PowerProfiles.profile = root.modeFromIndex(value);
            return;
        }
    }

    function modeIndex(mode) {
        switch (mode) {
        case PowerProfile.PowerSaver: return 0;
        case PowerProfile.Performance: return 2;
        default: return 1;
        }
    }

    function modeFromIndex(index) {
        switch (Math.round(index)) {
        case 0: return PowerProfile.PowerSaver;
        case 2: return PowerProfile.Performance;
        default: return PowerProfile.Balanced;
        }
    }

    function buildHighlightedText(text, matches) {
        if (!matches || matches.length === 0 || !text)
            return text || "";
        function escapeHtml(s) {
            return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        }
        var sorted = matches.slice().sort(function(a, b) { return a.start - b.start; });
        var merged = [];
        for (var i = 0; i < sorted.length; i++) {
            var r = sorted[i];
            if (r.start >= text.length) break;
            if (r.end <= 0) continue;
            if (!merged.length) {
                merged.push({ start: Math.max(0, r.start), end: Math.min(text.length, r.end) });
            } else {
                var last = merged[merged.length - 1];
                var s = Math.max(0, r.start);
                var e = Math.min(text.length, r.end);
                if (s <= last.end) {
                    last.end = Math.max(last.end, e);
                } else {
                    merged.push({ start: s, end: e });
                }
            }
        }
        var result = "";
        var pos = 0;
        for (var i = 0; i < merged.length; i++) {
            var r = merged[i];
            if (r.start > pos)
                result += escapeHtml(text.substring(pos, r.start));
            result += "<font color=\"" + String(Config.colors.blue) + "\">" + escapeHtml(text.substring(r.start, r.end)) + "</font>";
            pos = r.end;
        }
        if (pos < text.length)
            result += escapeHtml(text.substring(pos));
        return result;
    }

    function selectThisRow() {
        if (!root.treeView || !root.treeView.selectionModel || root.row < 0 || root.row >= root.treeView.rows)
            return;
        var idx = root.treeView.index(root.row, 0);
        if (!idx.valid)
            return;
        root.treeView.selectionModel.setCurrentIndex(idx, ItemSelectionModel.SelectCurrent);
        if (root.controller) {
            root.controller.currentTreeView = root.treeView;
            root.controller.treeVisualRow = root.row;
            root.controller.currentTreeKey = root.key;
            root.controller.activeNodeKey = root.key;
        }
    }

    TapHandler {
        onSingleTapped: {
            root.selectThisRow();
        }
        onDoubleTapped: {
            if (root.controller)
                root.controller.activateTreeRowByKey(root.key, null);
        }
    }
}
