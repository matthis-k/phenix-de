import QtQml
import Quickshell.Services.Pipewire
import qs.services

QtObject {
    id: root
    readonly property var tracer: Logger.scope("audio.models", { category: "audio" })
    readonly property var prof: Profiler.scope("audio.models", { category: "audio" })

    function collectNodes(pipewireNodes) {
        const items = [];
        for (const node of pipewireNodes || [])
            items.push(node);
        return items;
    }

    function audioSinks(nodes) {
        root.tracer.trace("audioSinks", function() { return { count: (nodes || []).length } });
        return (nodes || []).filter(node => (node.type & PwNodeType.AudioSink) === PwNodeType.AudioSink);
    }

    function audioSources(nodes) {
        root.tracer.trace("audioSources", function() { return { count: (nodes || []).length } });
        return (nodes || []).filter(node => (node.type & PwNodeType.AudioSource) === PwNodeType.AudioSource);
    }

    function outputStreams(nodes) {
        root.tracer.trace("outputStreams", function() { return { count: (nodes || []).length } });
        return (nodes || []).filter(node => (node.type & PwNodeType.AudioOutStream) === PwNodeType.AudioOutStream);
    }

    function inputStreams(nodes) {
        root.tracer.trace("inputStreams", function() { return { count: (nodes || []).length } });
        return (nodes || []).filter(node => (node.type & PwNodeType.AudioInStream) === PwNodeType.AudioInStream);
    }

    function isStreamConnectedTo(stream, targetNode, linkGroups) {
        if (!stream || !targetNode) return false;
        root.tracer.trace("isStreamConnectedTo", function() { return { streamId: stream.id, targetId: targetNode.id } });
        for (const link of linkGroups || []) {
            if (link.source && link.target && link.source.id === stream.id && link.target.id === targetNode.id)
                return true;
        }
        return false;
    }

}
