pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.services
import "audio"

Singleton {
    id: root

    readonly property var tracer: Logger.scope("audio.service", { category: "audio" })
    readonly property var prof: Profiler.scope("audio.service", { category: "audio" })

    readonly property var backend: Pipewire

    readonly property PipewireQuery pipewireQuery: PipewireQuery {}
    readonly property AudioNodeUtils nodeUtils: AudioNodeUtils {}
    readonly property AudioModels audioModels: AudioModels {}
    readonly property AudioPresentation audioPresentation: AudioPresentation {}
    readonly property AudioCommands audioCommands: AudioCommands {
        onMoveStreamFinished: function(success, message) {
            root.finishOperation(success, message);
            root._revision++;
        }
    }
    readonly property AudioDeviceNormalizer normalizer: AudioDeviceNormalizer {
        nodeUtils: root.nodeUtils
        audioModels: root.audioModels
        allNodes: root.allNodes
        linkGroups: root.linkGroups
        defaultSink: root.defaultSink
        defaultSource: root.defaultSource
    }

    readonly property bool available: true

    readonly property var defaultSink: Pipewire.defaultAudioSink
    readonly property var defaultSource: Pipewire.defaultAudioSource

    readonly property var allNodes: root.audioModels.collectNodes(Pipewire.nodes.values || [])
    readonly property var linkGroups: Pipewire.linkGroups.values || []

    readonly property int _rev: root._revision

    readonly property real outputVolume: defaultSink && defaultSink.audio ? Math.round((defaultSink.audio.volume || 0) * 100) : 0
    readonly property bool outputMuted: defaultSink && defaultSink.audio ? defaultSink.audio.muted : false
    readonly property string outputDeviceName: defaultSink ? root.nodeUtils.nodeName(defaultSink, "Output") : "No output"

    readonly property real inputVolume: defaultSource && defaultSource.audio ? Math.round((defaultSource.audio.volume || 0) * 100) : 0
    readonly property bool inputMuted: defaultSource && defaultSource.audio ? defaultSource.audio.muted : false
    readonly property string inputDeviceName: defaultSource ? root.nodeUtils.nodeName(defaultSource, "Input") : "No input"

    property var _revision: 0
    property string currentOperationKind: ""
    property string currentOperationTarget: ""
    property bool currentOperationRunning: false
    property string currentOperationLastError: ""

    readonly property var operation: ({
        kind: currentOperationKind,
        target: currentOperationTarget,
        running: currentOperationRunning,
        lastError: currentOperationLastError
    })
    readonly property bool busy: currentOperationRunning

    function beginOperation(kind, target) {
        currentOperationKind = kind || "";
        currentOperationTarget = target || "";
        currentOperationRunning = true;
        currentOperationLastError = "";
    }

    function finishOperation(success, message) {
        currentOperationRunning = false;
        currentOperationLastError = success ? "" : (message || `${currentOperationKind || "operation"} failed`);
    }

    readonly property string outputIconName: {
        if (!defaultSink) return "audio-volume-muted-symbolic";
        if (root.outputMuted) return "audio-volume-muted-symbolic";
        if (root.outputVolume <= 0) return "audio-volume-muted-symbolic";
        if (root.outputVolume < 34) return "audio-volume-low-symbolic";
        if (root.outputVolume < 67) return "audio-volume-medium-symbolic";
        return "audio-volume-high-symbolic";
    }
    readonly property color outputIconColor: outputMuted ? Config.styling.critical : (outputVolume === 0 ? Config.styling.warning : Config.styling.text0)
    readonly property string inputIconName: {
        if (!defaultSource) return "audio-input-microphone-symbolic";
        if (root.inputMuted) return "microphone-sensitivity-muted-symbolic";
        if (root.inputVolume <= 0) return "microphone-sensitivity-muted-symbolic";
        return "audio-input-microphone-symbolic";
    }
    readonly property color inputIconColor: inputMuted ? Config.styling.critical : (inputVolume === 0 ? Config.styling.warning : Config.styling.text0)

    readonly property string label: "Audio"
    readonly property string statusText: defaultSink ? `${root.nodeUtils.nodeName(defaultSink, "Output")} ${root.outputVolume}%` : "No output"

    readonly property var presentation: {
        return {
            icon: root.outputIconName,
            color: root.outputIconColor,
            label: root.label,
            status: root.statusText,
            outputDeviceName: root.outputDeviceName,
            outputVolume: root.outputVolume,
            outputMuted: root.outputMuted,
            inputDeviceName: root.inputDeviceName,
            inputVolume: root.inputVolume,
            inputMuted: root.inputMuted
        };
    }

    readonly property var outputPresentation: {
        return {
            icon: root.outputIconName,
            color: root.outputIconColor,
            deviceName: root.outputDeviceName,
            volume: root.outputVolume,
            muted: root.outputMuted,
            control: root.outputVolumeControl
        };
    }

    readonly property var inputPresentation: {
        return {
            icon: root.inputIconName,
            color: root.inputIconColor,
            deviceName: root.inputDeviceName,
            volume: root.inputVolume,
            muted: root.inputMuted,
            control: root.inputVolumeControl
        };
    }

    function executePayload(payload) {
        if (!payload) {
            root.tracer.warn("executePayload.nullPayload");
            return false;
        }
        root.tracer.debug("executePayload", function() { return { op: payload.op, nodeId: payload.nodeId } });
        switch (payload.op) {
        case "setVolume": return root.setVolumeById(payload.nodeId, Number(payload.value || 0));
        case "adjustVolume": return root.setVolumeById(payload.nodeId, root.volumePercentById(payload.nodeId) + Number(payload.delta || 0));
        case "setMuted": return root.setMutedById(payload.nodeId, !!payload.muted);
        case "toggleMute": return root.toggleMuteById(payload.nodeId);
        case "setDefaultOutput": root.setDefaultOutput(payload.nodeId); return true;
        case "setDefaultInput": root.setDefaultInput(payload.nodeId); return true;
        default: root.tracer.warn("executePayload.unknownOp", function() { return { op: payload.op } }); return false;
        }
    }

    function volumePercentById(id) {
        const node = root.pipewireQuery.rawNodeById(id);
        return node ? root.nodeUtils.volumePercent(node) : null;
    }

    function setVolumeById(id, percent) {
        root.tracer.trace("setVolumeById", function() { return { nodeId: id, percent: percent } });
        const node = root.pipewireQuery.rawNodeById(id);
        if (!node) {
            root.tracer.warn("setVolumeById.nodeNotFound", function() { return { nodeId: id } });
            return false;
        }
        root.beginOperation("set-volume", String(id));
        root.nodeUtils.setVolume(node, percent);
        root._revision++;
        root.finishOperation(true, "");
        root.tracer.info("volumeSet", function() { return { nodeId: id, percent: percent, name: root.nodeUtils.nodeName(node) } });
        return true;
    }

    function setMutedById(id, value) {
        root.tracer.trace("setMutedById", function() { return { nodeId: id, muted: value } });
        const node = root.pipewireQuery.rawNodeById(id);
        if (!node) {
            root.tracer.warn("setMutedById.nodeNotFound", function() { return { nodeId: id } });
            return false;
        }
        root.beginOperation("toggle", String(id));
        root.nodeUtils.setMuted(node, value);
        root._revision++;
        root.finishOperation(true, "");
        root.tracer.info("muteSet", function() { return { nodeId: id, muted: value, name: root.nodeUtils.nodeName(node) } });
        return true;
    }

    function toggleMuteById(id) {
        root.tracer.trace("toggleMuteById", function() { return { nodeId: id } });
        const node = root.pipewireQuery.rawNodeById(id);
        if (!node) {
            root.tracer.warn("toggleMuteById.nodeNotFound", function() { return { nodeId: id } });
            return false;
        }
        root.beginOperation("toggle", String(id));
        root.nodeUtils.toggleMute(node);
        root._revision++;
        root.finishOperation(true, "");
        root.tracer.info("muteToggled", function() { return { nodeId: id, muted: root.nodeUtils.isMuted(node), name: root.nodeUtils.nodeName(node) } });
        return true;
    }

    function setVolume(node, value) {
        root.beginOperation("set-volume", node ? String(node.id) : "");
        if (!root.audioCommands.setVolume(node, value)) {
            root.tracer.error("setVolume.failed", function() { return { nodeId: node ? node.id : null, value: value } });
            root.finishOperation(false, "Audio node not found");
            return;
        }
        root._revision++;
        root.finishOperation(true, "");
        root.tracer.info("volumeSet", function() { return { nodeId: node ? node.id : null, value: value } });
    }

    function toggleMute(node) {
        root.beginOperation("toggle", node ? String(node.id) : "");
        if (!root.audioCommands.toggleMute(node)) {
            root.tracer.error("toggleMute.failed", function() { return { nodeId: node ? node.id : null } });
            root.finishOperation(false, "Audio node not found");
            return;
        }
        root._revision++;
        root.finishOperation(true, "");
        root.tracer.trace("muteToggled", function() { return { nodeId: node ? node.id : null } });
    }

    function setDefaultSink(sink) {
        root.beginOperation("set-profile", sink ? String(sink.id) : "");
        if (!root.audioCommands.setDefaultSink(sink)) {
            root.tracer.error("setDefaultSink.failed", function() { return { sinkId: sink ? sink.id : null } });
            root.finishOperation(false, "Audio output not found");
            return;
        }
        root._revision++;
        root.finishOperation(true, "");
        root.tracer.info("defaultSinkChanged", function() { return { sinkId: sink ? sink.id : null, name: sink ? root.nodeUtils.nodeName(sink) : null } });
    }

    function setDefaultSource(source) {
        root.beginOperation("set-profile", source ? String(source.id) : "");
        if (!root.audioCommands.setDefaultSource(source)) {
            root.tracer.error("setDefaultSource.failed", function() { return { sourceId: source ? source.id : null } });
            root.finishOperation(false, "Audio input not found");
            return;
        }
        root._revision++;
        root.finishOperation(true, "");
        root.tracer.info("defaultSourceChanged", function() { return { sourceId: source ? source.id : null, name: source ? root.nodeUtils.nodeName(source) : null } });
    }

    function setOutputVolume(value) {
        root.beginOperation("set-volume", defaultSink ? String(defaultSink.id) : "");
        if (defaultSink && defaultSink.audio) defaultSink.audio.volume = Math.max(0, Math.min(1, value / 100));
        root._revision++;
        root.finishOperation(true, "");
        root.tracer.debug("outputVolumeSet", function() { return { value: value, name: root.outputDeviceName } });
    }

    function adjustOutputVolume(delta) {
        const target = root.outputVolume + delta;
        root.beginOperation("set-volume", defaultSink ? String(defaultSink.id) : "");
        if (defaultSink && defaultSink.audio) defaultSink.audio.volume = Math.max(0, Math.min(1, target / 100));
        root._revision++;
        root.finishOperation(true, "");
        root.tracer.debug("outputVolumeAdjusted", function() { return { delta: delta, target: target } });
    }

    function toggleOutputMute() {
        root.beginOperation("toggle", defaultSink ? String(defaultSink.id) : "");
        if (defaultSink && defaultSink.audio) defaultSink.audio.muted = !defaultSink.audio.muted;
        root._revision++;
        root.finishOperation(true, "");
        root.tracer.info("outputMuteToggled", function() { return { muted: root.outputMuted } });
    }

    function setInputVolume(value) {
        root.setVolume(defaultSource, value);
    }

    function adjustInputVolume(delta) {
        root.beginOperation("set-volume", defaultSource ? String(defaultSource.id) : "");
        root.nodeUtils.adjustVolume(defaultSource, delta);
        root._revision++;
        root.finishOperation(true, "");
        root.tracer.debug("inputVolumeAdjusted", function() { return { delta: delta } });
    }

    function toggleInputMute() {
        root.toggleMute(defaultSource);
    }

    function setDefaultOutput(id) {
        root.beginOperation("set-profile", String(id || ""));
        const node = root.pipewireQuery.rawNodeById(id);
        if (node) {
            root.setDefaultSink(node);
            return;
        }
        root.tracer.warn("setDefaultOutput.notFound", function() { return { id: id } });
        root.finishOperation(false, "Audio output not found");
    }

    function setDefaultInput(id) {
        root.beginOperation("set-profile", String(id || ""));
        const node = root.pipewireQuery.rawNodeById(id);
        if (node) {
            root.setDefaultSource(node);
            return;
        }
        root.tracer.warn("setDefaultInput.notFound", function() { return { id: id } });
        root.finishOperation(false, "Audio input not found");
    }

    function moveStreamTo(stream, sink) {
        const streamNode = typeof stream === "object" ? stream : root.pipewireQuery.rawNodeById(stream);
        const targetNode = typeof sink === "object" ? sink : root.pipewireQuery.rawNodeById(sink);
        root.beginOperation("move-stream", `${streamNode ? streamNode.id : stream}:${targetNode ? targetNode.id : sink}`);
        if (!streamNode || !targetNode) {
            root.tracer.error("moveStreamTo.notFound", function() { return { stream: typeof stream, sink: typeof sink } });
            root.finishOperation(false, "Audio stream or target not found");
            return;
        }
        root.tracer.info("moveStreamTo", function() { return { streamId: streamNode.id, targetId: targetNode.id } });
        root.audioCommands.moveStreamTo(streamNode, targetNode);
    }

    readonly property var outputVolumeControl: defaultSink ? root.normalizer.volumeControl(defaultSink) : null
    readonly property var inputVolumeControl: defaultSource ? root.normalizer.volumeControl(defaultSource) : null

    readonly property var outputEntries: _rev >= 0 ? root.normalizer.outputDeviceEntries() : []
    readonly property var inputEntries: _rev >= 0 ? root.normalizer.inputDeviceEntries() : []

    function outputDeviceEntries() { return root.outputEntries; }
    function inputDeviceEntries() { return root.inputEntries; }
    function streamEntriesForOutput(outputId) { return root.normalizer.streamEntriesForOutput(outputId); }
    function outputEntriesForStreamMove() { return root.outputEntries; }

    PwObjectTracker {
        objects: root.allNodes
    }

    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() { root._revision++; }
        function onDefaultAudioSourceChanged() { root._revision++; }
    }

    Connections {
        target: root.defaultSink ? root.defaultSink.audio : null
        function onVolumesChanged() { root._revision++; }
        function onMutedChanged() { root._revision++; }
    }

    Connections {
        target: root.defaultSource ? root.defaultSource.audio : null
        function onVolumesChanged() { root._revision++; }
        function onMutedChanged() { root._revision++; }
    }

    Connections {
        target: Pipewire.nodes
        function onValuesChanged() { root._revision++; }
    }

    Connections {
        target: Pipewire.linkGroups
        function onValuesChanged() { root._revision++; }
    }
}
