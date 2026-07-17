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
    property bool emptyQueryResultsEnabled: true

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

    Connections {
        target: LauncherUsage

        function onRevisionChanged() {
            if (root.emptyQueryResultsEnabled && root.query.trim().length === 0)
                root.refreshEmptyQuery();
        }
    }

    function refreshEmptyQuery() {
        if (!root.emptyQueryResultsEnabled)
            return;
        queryRevision += 1;
        generation += 1;
        query = "";
        searchTimer.restart();
    }

    function updateQuery(text) {
        tracer.trace("updateQuery", function() { return { textLen: (text || "").length, revision: queryRevision + 1 }; });
        queryRevision += 1;
        generation += 1;
        query = text || "";
        if (controller)
            controller.selectedActionIndex = 0;

        if (!query || query.trim().length === 0) {
            tracer.debug("updateQuery", function() { return { action: "empty-search", queryEmpty: true }; });
            resultsClearRequested();
            if (controller)
                controller.clearSearchOutputState();
            searchTimer.stop();
            if (emptyQueryResultsEnabled)
                searchTimer.restart();
            return;
        }

        searchTimer.restart();
    }

    function reset() {
        tracer.info("reset", function() { return { wasQuery: query, wasLoading: loading }; });
        searchTimer.stop();
        query = "";
        resultsClearRequested();
        loading = false;
        generation += 1;
        queryRevision += 1;
        if (controller)
            controller.clearSearchOutputState();
        asyncBackendQueries = {};
        asyncGeneration += 1;
        if (emptyQueryResultsEnabled)
            searchTimer.restart();
    }

    function requestSearch(text, requestGeneration) {
        startSearch(text || "", requestGeneration, false);
    }

    function _startSearch(text, requestGeneration, bumpAsyncGeneration) {
        tracer.info("startSearch", function() { return { text: text, generation: requestGeneration, bump: bumpAsyncGeneration }; });
        var ag = bumpAsyncGeneration ? (root.asyncGeneration += 1) : root.asyncGeneration;
        var revision = root.queryRevision;
        triggerAsyncBackends(text, requestGeneration);
        searchStarted(text, requestGeneration, revision);
        Engine.searchAsync(backends || [], text || "", stateForSearch(), searchOptions(),
            function() { return root.generation === requestGeneration && root.asyncGeneration === ag; },
            function(output) {
                if (!output)
                    return;
                if (requestGeneration !== root.generation || text !== root.query)
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

    function _triggerAsyncBackends(text, currentGeneration) {
        tracer.trace("triggerAsyncBackends", function() { return { text: text, generation: currentGeneration }; });
        var route = RoutingTree.routeQuery(root.routingTree, text || "");
        var directive = route && route.endpoints && route.endpoints.length > 0
            ? Engine.buildDirectiveFromRoute(text || "", route, backends || [])
            : Tokenize.parseDirective(text || "", backends || []);
        var parsedQuery = Tokenize.tokenize(directive.searchRaw || "");

        for (let i = 0; i < (backends || []).length; i += 1) {
            let backend = backends[i];
            if (!backend || !backend.enabled || typeof backend.resultsAsync !== "function")
                continue;
            if (typeof backend.shouldParticipate === "function" && !backend.shouldParticipate(text || "", directive, parsedQuery))
                continue;
            if (directive.active && directive.backendIds.indexOf(backend.backendId) < 0)
                continue;

            let key = backend.backendId || String(i);
            let state = asyncBackendQueries[key] || {};
            if (state.ready === text || state.pending === text)
                continue;

            beginAsyncBackendSearch(backend, key, text);

            backend.resultsAsync(text, function(newResults) {
                receiveAsyncBackendResults(backend, key, text, currentGeneration, newResults || []);
            });
        }
    }

    readonly property var triggerAsyncBackends: prof.fn("triggerAsyncBackends", _triggerAsyncBackends)

    function beginAsyncBackendSearch(backend, key, text) {
        tracer.debug("beginAsyncBackendSearch", function() { return { key: key, text: text, backend: backend.backendId }; });
        var state = asyncBackendQueries[key] || {};
        state.pending = text;
        state.ready = "";
        asyncBackendQueries[key] = state;
        backend.pendingCompositeQuery = text;
        backend.compositeQuery = "";
        backend.applyStreamUpdate({ op: "clear" });
        refreshLoading();
    }

    function receiveAsyncBackendResults(backend, key, text, requestGeneration, update) {
        if (requestGeneration !== root.generation || text !== root.query) {
            tracer.debug("receiveAsyncBackendResults", function() { return { key: key, text: text, stale: true, requestGeneration: requestGeneration, currentGen: root.generation }; });
            return;
        }

        tracer.info("receiveAsyncBackendResults", function() { return { key: key, text: text, generation: requestGeneration, updateCount: (update || []).length }; });
        var state = asyncBackendQueries[key] || {};
        state.pending = "";
        state.ready = text;
        asyncBackendQueries[key] = state;
        backend.pendingCompositeQuery = "";
        backend.compositeQuery = text;
        backend.applyStreamUpdate(update || []);
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

    Component.onCompleted: {
        if (root.emptyQueryResultsEnabled)
            root.refreshEmptyQuery();
    }
}
