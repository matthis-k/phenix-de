import QtQuick
import QtQml
import qs.services
import "../logic/"
import "../logic/RoutingTree.js" as RoutingTree

Item {
    readonly property var tracer: Logger.scope("launcher.searchSession", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.searchSession", { category: "launcher" })
    id: root

    property var controller: null
    property string query: ""
    property var backends: []
    property var routingTree: null
    property int maxResults: 12
    property bool loading: false
    property int generation: 0
    property int asyncGeneration: 0
    property int queryRevision: 0
    property var asyncBackendQueries: ({})

    signal resultsClearRequested()
    signal searchStarted(string text, int generation, int revision)
    signal searchCompleted(string text, int generation, int revision, var output)
    signal resultsAvailable(string text, int generation, int revision, var rows, var output)

    Timer {
        id: searchTimer
        interval: 40
        repeat: false
        onTriggered: root.startSearch(root.query, root.generation, true)
    }

    function hasUserQuery(text) {
        return String(text || "").trim().length > 0;
    }

    function cancelPendingAsyncSearches() {
        var states = asyncBackendQueries || {};
        for (var key in states) {
            var state = states[key];
            if (!state || !state.pending || !state.backend)
                continue;
            if (typeof state.backend.cancelAsyncSearch === "function")
                state.backend.cancelAsyncSearch(state.pending, state.generation || 0);
        }
        asyncBackendQueries = {};
        loading = false;
        asyncGeneration += 1;
    }

    function clearSearchState() {
        searchTimer.stop();
        cancelPendingAsyncSearches();
        resultsClearRequested();
        if (controller)
            controller.clearSearchOutputState();
    }

    function updateQuery(text) {
        tracer.trace("updateQuery", function() { return { textLen: (text || "").length, revision: queryRevision + 1 }; });
        searchTimer.stop();
        cancelPendingAsyncSearches();
        queryRevision += 1;
        generation += 1;
        query = text || "";
        if (controller)
            controller.selectedActionIndex = 0;

        if (!hasUserQuery(query)) {
            tracer.debug("updateQuery", function() { return { action: "clear", queryEmpty: true }; });
            resultsClearRequested();
            if (controller)
                controller.clearSearchOutputState();
            return;
        }

        searchTimer.restart();
    }

    function reset() {
        tracer.info("reset", function() { return { wasQuery: query, wasLoading: loading }; });
        query = "";
        generation += 1;
        queryRevision += 1;
        clearSearchState();
    }

    function requestSearch(text, requestGeneration) {
        var requestedText = text || "";
        if (!hasUserQuery(requestedText)) {
            tracer.debug("requestSearch", function() {
                return { action: "ignored-empty-query", generation: requestGeneration };
            });
            clearSearchState();
            return;
        }
        startSearch(requestedText, requestGeneration, false);
    }

    function _startSearch(text, requestGeneration, bumpAsyncGeneration) {
        if (!hasUserQuery(text)) {
            tracer.debug("startSearch", function() {
                return { action: "ignored-empty-query", generation: requestGeneration };
            });
            clearSearchState();
            return;
        }
        if (requestGeneration !== root.generation || text !== root.query) {
            tracer.trace("startSearch", function() {
                return {
                    action: "ignored-stale-query",
                    text: text,
                    generation: requestGeneration,
                    currentGeneration: root.generation
                };
            });
            return;
        }

        tracer.info("startSearch", function() { return { text: text, generation: requestGeneration, bump: bumpAsyncGeneration }; });
        var ag = bumpAsyncGeneration ? (root.asyncGeneration += 1) : root.asyncGeneration;
        var revision = root.queryRevision;
        var backendPorts = BackendContract.adaptAll(root.backends || []);
        triggerAsyncBackends(text, requestGeneration, backendPorts);
        searchStarted(text, requestGeneration, revision);
        Engine.searchAsync(backendPorts, text, stateForSearch(), searchOptions(),
            function() {
                return root.generation === requestGeneration
                    && root.asyncGeneration === ag
                    && root.query === text
                    && root.hasUserQuery(root.query);
            },
            function(output) {
                if (!output)
                    return;
                if (requestGeneration !== root.generation || text !== root.query || !root.hasUserQuery(root.query))
                    return;

                output.queryRevision = revision;
                root.searchCompleted(text, requestGeneration, revision, output);
                root.resultsAvailable(text, requestGeneration, revision, output.rows.slice(0, maxResults), output);
            }
        );
    }

    readonly property var startSearch: prof.fn("startSearch", _startSearch)

    function stateForSearch() {
        return controller ? controller.stateForSearch() : {};
    }

    function searchOptions() {
        return controller ? controller.searchOptions() : {};
    }

    function _triggerAsyncBackends(text, currentGeneration, providedPorts) {
        if (!hasUserQuery(text)) {
            tracer.trace("triggerAsyncBackends", function() {
                return { action: "ignored-empty-query", generation: currentGeneration };
            });
            return;
        }

        tracer.trace("triggerAsyncBackends", function() { return { text: text, generation: currentGeneration }; });
        var backendPorts = providedPorts || BackendContract.adaptAll(root.backends || []);
        var route = RoutingTree.routeQuery(root.routingTree, text);
        var directive = route && route.endpoints && route.endpoints.length > 0
            ? Engine.buildDirectiveFromRoute(text, route, backendPorts)
            : Tokenize.parseDirective(text, backendPorts);
        var parsedQuery = Tokenize.tokenize(directive.searchRaw || "");

        for (let i = 0; i < backendPorts.length; i += 1) {
            let backend = backendPorts[i];
            if (!backend.enabled || !backend.asyncCapable)
                continue;
            if (!backend.shouldParticipate(text, directive, parsedQuery))
                continue;
            if (directive.active && directive.backendIds.indexOf(backend.backendId) < 0)
                continue;

            let key = backend.backendId;
            let state = asyncBackendQueries[key] || {};
            if (state.ready === text || state.pending === text)
                continue;

            beginAsyncBackendSearch(backend, key, text, currentGeneration);

            backend.searchAsync(text, function(newResults) {
                receiveAsyncBackendResults(backend, key, text, currentGeneration, newResults || []);
            });
        }
    }

    readonly property var triggerAsyncBackends: prof.fn("triggerAsyncBackends", _triggerAsyncBackends)

    function beginAsyncBackendSearch(backend, key, text, requestGeneration) {
        tracer.debug("beginAsyncBackendSearch", function() { return { key: key, text: text, backend: backend.backendId }; });
        var state = asyncBackendQueries[key] || {};
        state.pending = text;
        state.ready = "";
        state.backend = backend;
        state.generation = requestGeneration;
        asyncBackendQueries[key] = state;
        backend.beginAsyncSearch(text);
        refreshLoading();
    }

    function receiveAsyncBackendResults(backend, key, text, requestGeneration, update) {
        if (requestGeneration !== root.generation || text !== root.query || !hasUserQuery(root.query)) {
            tracer.debug("receiveAsyncBackendResults", function() { return { key: key, text: text, stale: true, requestGeneration: requestGeneration, currentGen: root.generation }; });
            return;
        }

        tracer.info("receiveAsyncBackendResults", function() { return { key: key, text: text, generation: requestGeneration, updateCount: (update || []).length }; });
        var state = asyncBackendQueries[key] || {};
        state.pending = "";
        state.ready = text;
        state.backend = backend;
        state.generation = requestGeneration;
        asyncBackendQueries[key] = state;
        backend.finishAsyncSearch(text, update || []);
        refreshLoading();
        root.asyncGeneration += 1;
        requestSearch(text, requestGeneration);
    }

    function refreshLoading() {
        loading = hasPendingAsyncBackends();
    }

    function hasPendingAsyncBackends() {
        for (var key in asyncBackendQueries || {}) {
            if (asyncBackendQueries[key] && asyncBackendQueries[key].pending)
                return true;
        }
        return false;
    }
}
