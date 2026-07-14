pragma Singleton
import QtQml

QtObject {
    id: root

    property int installedMaxLevel: 0
    property int runtimeMaxLevel: 0

    property int maxEvents: 20000
    property int maxPayloads: 10000

    property int eventCount: 0
    property int droppedEventCount: 0

    property int payloadCount: 0
    property int droppedPayloadCount: 0

    property int nextEventId: 1
    property int nextTraceId: 1

    property var names: []
    property var nameToId: ({})

    property var categories: []
    property var categoryToId: ({})

    property var events: []
    property int eventWriteIndex: 0

    property var payloads: []
    property int payloadWriteIndex: 0

    property var traceStack: []

    property int currentFrameId: 0
    property int currentQueryRevision: 0
    property int currentGeneration: 0
    property string currentSurface: ""

    property bool _clockBaseSet: false
    property var _clockBase: 0

    function configure(config) {
        installedMaxLevel = config.installedMaxLevel !== undefined ? config.installedMaxLevel : 0
        runtimeMaxLevel = config.runtimeMaxLevel !== undefined ? config.runtimeMaxLevel : 0
        maxEvents = config.maxEvents || 20000
        maxPayloads = config.maxPayloads || 10000
        reset()
    }

    function reset() {
        eventCount = 0
        droppedEventCount = 0
        payloadCount = 0
        droppedPayloadCount = 0
        nextEventId = 1
        nextTraceId = 1
        events = new Array(maxEvents)
        payloads = new Array(maxPayloads)
        traceStack = []
        _clockBase = Date.now()
        _clockBaseSet = true
    }

    function nowUs() {
        return (Date.now() - _clockBase) * 1000
    }

    function internName(name) {
        if (name === null || name === undefined)
            name = ""

        let existing = nameToId[name]
        if (existing !== undefined)
            return existing

        const id = names.length
        names.push(name)
        nameToId[name] = id
        return id
    }

    function internCategory(category) {
        if (category === null || category === undefined)
            category = "general"

        let existing = categoryToId[category]
        if (existing !== undefined)
            return existing

        const id = categories.length
        categories.push(category)
        categoryToId[category] = id
        return id
    }

    function nameName(id) {
        return names[id] || "<unknown>"
    }

    function categoryName(id) {
        return categories[id] || "general"
    }

    function appendLog(level, nameId, categoryId, payload) {
        if (level > runtimeMaxLevel)
            return null

        const ev = {
            id: nextEventId++,
            kind: "log",
            level: level,
            nameId: nameId,
            categoryId: categoryId,
            timestampUs: nowUs(),
            traceId: 0,
            parentTraceId: 0,
            durationUs: 0,
            flags: 0,
            frameId: currentFrameId,
            queryRevision: currentQueryRevision,
            generation: currentGeneration,
            surface: currentSurface
        }

        const idx = appendEvent(ev)

        if (payload !== null && payload !== undefined)
            appendPayload(ev.id, payload)

        return ev
    }

    function beginTrace(level, nameId, categoryId, payload) {
        if (level > runtimeMaxLevel)
            return null

        const traceId = nextTraceId++
        const parentTraceId = traceStack.length > 0
            ? traceStack[traceStack.length - 1]
            : 0

        const ev = {
            id: nextEventId++,
            kind: "trace.begin",
            level: level,
            nameId: nameId,
            categoryId: categoryId,
            timestampUs: nowUs(),
            traceId: traceId,
            parentTraceId: parentTraceId,
            durationUs: 0,
            flags: 0,
            frameId: currentFrameId,
            queryRevision: currentQueryRevision,
            generation: currentGeneration,
            surface: currentSurface
        }

        const idx = appendEvent(ev)
        traceStack.push(traceId)

        if (payload !== null && payload !== undefined)
            appendPayload(ev.id, payload)

        return {
            eventId: ev.id,
            traceId: traceId,
            index: idx
        }
    }

    function endTrace(traceInfo, payload) {
        if (traceInfo === null || traceInfo === undefined)
            return

        const ev = events[traceInfo.index]
        if (!ev)
            return

        const durationUs = nowUs() - ev.timestampUs
        ev.durationUs = durationUs
        ev.kind = "trace.end"

        if (payload !== null && payload !== undefined)
            appendPayload(ev.id, payload)

        const tid = traceInfo.traceId
        for (let i = traceStack.length - 1; i >= 0; --i) {
            if (traceStack[i] === tid) {
                traceStack.splice(i, 1)
                break
            }
        }
    }

    function markTraceError(traceInfo, error) {
        if (traceInfo === null || traceInfo === undefined)
            return

        const ev = events[traceInfo.index]
        if (ev)
            ev.flags |= 1
    }

    function appendEvent(ev) {
        const idx = eventWriteIndex
        eventWriteIndex = (eventWriteIndex + 1) % maxEvents

        if (eventCount < maxEvents)
            eventCount += 1
        else
            droppedEventCount += 1

        events[idx] = ev
        return idx
    }

    function appendPayload(eventId, payload) {
        const pl = {
            eventId: eventId,
            timestampUs: nowUs(),
            payload: payload
        }

        const idx = payloadWriteIndex
        payloadWriteIndex = (payloadWriteIndex + 1) % maxPayloads

        if (payloadCount < maxPayloads)
            payloadCount += 1
        else
            droppedPayloadCount += 1

        payloads[idx] = pl
        return idx
    }

    function setFrameContext(frameId, surface) {
        currentFrameId = frameId
        currentSurface = surface || ""
    }

    function setQueryContext(queryRevision, generation) {
        currentQueryRevision = queryRevision || 0
        currentGeneration = generation || 0
    }

    function snapshot(options) {
        options = options || {}

        const liveEvents = []
        for (let i = 0; i < events.length; ++i) {
            const ev = events[i]
            if (ev)
                liveEvents.push(ev)
        }

        liveEvents.sort((a, b) => a.id - b.id)

        let filtered = liveEvents

        if (options.level) {
            const levelVal = levelFromName(options.level)
            filtered = filtered.filter(function(ev) { return ev.level === levelVal })
        }

        if (options.category) {
            const catId = categoryToId[options.category]
            if (catId !== undefined)
                filtered = filtered.filter(function(ev) { return ev.categoryId === catId })
        }

        if (options.nameContains) {
            const lower = options.nameContains.toLowerCase()
            filtered = filtered.filter(function(ev) {
                const name = names[ev.nameId] || ""
                return name.toLowerCase().indexOf(lower) >= 0
            })
        }

        if (options.queryRevision !== undefined) {
            filtered = filtered.filter(function(ev) { return ev.queryRevision === options.queryRevision })
        }

        if (options.limit && filtered.length > options.limit)
            filtered = filtered.slice(-options.limit)

        const livePayloads = []
        for (let i = 0; i < payloads.length; ++i) {
            const pl = payloads[i]
            if (pl)
                livePayloads.push(pl)
        }

        return {
            installedMaxLevel: installedMaxLevel,
            runtimeMaxLevel: runtimeMaxLevel,
            eventCount: eventCount,
            droppedEventCount: droppedEventCount,
            payloadCount: payloadCount,
            droppedPayloadCount: droppedPayloadCount,
            names: names.slice(),
            categories: categories.slice(),
            events: filtered,
            payloads: livePayloads
        }
    }

    function levelFromName(name) {
        switch (String(name || "").toLowerCase()) {
        case "off":   return 0
        case "fatal": return 10
        case "error": return 20
        case "warn":  return 30
        case "info":  return 40
        case "debug": return 50
        case "trace": return 60
        default:      return -1
        }
    }

    function levelName(level) {
        switch (level) {
        case 0:  return "off"
        case 10: return "fatal"
        case 20: return "error"
        case 30: return "warn"
        case 40: return "info"
        case 50: return "debug"
        case 60: return "trace"
        default: return "unknown"
        }
    }
}
