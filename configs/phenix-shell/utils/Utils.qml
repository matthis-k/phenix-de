pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.services

Singleton {
    readonly property var tracer: Logger.scope("utils", { category: "service" })
    readonly property var prof: Profiler.scope("utils", { category: "service" })
    id: root

    function nodeName(node, fallback) {
        tracer.trace("nodeName", function() { return { hasNode: !!node }; });
        if (!node) return fallback;
        return node.nickname || node.description || node.name || fallback;
    }

    function volumePercent(node) {
        return node && node.audio ? Math.round((node.audio.volume || 0) * 100) : 0;
    }

    function setVolume(node, percent) {
        tracer.debug("setVolume", function() { return { percent: percent }; });
        if (!node || !node.audio) return;
        node.audio.volume = Math.max(0, Math.min(1, percent / 100));
    }

    function toggleMute(node) {
        tracer.debug("toggleMute", function() { return { wasMuted: !!(node?.audio?.muted) }; });
        if (!node || !node.audio) return;
        node.audio.muted = !node.audio.muted;
    }

    function isMuted(node) {
        return !!(node && node.audio && node.audio.muted);
    }

    function volumeIconName(node, inputNode) {
        if (!node || !node.audio)
            return inputNode ? "audio-input-microphone-symbolic" : "audio-volume-muted-symbolic";
        if (node.audio.muted)
            return inputNode ? "microphone-sensitivity-muted-symbolic" : "audio-volume-muted-symbolic";
        const vol = node.audio.volume || 0;
        if (inputNode)
            return vol <= 0.001 ? "microphone-sensitivity-muted-symbolic" : "audio-input-microphone-symbolic";
        if (vol <= 0.001)
            return "audio-volume-muted-symbolic";
        if (vol < 0.34)
            return "audio-volume-low-symbolic";
        if (vol < 0.67)
            return "audio-volume-medium-symbolic";
        return "audio-volume-high-symbolic";
    }

    function batteryColor(percentage) {
        if (percentage <= 10) return Config.styling.critical;
        if (percentage <= 20) return Config.colors.yellow;
        if (percentage <= 60) return Config.styling.text0;
        return Config.styling.good;
    }
}
