import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.services

QtObject {
    id: root

    readonly property var tracer: Logger.scope("audio.commands", { category: "audio" })
    readonly property var prof: Profiler.scope("audio.commands", { category: "audio" })

    signal moveStreamFinished(bool success, string message)

    function setDefaultSink(sink) {
        if (!sink) {
            root.tracer.warn("setDefaultSink.nullSink");
            return false;
        }
        Pipewire.preferredDefaultAudioSink = sink;
        root.tracer.info("setDefaultSink", function() { return { sinkId: sink.id } });
        return true;
    }

    function setDefaultSource(source) {
        if (!source) {
            root.tracer.warn("setDefaultSource.nullSource");
            return false;
        }
        Pipewire.preferredDefaultAudioSource = source;
        root.tracer.info("setDefaultSource", function() { return { sourceId: source.id } });
        return true;
    }

    function toggleMute(node) {
        if (!node?.audio) {
            root.tracer.warn("toggleMute.noAudio", function() { return { nodeId: node?.id } });
            return false;
        }
        node.audio.muted = !node.audio.muted;
        root.tracer.trace("muteToggled", function() { return { nodeId: node.id, muted: node.audio.muted } });
        return true;
    }

    function setVolume(node, value) {
        if (!node?.audio) {
            root.tracer.warn("setVolume.noAudio", function() { return { nodeId: node?.id } });
            return false;
        }
        node.audio.volume = Math.max(0, Math.min(1, value / 100));
        root.tracer.trace("volumeSet", function() { return { nodeId: node.id, value: value } });
        return true;
    }

    function moveStreamTo(stream, sink) {
        if (!stream || !sink) {
            root.tracer.warn("moveStreamTo.invalidArgs", function() { return { hasStream: !!stream, hasSink: !!sink } });
            return false;
        }
        root.tracer.info("moveStreamTo.executing", function() { return { streamId: stream.id, sinkId: sink.id } });
        const proc = Qt.createQmlObject("import Quickshell.Io; Process {}", root);
        proc.command = ["pw-cli", "move-stream", String(stream.id), String(sink.id)];
        proc.running = true;
        proc.exited.connect(function(exitCode) {
            root.moveStreamFinished(exitCode === 0, exitCode === 0 ? "" : `move stream failed (${exitCode})`);
            proc.destroy();
        });
        return true;
    }
}
