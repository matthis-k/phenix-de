import QtQml
import Quickshell.Services.Pipewire
import qs.services

QtObject {
    id: root

    readonly property var tracer: Logger.scope("audio.normalizer", { category: "audio" })
    readonly property var prof: Profiler.scope("audio.normalizer", { category: "audio" })

    property var nodeUtils: null
    property var audioModels: null
    property var allNodes: []
    property var linkGroups: []
    property var defaultSink: null
    property var defaultSource: null

    function normalizeDevice(node, isInput) {
        const muted = root.nodeUtils.isMuted(node);
        const isDefault = isInput
            ? (root.defaultSource && node.id === root.defaultSource.id)
            : (root.defaultSink && node.id === root.defaultSink.id);
        const vol = root.nodeUtils.volumePercent(node);

        return {
            raw: node,
            id: String(node.id),
            name: root.nodeUtils.nodeName(node, isInput ? "Input" : "Output"),
            kind: isInput ? "input" : "output",
            default: isDefault,
            volume: vol,
            muted: muted,
            iconName: root.nodeUtils.volumeIconName(node, isInput),
            iconColor: muted ? root.errorColor() : root.textColor(),
            statusText: isDefault ? "Default" : `${vol}%`,
            control: {
                kind: "slider",
                target: "audio",
                nodeId: node.id,
                from: 0,
                to: 100,
                step: 5,
                value: vol
            },
            switchActions: {
                toggle: {
                    id: "toggle",
                    title: "Toggle",
                    state: null,
                    payload: { service: "audio", op: "toggleMute", nodeId: String(node.id) }
                },
                on: {
                    id: "on",
                    title: "On",
                    state: true,
                    payload: { service: "audio", op: "setMuted", nodeId: String(node.id), muted: true }
                },
                off: {
                    id: "off",
                    title: "Off",
                    state: false,
                    payload: { service: "audio", op: "setMuted", nodeId: String(node.id), muted: false }
                }
            }
        };
    }

    function normalizeStream(stream) {
        const props = stream.properties || {};
        const mediaName = props["media.name"];
        const appName = props["application.name"];
        const name = mediaName || appName || root.nodeUtils.nodeName(stream, "Stream");
        const vol = root.nodeUtils.volumePercent(stream);
        const muted = root.nodeUtils.isMuted(stream);

        return {
            raw: stream,
            id: String(stream.id),
            name: name,
            kind: "stream",
            default: false,
            volume: vol,
            muted: muted,
            iconName: props["application.icon-name"] || "audio-x-generic-symbolic",
            iconColor: muted ? root.errorColor() : root.textColor(),
            statusText: `${vol}%`,
            control: {
                kind: "slider",
                target: "audio",
                nodeId: stream.id,
                from: 0,
                to: 100,
                step: 5,
                value: vol
            },
            switchActions: {
                toggle: {
                    id: "toggle",
                    title: "Toggle",
                    state: null,
                    payload: { service: "audio", op: "toggleMute", nodeId: String(stream.id) }
                }
            }
        };
    }

    function outputDeviceEntries() {
        const sinks = root.audioModels.audioSinks(root.allNodes).slice();
        sinks.sort(function(a, b) {
            const aDefault = root.defaultSink && a.id === root.defaultSink.id;
            const bDefault = root.defaultSink && b.id === root.defaultSink.id;
            if (aDefault !== bDefault) return aDefault ? -1 : 1;
            return root.nodeUtils.nodeName(a).localeCompare(root.nodeUtils.nodeName(b));
        });
        const entries = sinks.map(function(sink) {
            const entry = root.normalizeDevice(sink, false);
            entry.streams = root.streamEntriesForOutput(entry.id);
            return entry;
        });
        root.tracer.trace("outputDeviceEntries", function() { return { count: entries.length } });
        return entries;
    }

    function inputDeviceEntries() {
        const sources = root.audioModels.audioSources(root.allNodes).slice();
        sources.sort(function(a, b) {
            const aDefault = root.defaultSource && a.id === root.defaultSource.id;
            const bDefault = root.defaultSource && b.id === root.defaultSource.id;
            if (aDefault !== bDefault) return aDefault ? -1 : 1;
            return root.nodeUtils.nodeName(a).localeCompare(root.nodeUtils.nodeName(b));
        });
        const entries = sources.map(function(source) {
            const entry = root.normalizeDevice(source, true);
            entry.streams = [];
            return entry;
        });
        root.tracer.trace("inputDeviceEntries", function() { return { count: entries.length } });
        return entries;
    }

    function streamEntriesForOutput(outputId) {
        const sink = root.rawNodeById(outputId);
        if (!sink || !root.audioModels) return [];
        const streams = root.audioModels.outputStreams(root.allNodes).filter(function(stream) {
            return root.audioModels.isStreamConnectedTo(stream, sink, root.linkGroups);
        });
        const entries = streams.map(function(stream) {
            const entry = root.normalizeStream(stream);
            entry.targetId = String(sink.id);
            entry.targetName = root.nodeUtils.nodeName(sink, "Output");
            entry.defaultTarget = root.defaultSink && sink.id === root.defaultSink.id;
            return entry;
        });
        root.tracer.trace("streamEntriesForOutput", function() { return { outputId: outputId, count: entries.length } });
        return entries;
    }

    function rawNodeById(id) {
        for (const node of root.allNodes || []) {
            if (node.id === id || String(node.id) === String(id))
                return node;
        }
        root.tracer.trace("rawNodeById.notFound", function() { return { id: id } });
        return null;
    }

    function errorColor() { return Config.styling.critical; }
    function textColor() { return Config.styling.text0; }

    function volumeControl(node) {
        if (!node) return null;
        return {
            kind: "slider",
            target: "pipewire",
            nodeId: node.id,
            from: 0,
            to: 100,
            step: 5,
            value: root.nodeUtils.volumePercent(node)
        };
    }
}
