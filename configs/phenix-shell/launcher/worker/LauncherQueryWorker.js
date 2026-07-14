/*
 * Generic launcher query worker.
 *
 * Runs inside QtQml.WorkerScript, off the GUI thread.
 * Keep this file plain JS. Do not access QML objects here.
 */

var datasetsByBackend = {}
var datasetRevisionByBackend = {}
var latestRequestByBackend = {}
var cancelledRequestIds = {}
var queryCache = {}
var queryCacheOrder = []
var maxCacheEntries = 256

function lower(value) {
    return String(value || "").toLowerCase()
}

function normalizeQuery(query) {
    return lower(query).trim().replace(/\s+/g, " ")
}

function cacheKey(backend, datasetRevision, query, options) {
    var maxResults = options && options.maxResults ? options.maxResults : 12
    var mode = options && options.mode ? options.mode : "generic"
    return backend + "\u0000" + datasetRevision + "\u0000" + mode + "\u0000" + normalizeQuery(query) + "\u0000" + maxResults
}

function rememberCache(key, items) {
    if (!queryCache.hasOwnProperty(key))
        queryCacheOrder.push(key)

    queryCache[key] = items

    while (queryCacheOrder.length > maxCacheEntries) {
        var oldKey = queryCacheOrder.shift()
        delete queryCache[oldKey]
    }
}

function sendResult(request, items, cacheHit) {
    WorkerScript.sendMessage({
        type: "result",
        id: request.id,
        generation: request.generation,
        backend: request.backend,
        datasetRevision: request.datasetRevision,
        query: request.query,
        items: items,
        cacheHit: !!cacheHit
    })
}

function sendLog(message) {
    WorkerScript.sendMessage({
        type: "log",
        message: String(message || "")
    })
}

function sendError(request, message) {
    WorkerScript.sendMessage({
        type: "error",
        id: request && request.id ? request.id : 0,
        backend: request && request.backend ? request.backend : "",
        message: String(message || "")
    })
}

function isCurrent(request) {
    return latestRequestByBackend[request.backend] === request.id && !cancelledRequestIds[request.id]
}

WorkerScript.onMessage = function(message) {
    if (!message || !message.type)
        return

    if (message.type === "dataset") {
        handleDataset(message)
        return
    }

    if (message.type === "cancel") {
        cancelledRequestIds[message.id] = true
        return
    }

    if (message.type === "reset") {
        resetBackend(message.backend)
        return
    }

    if (message.type === "query") {
        handleQuery(message)
        return
    }
}

function handleDataset(message) {
    var backend = message.backend || ""
    if (!backend)
        return

    datasetsByBackend[backend] = message.items || []
    datasetRevisionByBackend[backend] = message.revision || 0

    var prefix = backend + "\u0000"
    var keptOrder = []

    for (var i = 0; i < queryCacheOrder.length; i += 1) {
        var key = queryCacheOrder[i]
        if (key.indexOf(prefix) === 0) {
            delete queryCache[key]
        } else {
            keptOrder.push(key)
        }
    }

    queryCacheOrder = keptOrder
}

function resetBackend(backend) {
    if (!backend)
        return

    var prefix = backend + "\u0000"
    var keptOrder = []

    for (var i = 0; i < queryCacheOrder.length; i += 1) {
        var key = queryCacheOrder[i]
        if (key.indexOf(prefix) === 0) {
            delete queryCache[key]
        } else {
            keptOrder.push(key)
        }
    }

    queryCacheOrder = keptOrder
}

function handleQuery(request) {
    try {
        var backend = request.backend || ""
        if (!backend)
            return

        latestRequestByBackend[backend] = request.id

        var currentRevision = datasetRevisionByBackend[backend] || 0
        if (request.datasetRevision !== currentRevision) {
            sendError(request, "dataset revision mismatch")
            return
        }

        var options = request.options || {}
        var key = cacheKey(backend, request.datasetRevision, request.query, options)

        if (queryCache.hasOwnProperty(key)) {
            if (isCurrent(request))
                sendResult(request, queryCache[key], true)
            return
        }

        var dataset = datasetsByBackend[backend] || []
        var items = runGenericQuery(dataset, request.query || "", options, function() {
            return isCurrent(request)
        })

        rememberCache(key, items)

        if (!isCurrent(request))
            return

        sendResult(request, items, false)
    } catch (e) {
        sendError(request, e && e.message ? e.message : String(e))
    }
}

function tokenize(query) {
    var normalized = normalizeQuery(query)
    if (!normalized)
        return []

    return normalized.split(" ").filter(function(token) {
        return token.length > 0
    })
}

function candidateText(item) {
    var parts = []

    if (item.title)
        parts.push(item.title)
    if (item.subtitle)
        parts.push(item.subtitle)
    if (item.label)
        parts.push(item.label)
    if (item.path)
        parts.push(item.path)

    var keywords = item.keywords || []
    for (var i = 0; i < keywords.length; i += 1)
        parts.push(keywords[i])

    return lower(parts.join(" "))
}

function scoreCandidate(item, tokens) {
    if (!tokens || tokens.length === 0)
        return 0

    var title = lower(item.title || item.label || "")
    var text = item._searchText || candidateText(item)

    var score = 0

    for (var i = 0; i < tokens.length; i += 1) {
        var token = tokens[i]

        if (title === token) {
            score += 10
            continue
        }

        if (title.indexOf(token) === 0) {
            score += 7
            continue
        }

        if (text.indexOf(token) >= 0) {
            score += 3
            continue
        }

        if (acronymMatches(title, token)) {
            score += 2
            continue
        }

        return 0
    }

    if (item.usageCount)
        score += Math.min(2, item.usageCount * 0.1)

    if (item.priority)
        score += item.priority * 0.01

    return score
}

function acronymMatches(text, token) {
    if (!text || !token)
        return false

    var words = text.split(/[^a-z0-9]+/).filter(function(part) {
        return part.length > 0
    })

    var acronym = ""
    for (var i = 0; i < words.length; i += 1)
        acronym += words[i][0]

    return acronym.indexOf(token) === 0
}

function runGenericQuery(dataset, query, options, isCurrent) {
    var tokens = tokenize(query)
    var maxResults = options && options.maxResults ? options.maxResults : 12
    var scored = []

    for (var i = 0; i < dataset.length; i += 1) {
        if ((i % 128) === 0 && !isCurrent())
            break

        var item = dataset[i]
        if (!item)
            continue

        if (!item._searchText)
            item._searchText = candidateText(item)

        var score = scoreCandidate(item, tokens)
        if (score <= 0)
            continue

        var out = copyResultItem(item)
        out.score = score
        scored.push(out)
    }

    scored.sort(function(a, b) {
        if (b.score !== a.score)
            return b.score - a.score

        var at = lower(a.title || a.label || "")
        var bt = lower(b.title || b.label || "")
        return at < bt ? -1 : at > bt ? 1 : 0
    })

    return scored.slice(0, maxResults)
}

function copyResultItem(item) {
    return {
        id: item.id || item.key || item.title || item.label || "",
        title: item.title || item.label || "",
        subtitle: item.subtitle || "",
        icon: item.icon || "",
        keywords: item.keywords || [],
        payload: item.payload || {},
        path: item.path || "",
        kind: item.kind || ""
    }
}
