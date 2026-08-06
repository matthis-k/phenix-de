pragma Singleton
import QtQml
import Quickshell
import qs.services

// Parses duck-typed backend QObjects into the canonical capability surface used
// by launcher search. Optional source methods are handled only at this boundary.
Singleton {
    readonly property var tracer: Logger.scope("launcher.backendContract", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.backendContract", { category: "launcher" })

    function adaptAll(backends) {
        var result = [];
        for (var i = 0; i < (backends || []).length; i += 1) {
            var port = adapt(backends[i], i);
            if (port)
                result.push(port);
        }
        return result;
    }

    function adapt(source, index) {
        if (!source)
            return null;

        var id = String(source.backendId || source.id || ("backend-" + index));
        if (typeof source.rootNode !== "function")
            throw new Error("Launcher backend '" + id + "' must implement rootNode(query, context)");

        var hasAsyncSearch = typeof source.resultsAsync === "function";
        var hasStreamUpdates = typeof source.applyStreamUpdate === "function";
        var hasCancellation = typeof source.cancelSearch === "function";

        return {
            source: source,
            backendId: id,
            name: String(source.name || id),
            helpTitle: String(source.helpTitle || source.name || id),
            helpPrefixes: (source.helpPrefixes || []).slice(),
            enabled: source.enabled !== false,
            priority: Number(source.priority || 0),
            asyncCapable: hasAsyncSearch && hasStreamUpdates,

            shouldParticipate: function(rawQuery, directive, parsedQuery) {
                return typeof source.shouldParticipate === "function"
                    ? source.shouldParticipate(rawQuery, directive, parsedQuery)
                    : true;
            },

            rootNode: function(query, context) {
                return source.rootNode(query, context);
            },

            searchAsync: function(query, callback) {
                if (!hasAsyncSearch)
                    return false;
                source.resultsAsync(query, callback);
                return true;
            },

            beginAsyncSearch: function(query) {
                if (!hasStreamUpdates)
                    return false;
                source.pendingCompositeQuery = query;
                source.compositeQuery = "";
                source.applyStreamUpdate({ op: "clear" });
                return true;
            },

            finishAsyncSearch: function(query, update) {
                if (!hasStreamUpdates)
                    return false;
                source.pendingCompositeQuery = "";
                source.compositeQuery = query;
                source.applyStreamUpdate(update || []);
                return true;
            },

            cancelAsyncSearch: function(query, generation) {
                var cancelled = false;
                if (hasCancellation) {
                    source.cancelSearch(query || "", generation || 0);
                    cancelled = true;
                }
                if (hasStreamUpdates) {
                    source.pendingCompositeQuery = "";
                    source.compositeQuery = "";
                    source.applyStreamUpdate({ op: "clear" });
                    cancelled = true;
                }
                return cancelled;
            },

            activate: function(result, action) {
                if (typeof source.activate !== "function")
                    return false;
                source.activate(result, action);
                return true;
            }
        };
    }
}
