import Quickshell.Io
import qs.services

StreamingBackendBase {
    id: root

    readonly property var tracer: Logger.scope("backend.process", { category: "backend" })
    readonly property var prof: Profiler.scope("backend.process", { category: "backend" })

    property var pendingQuery: ""
    property var pendingCallback: null

    function cancelSearch(query, generation) {
        tracer.trace("cancelSearch", function() { return { query: query, generation: generation }; });
        root.pendingCallback = null;
        root.pendingQuery = "";
        searchProcess.running = false;
        root.activeQuery = "";
        root.activeGeneration = 0;
    }

    function buildCommand(queryText) {
        return [];
    }

    function parseOutput(text, queryText) {
        return [];
    }

    function applySearchOutput(text) {
        tracer.info("applySearchOutput", function() { return { textLen: (text || "").length, hasCallback: !!root.pendingCallback }; });
        const callback = root.pendingCallback;
        if (!callback)
            return;
        const results = root.parseOutput(text, root.pendingQuery);
        const query = root.pendingQuery;
        root.pendingCallback = null;
        root.pendingQuery = "";
        root.finishSearch(query, root.activeGeneration);
        callback({ op: "reset", items: results });
    }

    function resultsAsync(query, callback) {
        tracer.trace("resultsAsync", function() { return { query: query, hasCallback: !!callback }; });
        const text = root.queryText(query);
        if (!text) {
            if (callback)
                callback([]);
            return;
        }

        if (root.pendingQuery || root.pendingCallback)
            root.cancelSearch(root.pendingQuery, root.activeGeneration);
        root.beginSearch(text, 0);
        root.pendingQuery = text;
        root.pendingCallback = callback;

        const command = root.buildCommand(text);
        if (!command || command.length === 0) {
            if (callback)
                callback([]);
            root.pendingCallback = null;
            root.pendingQuery = "";
            return;
        }

        searchProcess.exec({ command: command });
    }

    property Process searchProcess: Process {
        id: searchProcess
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.applySearchOutput(text)
        }
        function onExited(exitCode) {
            if (exitCode !== 0)
                root.applySearchOutput("");
        }
    }
}
