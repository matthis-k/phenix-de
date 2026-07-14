import QtQml
import qs.services

QtObject {
    readonly property var tracer: Logger.scope("audio.presentation", { category: "audio" })
    readonly property var prof: Profiler.scope("audio.presentation", { category: "audio" })

    function streamName(stream) {
        if (!stream) return "Unknown";
        const props = stream.properties || {};
        const mediaName = props["media.name"];
        const appName = props["application.name"];
        if (mediaName && appName) return `${mediaName} - ${appName}`;
        if (mediaName) return mediaName;
        if (appName) return appName;
        return stream.description || stream.name || "Unknown stream";
    }

    function streamIconName(stream) {
        if (!stream) return "audio-x-generic-symbolic";
        const props = stream.properties || {};
        return props["application.icon-name"] || "audio-x-generic-symbolic";
    }

    function humanName(node) {
        return node ? (node.description || node.name || "") : "";
    }

    function volumePercent(node) {
        return node ? Math.round((node.audio?.volume || 0) * 100) : 0;
    }

    function volumeIconName(node, isInput) {
        if (!node) return "audio-volume-high-symbolic";
        if (node.audio?.muted) return "audio-volume-muted-symbolic";
        const vol = node.audio?.volume || 0;
        if (vol <= 0) return "audio-volume-muted-symbolic";
        if (vol < 0.34) return isInput ? "audio-input-microphone-low-symbolic" : "audio-volume-low-symbolic";
        if (vol < 0.67) return isInput ? "audio-input-microphone-medium-symbolic" : "audio-volume-medium-symbolic";
        return isInput ? "audio-input-microphone-high-symbolic" : "audio-volume-high-symbolic";
    }
}
