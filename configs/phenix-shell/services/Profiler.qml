pragma Singleton
import QtQml

QtObject {
    id: root

    readonly property bool devMode: Config.behaviour.devMode

    property bool installed: Config.behaviour.profilerInstalled
    property string mode: Config.behaviour.profilerMode

    readonly property bool recording: mode !== "off"
    readonly property bool countersEnabled: mode === "counters" || mode === "spans" || mode === "detailed"
    readonly property bool spansEnabled: mode === "spans" || mode === "detailed"
    readonly property bool detailedEnabled: mode === "detailed"

    property int maxEvents: Config.behaviour.profilerMaxEvents
    property int maxSamplesPerName: Config.behaviour.profilerMaxSamplesPerName

    signal modeChangedForProfiler(string mode)

    Component.onCompleted: {
        ProfilerStore.configure({
            installed: installed || devMode,
            mode: mode || (devMode ? "spans" : "off"),
            maxEvents: maxEvents || 50000,
            maxSamplesPerName: maxSamplesPerName || 512
        })
    }

    onModeChanged: {
        ProfilerStore.setMode(mode)
        modeChangedForProfiler(mode)
    }

    function enable() {
        installed = true
        mode = "spans"
        return { ok: true, mode: mode }
    }

    function disable() {
        mode = "off"
        return { ok: true, mode: mode }
    }

    function toggle() {
        return recording ? disable() : enable()
    }

    function setMode(nextMode) {
        if (!["off", "counters", "spans", "detailed"].includes(nextMode)) {
            return {
                ok: false,
                error: "Invalid profiler mode: " + nextMode
            }
        }

        if (!installed && nextMode !== "off")
            installed = true

        mode = nextMode
        return { ok: true, mode: mode }
    }

    function reset() {
        ProfilerStore.reset()
        return { ok: true }
    }

    function status() {
        return {
            installed: installed,
            mode: mode,
            recording: recording,
            countersEnabled: countersEnabled,
            spansEnabled: spansEnabled,
            detailedEnabled: detailedEnabled,
            maxEvents: maxEvents,
            eventCount: ProfilerStore.eventCount,
            droppedEventCount: ProfilerStore.droppedEventCount
        }
    }

    function collect(options) {
        return ProfilerStats.collect(options || {})
    }

    function report(options) {
        return ProfilerStats.textReport(options || {})
    }

    function flamegraph(options) {
        return ProfilerStats.flamegraph(options || {})
    }

    function profiled(name, fn, options) {
        const nameId = ProfilerStore.internName(name)
        const categoryId = ProfilerStore.internCategory((options && options.category) || inferCategory(name))
        const slowThresholdUs = (options && options.slowThresholdUs) || slowThresholdForCategoryUs(categoryId)

        return function profiledWrapper() {
            if (mode === "off")
                return fn.apply(this, arguments)

            const span = ProfilerStore.begin(nameId, categoryId)

            try {
                return fn.apply(this, arguments)
            } catch (error) {
                ProfilerStore.markError(span)
                throw error
            } finally {
                ProfilerStore.end(span, slowThresholdUs)
            }
        }
    }

    function scope(prefix, defaults) {
        defaults = defaults || {}

        return {
            fn: function(name, fn, options) {
                return root.profiled(prefix + "." + name, fn, mergeOptions(defaults, options))
            },

            begin: function(name) {
                if (root.mode === "off")
                    return null

                const fullName = prefix + "." + name
                return ProfilerStore.begin(
                    ProfilerStore.internName(fullName),
                    ProfilerStore.internCategory(defaults.category || inferCategory(fullName))
                )
            },

            end: function(span) {
                if (span !== null && span !== undefined)
                    ProfilerStore.end(span)
            }
        }
    }

    function mergeOptions(a, b) {
        if (!b)
            return a

        const result = {}
        for (const key in a)
            result[key] = a[key]
        for (const key in b)
            result[key] = b[key]
        return result
    }

    function inferCategory(name) {
        const dot = name.indexOf(".")
        return dot > 0 ? name.slice(0, dot) : "general"
    }

    function slowThresholdForCategoryUs(categoryId) {
        const category = ProfilerStore.categoryName(categoryId)

        switch (category) {
        case "launcher": return 8000
        case "backend": return 8000
        case "policy": return 1000
        case "service": return 5000
        case "animation": return 4000
        case "ipc": return 10000
        case "render": return 16600
        default: return 8000
        }
    }
}
