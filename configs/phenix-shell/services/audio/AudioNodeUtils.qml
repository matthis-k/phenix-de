import QtQml
import qs.services

QtObject {
    id: root

    readonly property var tracer: Logger.scope("audio.nodeUtils", { category: "audio" })
    readonly property var prof: Profiler.scope("audio.nodeUtils", { category: "audio" })

    function nodeName(node, fallback) {
        if (!node) return fallback || "";
        return node.nickname || node.description || node.name || fallback || "";
    }

    function volumePercent(node) {
        if (!node || !node.audio) return 0;
        return Math.round((node.audio.volume || 0) * 100);
    }

    function setVolume(node, percent) {
        if (!node || !node.audio) {
            root.tracer.warn("setVolume.noAudio", function() { return { nodeId: node?.id } });
            return false;
        }
        node.audio.volume = Math.max(0, Math.min(1, percent / 100));
        root.tracer.trace("volumeSet", function() { return { nodeId: node.id, percent: percent } });
        return true;
    }

    function adjustVolume(node, delta) {
        if (!node || !node.audio) {
            root.tracer.warn("adjustVolume.noAudio", function() { return { nodeId: node?.id } });
            return;
        }
        const current = root.volumePercent(node);
        root.setVolume(node, current + delta);
        root.tracer.trace("volumeAdjusted", function() { return { nodeId: node.id, delta: delta, newPercent: current + delta } });
    }

    function isMuted(node) {
        return !!(node && node.audio && node.audio.muted);
    }

    function setMuted(node, value) {
        if (!node || !node.audio) {
            root.tracer.warn("setMuted.noAudio", function() { return { nodeId: node?.id } });
            return false;
        }
        node.audio.muted = value;
        root.tracer.trace("muteSet", function() { return { nodeId: node.id, muted: value } });
        return true;
    }

    function toggleMute(node) {
        if (!node || !node.audio) {
            root.tracer.warn("toggleMute.noAudio", function() { return { nodeId: node?.id } });
            return false;
        }
        node.audio.muted = !node.audio.muted;
        root.tracer.trace("muteToggled", function() { return { nodeId: node.id, muted: node.audio.muted } });
        return true;
    }

    function volumeIconName(node, inputNode) {
        if (!node || !node.audio)
            return inputNode ? "audio-input-microphone-symbolic" : "audio-volume-muted-symbolic";
        if (node.audio.muted)
            return inputNode ? "microphone-sensitivity-muted-symbolic" : "audio-volume-muted-symbolic";
        const pct = root.volumePercent(node);
        if (inputNode)
            return pct <= 0 ? "microphone-sensitivity-muted-symbolic" : "audio-input-microphone-symbolic";
        if (pct <= 0)
            return "audio-volume-muted-symbolic";
        if (pct < 34)
            return "audio-volume-low-symbolic";
        if (pct < 67)
            return "audio-volume-medium-symbolic";
        return "audio-volume-high-symbolic";
    }
}
