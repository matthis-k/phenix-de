pragma Singleton
import QtQml

QtObject {
    id: root

    property string mode: "off"
    property bool installed: false
    property int maxEvents: 50000
    property int maxSamplesPerName: 512

    property int eventCount: 0
    property int droppedEventCount: 0

    property var names: []
    property var nameToId: ({})
    property var categories: []
    property var categoryToId: ({})

    property var counters: ({})

    property int writeIndex: 0
    property int nextEventId: 1
    property var events: []
    property var stack: []

    property int currentFrameId: 0
    property int currentQueryRevision: 0
    property int currentGeneration: 0
    property string currentSurface: ""

    function configure(config) {
        installed = config.installed
        mode = config.mode
        maxEvents = config.maxEvents || 50000
        maxSamplesPerName = config.maxSamplesPerName || 512
        reset()
    }

    function setMode(nextMode) {
        mode = nextMode
    }

    function reset() {
        eventCount = 0
        droppedEventCount = 0
        writeIndex = 0
        nextEventId = 1
        counters = {}
        events = new Array(maxEvents)
        stack = []
    }

    function internName(name) {
        let existing = nameToId[name]
        if (existing !== undefined)
            return existing

        const id = names.length
        names.push(name)
        nameToId[name] = id
        return id
    }

    function internCategory(category) {
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

    function nowUs() {
        return ProfilerClock.nowUs()
    }

    function begin(nameId, categoryId) {
        if (mode === "off")
            return null

        const idx = writeIndex
        writeIndex = (writeIndex + 1) % maxEvents

        if (eventCount < maxEvents)
            eventCount += 1
        else
            droppedEventCount += 1

        const parent =
            stack.length > 0
                ? events[stack[stack.length - 1]].id
                : 0

        const ev = {
            id: nextEventId++,
            parentId: parent,
            nameId: nameId,
            categoryId: categoryId,
            startUs: nowUs(),
            durationUs: 0,
            flags: 0,
            frameId: currentFrameId,
            queryRevision: currentQueryRevision,
            generation: currentGeneration,
            surface: currentSurface
        }

        events[idx] = ev
        stack.push(idx)

        return idx
    }

    function markError(span) {
        if (span === null || span === undefined)
            return

        const ev = events[span]
        if (ev)
            ev.flags |= 1
    }

    function end(span, slowThresholdUs) {
        if (span === null || span === undefined)
            return

        const ev = events[span]
        if (!ev)
            return

        const durationUs = nowUs() - ev.startUs
        ev.durationUs = durationUs

        const slow = slowThresholdUs > 0 && durationUs >= slowThresholdUs
        if (slow)
            ev.flags |= 2

        updateCounter(ev.nameId, durationUs, (ev.flags & 1) !== 0, slow)

        if (stack.length > 0 && stack[stack.length - 1] === span) {
            stack.pop()
        } else {
            repairStack(span)
        }
    }

    function updateCounter(nameId, durationUs, errored, slow) {
        let c = counters[nameId]

        if (!c) {
            c = {
                nameId: nameId,
                count: 0,
                totalUs: 0,
                minUs: durationUs,
                maxUs: durationUs,
                meanUs: 0,
                m2Us: 0,
                lastUs: 0,
                errorCount: 0,
                slowCount: 0,
                samples: []
            }
            counters[nameId] = c
        }

        c.count += 1
        c.totalUs += durationUs
        c.lastUs = durationUs

        if (durationUs < c.minUs)
            c.minUs = durationUs

        if (durationUs > c.maxUs)
            c.maxUs = durationUs

        const delta = durationUs - c.meanUs
        c.meanUs += delta / c.count
        const delta2 = durationUs - c.meanUs
        c.m2Us += delta * delta2

        if (errored)
            c.errorCount += 1

        if (slow)
            c.slowCount += 1

        if (c.samples.length < maxSamplesPerName) {
            c.samples.push(durationUs)
        } else {
            c.samples[c.count % maxSamplesPerName] = durationUs
        }
    }

    function repairStack(span) {
        for (let i = stack.length - 1; i >= 0; --i) {
            if (stack[i] === span) {
                stack.splice(i, 1)
                return
            }
        }
    }

    function setFrameContext(frameId, surface) {
        currentFrameId = frameId
        currentSurface = surface || ""
    }

    function setQueryContext(queryRevision, generation) {
        currentQueryRevision = queryRevision || 0
        currentGeneration = generation || 0
    }

    function snapshot() {
        const liveEvents = []

        for (let i = 0; i < events.length; ++i) {
            const ev = events[i]
            if (ev && ev.durationUs > 0)
                liveEvents.push(ev)
        }

        liveEvents.sort((a, b) => a.startUs - b.startUs)

        return {
            mode: mode,
            eventCount: eventCount,
            droppedEventCount: droppedEventCount,
            names: names.slice(),
            categories: categories.slice(),
            counters: cloneCounters(),
            events: liveEvents
        }
    }

    function cloneCounters() {
        const result = {}

        for (const key in counters) {
            const c = counters[key]
            result[key] = {
                nameId: c.nameId,
                count: c.count,
                totalUs: c.totalUs,
                minUs: c.minUs,
                maxUs: c.maxUs,
                meanUs: c.meanUs,
                m2Us: c.m2Us,
                lastUs: c.lastUs,
                errorCount: c.errorCount,
                slowCount: c.slowCount,
                samples: c.samples.slice()
            }
        }

        return result
    }
}
