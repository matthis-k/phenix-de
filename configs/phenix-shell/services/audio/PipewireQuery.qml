import QtQml
import Quickshell.Services.Pipewire
import qs.services

QtObject {
    id: root
    readonly property var tracer: Logger.scope("audio.pipewireQuery", { category: "audio" })
    readonly property var prof: Profiler.scope("audio.pipewireQuery", { category: "audio" })

    function rawNodeById(id) {
        root.tracer.trace("rawNodeById", function() { return { id: id } });
        for (const node of Pipewire.nodes.values || []) {
            if (node.id === id || String(node.id) === String(id))
                return node;
        }
        return null;
    }
}
