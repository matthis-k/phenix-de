pragma Singleton
import QtQml

QtObject {
    function collect(options) {
        options = options || {}

        const snapshot = ProfilerStore.snapshot()

        const stats = buildStats(snapshot)

        const result = {
            ok: true,
            mode: snapshot.mode,
            eventCount: snapshot.eventCount,
            droppedEventCount: snapshot.droppedEventCount,
            stats: stats
        }

        if (options.includeEvents)
            result.events = snapshot.events

        if (options.includeFlamegraph)
            result.flamegraph = buildFlamegraph(snapshot, options.groupBy || "stack")

        return result
    }

    function textReport(options) {
        options = options || {}

        const data = collect({})
        const top = options.top || 30
        const sort = options.sort || "total"

        const rows = data.stats.slice()
        rows.sort((a, b) => {
            switch (sort) {
            case "max": return b.maxMs - a.maxMs
            case "mean": return b.meanMs - a.meanMs
            case "count": return b.count - a.count
            case "slow": return b.slowCount - a.slowCount
            case "total":
            default:
                return b.totalMs - a.totalMs
            }
        })

        let out = ""
        out += "Profiler report\n"
        out += "mode: " + data.mode + "\n"
        out += "events: " + data.eventCount + "\n"
        out += "dropped: " + data.droppedEventCount + "\n\n"

        out += "Top by " + sort + "\n"
        out += "name                                      count   total    mean     min      max      stddev   slow errors\n"

        for (let i = 0; i < Math.min(top, rows.length); ++i) {
            const r = rows[i]
            out += pad(r.name, 42)
                + pad(String(r.count), 8)
                + pad(formatMs(r.totalMs), 9)
                + pad(formatMs(r.meanMs), 9)
                + pad(formatMs(r.minMs), 9)
                + pad(formatMs(r.maxMs), 9)
                + pad(formatMs(r.stddevMs), 9)
                + pad(String(r.slowCount), 6)
                + String(r.errorCount)
                + "\n"
        }

        return out
    }

    function buildStats(snapshot) {
        const rows = []

        for (const key in snapshot.counters) {
            const c = snapshot.counters[key]
            const varianceUs2 = c.count > 1 ? c.m2Us / (c.count - 1) : 0
            const samples = c.samples.slice().sort((a, b) => a - b)

            rows.push({
                name: snapshot.names[c.nameId] || "<unknown>",
                count: c.count,
                totalMs: c.totalUs / 1000,
                minMs: c.minUs / 1000,
                maxMs: c.maxUs / 1000,
                meanMs: c.meanUs / 1000,
                avgMs: c.meanUs / 1000,
                varianceMs2: varianceUs2 / 1000000,
                stddevMs: Math.sqrt(varianceUs2) / 1000,
                lastMs: c.lastUs / 1000,
                p50Ms: percentile(samples, 0.50) / 1000,
                p90Ms: percentile(samples, 0.90) / 1000,
                p95Ms: percentile(samples, 0.95) / 1000,
                p99Ms: percentile(samples, 0.99) / 1000,
                errorCount: c.errorCount,
                slowCount: c.slowCount
            })
        }

        return rows
    }

    function percentile(sortedSamples, p) {
        if (sortedSamples.length === 0)
            return 0

        const idx = Math.floor((sortedSamples.length - 1) * p)
        return sortedSamples[idx]
    }

    function buildFlamegraph(snapshot, groupBy) {
        if (groupBy === "name")
            return buildNameFlamegraph(snapshot)

        if (groupBy === "category")
            return buildCategoryFlamegraph(snapshot)

        return buildStackFlamegraph(snapshot)
    }

    function buildStackFlamegraph(snapshot) {
        const byParent = {}

        for (const ev of snapshot.events) {
            const parent = ev.parentId || 0
            if (!byParent[parent])
                byParent[parent] = []
            byParent[parent].push(ev)
        }

        function fold(parentId) {
            const node = {
                name: parentId === 0 ? "root" : String(parentId),
                totalMs: 0,
                selfMs: 0,
                count: 0,
                children: []
            }

            const folded = {}
            const children = byParent[parentId] || []

            for (const child of children) {
                const name = snapshot.names[child.nameId] || "<unknown>"
                let target = folded[name]

                if (!target) {
                    target = {
                        name: name,
                        totalMs: 0,
                        selfMs: 0,
                        count: 0,
                        children: []
                    }
                    folded[name] = target
                }

                const directChildren = byParent[child.id] || []
                let directChildUs = 0
                for (const c of directChildren)
                    directChildUs += c.durationUs

                target.totalMs += child.durationUs / 1000
                target.selfMs += Math.max(0, child.durationUs - directChildUs) / 1000
                target.count += 1

                const nested = fold(child.id)
                mergeChildren(target, nested.children)
            }

            for (const key in folded)
                node.children.push(folded[key])

            return node
        }

        return fold(0)
    }

    function mergeChildren(target, children) {
        for (const child of children) {
            let existing = null

            for (const t of target.children) {
                if (t.name === child.name) {
                    existing = t
                    break
                }
            }

            if (!existing) {
                target.children.push(child)
                continue
            }

            existing.totalMs += child.totalMs
            existing.selfMs += child.selfMs
            existing.count += child.count
            mergeChildren(existing, child.children)
        }
    }

    function buildNameFlamegraph(snapshot) {
        const root = {
            name: "root",
            totalMs: 0,
            selfMs: 0,
            count: 0,
            children: []
        }

        const byName = {}

        for (const ev of snapshot.events) {
            const name = snapshot.names[ev.nameId] || "<unknown>"
            let node = byName[name]

            if (!node) {
                node = {
                    name: name,
                    totalMs: 0,
                    selfMs: 0,
                    count: 0,
                    children: []
                }
                byName[name] = node
                root.children.push(node)
            }

            node.totalMs += ev.durationUs / 1000
            node.selfMs += ev.durationUs / 1000
            node.count += 1
            root.totalMs += ev.durationUs / 1000
        }

        return root
    }

    function buildCategoryFlamegraph(snapshot) {
        const root = {
            name: "root",
            totalMs: 0,
            selfMs: 0,
            count: 0,
            children: []
        }

        const byCategory = {}

        for (const ev of snapshot.events) {
            const category = snapshot.categories[ev.categoryId] || "general"
            let node = byCategory[category]

            if (!node) {
                node = {
                    name: category,
                    totalMs: 0,
                    selfMs: 0,
                    count: 0,
                    children: []
                }
                byCategory[category] = node
                root.children.push(node)
            }

            node.totalMs += ev.durationUs / 1000
            node.selfMs += ev.durationUs / 1000
            node.count += 1
            root.totalMs += ev.durationUs / 1000
        }

        return root
    }

    function pad(value, width) {
        value = String(value)
        while (value.length < width)
            value += " "
        return value
    }

    function formatMs(value) {
        return value.toFixed(2) + "ms"
    }
}
