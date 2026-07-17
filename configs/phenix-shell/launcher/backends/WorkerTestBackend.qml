import qs.services

ScriptWorkerBackendBase {
    id: root

    readonly property var tracer: Logger.scope("backend.workerTest", { category: "backend" })
    readonly property var prof: Profiler.scope("backend.workerTest", { category: "backend" })

    enabled: TestMode.isActive
    category: qsTr("Worker Test")

    backendId: "worker-test"
    name: qsTr("Worker Test")
    helpTitle: qsTr("Worker Test")
    helpDescription: qsTr("Test backend for WorkerScript")
    helpIcon: "applications-engineering"
    priority: 85
    maxResults: 12
    routes: TestMode.isActive ? [
        { prefix: "@worker", priority: 90, combine: "exclusive", afterEmpty: "fallthrough" },
        { priority: 0, combine: "shared", afterEmpty: "stop" }
    ] : []

    function shouldParticipate(rawQuery, directive, query) {
        return TestMode.isActive && !!(directive && directive.active && directive.prefix === "@worker")
    }

    function workerDataset() {
        return [
            { id: "country:de", title: "Germany", subtitle: "Country in Central Europe", keywords: ["germany", "deutschland", "de"] },
            { id: "country:dz", title: "Algeria", subtitle: "Country in North Africa", keywords: ["algeria", "dz"] },
            { id: "country:be", title: "Belgium", subtitle: "Country in Western Europe", keywords: ["belgium", "be"] },
            { id: "country:se", title: "Sweden", subtitle: "Country in Northern Europe", keywords: ["sweden", "swe"] },
            { id: "country:no", title: "Norway", subtitle: "Country in Northern Europe", keywords: ["norway", "nor"] },
            { id: "country:alg", title: "Algeria (alternate)", subtitle: "Alternate name for Algeria", keywords: ["algeria", "alg"] },
            { id: "country:bel", title: "Belgium (alternate)", subtitle: "Alternate name for Belgium", keywords: ["belgium", "bel"] },
            { id: "country:swe", title: "Sweden (alternate)", subtitle: "Alternate name for Sweden", keywords: ["sweden", "swe"] },
            { id: "country:nor", title: "Norway (alternate)", subtitle: "Alternate name for Norway", keywords: ["norway", "nor"] },
            { id: "country:ger", title: "Germany (alternate)", subtitle: "Alternate search alias", keywords: ["germany", "ger"] }
        ]
    }

    function normalizeWorkerItem(item, index) {
        if (!item || !item.id || !item.title)
            return null
        return item
    }

    function syncSearch(queryText) {
        if (!queryText)
            return []

        var text = String(queryText || "").toLowerCase().trim()
        if (!text)
            return []

        var tokens = text.split(/\s+/).filter(function(t) { return t.length > 0 })
        var dataset = root.workerDataset()
        var results = []

        for (var i = 0; i < dataset.length; i += 1) {
            var item = dataset[i]
            var searchText = String(item.title || "").toLowerCase() + " " + String(item.subtitle || "").toLowerCase()
            var kw = item.keywords || []
            for (var k = 0; k < kw.length; k += 1)
                searchText += " " + String(kw[k] || "").toLowerCase()

            var allMatch = true
            for (var t = 0; t < tokens.length; t += 1) {
                if (searchText.indexOf(tokens[t]) < 0) {
                    allMatch = false
                    break
                }
            }
            if (allMatch)
                results.push(item)
        }

        // Score by exact title prefix match first, then keyword match
        results.sort(function(a, b) {
            var aTitle = String(a.title || "").toLowerCase()
            var bTitle = String(b.title || "").toLowerCase()
            var aPrefix = aTitle.indexOf(tokens[0]) === 0 ? 1 : 0
            var bPrefix = bTitle.indexOf(tokens[0]) === 0 ? 1 : 0
            if (bPrefix !== aPrefix)
                return bPrefix - aPrefix
            return aTitle < bTitle ? -1 : aTitle > bTitle ? 1 : 0
        })

        return results.slice(0, root.maxResults)
    }

    function resultNodes(query, context) {
        var searchRaw = (query && query.raw) || (context && context.directive && context.directive.searchRaw) || ""
        var items = root.compositeResults.length > 0
            ? root.compositeResults
            : root.syncSearch(searchRaw)

        return items.map(function(item, index) {
            const payload = item.payload || {}

            return root.nodeDto({
                id: item.id,
                kind: "worker-test-result",
                label: item.title,
                subtitle: item.subtitle || "",
                icon: item.icon || root.helpIcon,
                keywords: item.keywords || [item.title],
                usageCount: Math.max(0, root.maxResults - index),
                lastUsedDaysAgo: 9999,
                actionList: [
                    root.actionDto("select", qsTr("Select"), {
                        actionId: "select",
                        id: payload.id || item.id
                    })
                ],
                meta: item
            })
        })
    }

    function rootNode(query, context) {
        return root.backendRootDto(root.resultNodes(query, context), {
            subtitle: root.compositeQuery
                ? qsTr("Worker results for %1").arg(root.compositeQuery)
                : root.helpDescription
        })
    }

    function activate(result, action) {
        tracer.info("activate", function() { return { resultId: result ? result.id : null, actionId: action ? action.id : null }; })
    }
}
