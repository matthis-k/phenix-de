pragma Singleton
import QtQml

QtObject {
    id: root

    function collect(options) {
        options = options || {}

        const snapshot = LogStore.snapshot(options)

        const result = {
            ok: true,
            installedMaxLevel: snapshot.installedMaxLevel,
            runtimeMaxLevel: snapshot.runtimeMaxLevel,
            eventCount: snapshot.eventCount,
            droppedEventCount: snapshot.droppedEventCount,
            payloadCount: snapshot.payloadCount,
            droppedPayloadCount: snapshot.droppedPayloadCount
        }

        if (options.includeEvents)
            result.events = decorateEvents(snapshot)

        if (options.includePayloads)
            result.payloads = snapshot.payloads

        if (options.includeCounts)
            result.counts = buildCounts(snapshot)

        if (options.includeTraces) {
            const slowMs = options.slowMs || 0
            result.slowTraces = buildSlowTraces(snapshot, slowMs)
            result.traceTree = buildTraceTree(snapshot)
        }

        return result
    }

    function textReport(options) {
        options = options || {}

        const data = collect({
            includeCounts: true,
            includeTraces: true,
            slowMs: options.slowMs || 4,
            limit: options.limit
        })

        let out = ""
        out += "Logger report\n"
        out += "installed level: " + LogStore.levelName(data.installedMaxLevel) + "\n"
        out += "runtime level: " + LogStore.levelName(data.runtimeMaxLevel) + "\n"
        out += "events: " + data.eventCount + "\n"
        out += "dropped events: " + data.droppedEventCount + "\n"
        out += "payloads: " + data.payloadCount + "\n"
        out += "dropped payloads: " + data.droppedPayloadCount + "\n\n"

        if (data.counts) {
            out += "Counts by level\n"
            out += pad("level", 10) + "count\n"
            const levels = ["fatal", "error", "warn", "info", "debug", "trace"]
            for (let i = 0; i < levels.length; ++i) {
                const l = levels[i]
                const c = data.counts.byLevel[l] || 0
                if (c > 0)
                    out += pad(l, 10) + c + "\n"
            }
            out += "\n"

            out += "Counts by category\n"
            out += pad("category", 20) + "count\n"
            const cats = Object.keys(data.counts.byCategory).sort()
            for (let i = 0; i < cats.length; ++i) {
                const c = cats[i]
                out += pad(c, 20) + data.counts.byCategory[c] + "\n"
            }
            out += "\n"
        }

        if (data.slowTraces && data.slowTraces.length > 0) {
            out += "Slow traces (>=" + (options.slowMs || 4) + "ms)\n"
            out += pad("name", 42) + "duration\n"
            const top = options.top || 30
            const sorted = data.slowTraces.slice().sort(function(a, b) {
                return b.durationUs - a.durationUs
            })
            for (let i = 0; i < Math.min(top, sorted.length); ++i) {
                const t = sorted[i]
                const name = LogStore.nameName(t.nameId)
                out += pad(name, 42) + (t.durationUs / 1000).toFixed(2) + "ms\n"
            }
        }

        return out
    }

    function decorateEvents(snapshot) {
        return snapshot.events.map(function(ev) {
            return {
                id: ev.id,
                kind: ev.kind,
                level: LogStore.levelName(ev.level),
                name: snapshot.names[ev.nameId] || "<unknown>",
                category: snapshot.categories[ev.categoryId] || "general",
                timestampUs: ev.timestampUs,
                traceId: ev.traceId,
                parentTraceId: ev.parentTraceId,
                durationUs: ev.durationUs,
                durationMs: ev.durationUs / 1000,
                flags: ev.flags,
                frameId: ev.frameId,
                queryRevision: ev.queryRevision,
                generation: ev.generation,
                surface: ev.surface
            }
        })
    }

    function buildCounts(snapshot) {
        const byLevel = {}
        const byCategory = {}

        for (let i = 0; i < snapshot.events.length; ++i) {
            const ev = snapshot.events[i]
            const levelName = LogStore.levelName(ev.level)
            byLevel[levelName] = (byLevel[levelName] || 0) + 1

            const catName = snapshot.categories[ev.categoryId] || "general"
            byCategory[catName] = (byCategory[catName] || 0) + 1
        }

        return {
            byLevel: byLevel,
            byCategory: byCategory
        }
    }

    function buildSlowTraces(snapshot, slowMs) {
        const slowUs = (slowMs || 0) * 1000
        const traces = []

        for (let i = 0; i < snapshot.events.length; ++i) {
            const ev = snapshot.events[i]
            if (ev.kind === "trace.end" && ev.durationUs >= slowUs) {
                traces.push({
                    eventId: ev.id,
                    traceId: ev.traceId,
                    parentTraceId: ev.parentTraceId,
                    nameId: ev.nameId,
                    categoryId: ev.categoryId,
                    durationUs: ev.durationUs,
                    timestampUs: ev.timestampUs,
                    level: ev.level,
                    flags: ev.flags
                })
            }
        }

        return traces
    }

    function buildTraceTree(snapshot) {
        const byId = {}

        for (let i = 0; i < snapshot.events.length; ++i) {
            const ev = snapshot.events[i]
            if (ev.kind === "trace.begin" || ev.kind === "trace.end") {
                const tid = ev.traceId
                if (!byId[tid])
                    byId[tid] = {}

                if (ev.kind === "trace.begin") {
                    byId[tid].begin = ev
                } else {
                    byId[tid].end = ev
                }
            }
        }

        function buildNode(traceId) {
            const entry = byId[traceId]
            if (!entry || !entry.begin)
                return null

            const begin = entry.begin
            const end = entry.end

            const node = {
                traceId: traceId,
                parentTraceId: begin.parentTraceId,
                name: snapshot.names[begin.nameId] || "<unknown>",
                category: snapshot.categories[begin.categoryId] || "general",
                startUs: begin.timestampUs,
                durationUs: end ? end.durationUs : 0,
                flags: begin.flags | (end ? end.flags : 0),
                children: []
            }

            for (const tid in byId) {
                const child = byId[tid]
                if (child.begin && child.begin.parentTraceId === traceId) {
                    const childNode = buildNode(parseInt(tid))
                    if (childNode)
                        node.children.push(childNode)
                }
            }

            node.children.sort(function(a, b) { return a.startUs - b.startUs })
            return node
        }

        const roots = []
        for (const tid in byId) {
            const entry = byId[tid]
            if (entry.begin && (entry.begin.parentTraceId === 0 || !byId[entry.begin.parentTraceId])) {
                const root = buildNode(parseInt(tid))
                if (root)
                    roots.push(root)
            }
        }

        roots.sort(function(a, b) { return a.startUs - b.startUs })

        return {
            roots: roots
        }
    }

    function pad(value, width) {
        value = String(value)
        while (value.length < width)
            value += " "
        return value
    }
}
