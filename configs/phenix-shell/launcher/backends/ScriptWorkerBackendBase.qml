import QtQml
import QtQml.WorkerScript
import qs.services

StreamingBackendBase {
    readonly property var tracer: Logger.scope("launcher.scriptWorkerBackend", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.scriptWorkerBackend", { category: "launcher" })
    id: root

    property url workerSource: "../worker/LauncherQueryWorker.js"

    property int nextRequestId: 0
    property int activeRequestId: 0
    property string pendingQuery: ""
    property int pendingGeneration: 0
    property var callbacksById: ({})

    property bool datasetDirty: true
    property int datasetRevision: 0
    property int workerDatasetRevision: 0

    property int staleWorkerResultsDropped: 0
    property int workerCacheHits: 0
    property int workerCacheMisses: 0
    property real lastWorkerRoundTripMs: 0
    property var requestStartedAtMsById: ({})

    property WorkerScript worker: WorkerScript {
        source: root.workerSource

        onMessage: function(message) {
            root.handleWorkerMessage(message)
        }
    }

    function workerBackendMode() {
        return "generic"
    }

    function workerDataset() {
        return []
    }

    function workerOptions(queryText) {
        return {
            maxResults: root.maxResults,
            mode: root.workerBackendMode()
        }
    }

    function normalizeWorkerItem(item, index) {
        return item
    }

    function markDatasetDirty() {
        root.datasetDirty = true
        root.datasetRevision += 1
    }

    function ensureWorkerDataset() {
        if (!root.datasetDirty && root.workerDatasetRevision === root.datasetRevision)
            return

        const dataset = root.workerDataset() || []

        worker.sendMessage({
            type: "dataset",
            backend: root.backendId,
            revision: root.datasetRevision,
            mode: root.workerBackendMode(),
            items: dataset
        })

        root.workerDatasetRevision = root.datasetRevision
        root.datasetDirty = false
    }

    function cancelSearch(query, generation) {
        tracer.trace("cancelSearch", function() { return { query: query, generation: generation }; })
        if (root.activeRequestId > 0) {
            worker.sendMessage({
                type: "cancel",
                id: root.activeRequestId,
                backend: root.backendId
            })

            if (root.callbacksById[root.activeRequestId])
                delete root.callbacksById[root.activeRequestId]
        }

        root.activeRequestId = 0
        root.pendingQuery = ""
        root.pendingGeneration = 0
        root.activeQuery = ""
        root.activeGeneration = 0
    }

    function _resultsAsync(query, callback) {
        const text = root.queryText(query)

        if (!text) {
            if (callback)
                callback([])
            return
        }

        ensureWorkerDataset()

        if (root.activeRequestId > 0)
            root.cancelSearch(root.pendingQuery, root.pendingGeneration)

        const id = ++root.nextRequestId
        const generation = root.controller ? root.controller.generation : 0

        root.beginSearch(text, generation)

        root.activeRequestId = id
        root.pendingQuery = text
        root.pendingGeneration = generation
        root.callbacksById[id] = callback
        root.requestStartedAtMsById[id] = Date.now()

        worker.sendMessage({
            type: "query",
            id: id,
            generation: generation,
            backend: root.backendId,
            datasetRevision: root.datasetRevision,
            query: text,
            options: root.workerOptions(text)
        })
    }

    readonly property var resultsAsync: prof.fn("resultsAsync", _resultsAsync)

    function resetWorkerCache() {
        worker.sendMessage({
            type: "reset",
            backend: root.backendId
        })
    }

    function isCurrentWorkerResult(msg) {
        if (!msg)
            return false

        if (msg.backend !== root.backendId)
            return false

        if (msg.id !== root.activeRequestId)
            return false

        if (msg.query !== root.pendingQuery)
            return false

        if (msg.datasetRevision !== root.datasetRevision)
            return false

        if (root.controller && msg.generation !== root.controller.generation)
            return false

        return true
    }

    function handleWorkerMessage(msg) {
        if (!msg || !msg.type)
            return

        if (msg.type === "log") {
            if (root.controller && root.controller.debugEnabled)
                console.log("launcher worker:", msg.message || "")
            return
        }

        if (msg.type === "error") {
            if (root.controller && root.controller.debugEnabled)
                console.warn("launcher worker error:", msg.message || "")
            return
        }

        if (msg.type !== "result")
            return

        if (!isCurrentWorkerResult(msg)) {
            root.staleWorkerResultsDropped += 1
            return
        }

        if (msg.cacheHit)
            root.workerCacheHits += 1
        else
            root.workerCacheMisses += 1

        if (root.requestStartedAtMsById[msg.id]) {
            root.lastWorkerRoundTripMs = Date.now() - root.requestStartedAtMsById[msg.id]
            delete root.requestStartedAtMsById[msg.id]
        }

        const cb = root.callbacksById[msg.id]
        delete root.callbacksById[msg.id]

        const queryText = root.pendingQuery
        const generation = root.pendingGeneration

        root.activeRequestId = 0
        root.pendingQuery = ""
        root.pendingGeneration = 0

        root.finishSearch(queryText, generation)

        const normalizedItems = (msg.items || []).map(function(item, index) {
            return root.normalizeWorkerItem(item, index)
        }).filter(Boolean)

        if (cb) {
            cb({
                op: "reset",
                items: normalizedItems
            })
        }
    }
}
