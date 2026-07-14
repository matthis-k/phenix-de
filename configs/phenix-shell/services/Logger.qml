pragma Singleton
import QtQml
import "logger"

QtObject {
    id: root

    readonly property bool devMode: Config.behaviour.devMode

    property bool installed: Config.behaviour.loggerInstalled
        || devMode

    property int installedMaxLevel: Config.behaviour.loggerInstalledMaxLevel !== undefined
        ? Config.behaviour.loggerInstalledMaxLevel
        : (devMode ? 60 : 30)

    property int runtimeMaxLevel: Config.behaviour.loggerRuntimeMaxLevel !== undefined
        ? Config.behaviour.loggerRuntimeMaxLevel
        : (devMode ? 50 : 30)

    readonly property bool fatalOn: 10 <= runtimeMaxLevel
    readonly property bool errorOn: 20 <= runtimeMaxLevel
    readonly property bool warnOn:  30 <= runtimeMaxLevel
    readonly property bool infoOn:  40 <= runtimeMaxLevel
    readonly property bool debugOn: 50 <= runtimeMaxLevel
    readonly property bool traceOn: 60 <= runtimeMaxLevel

    readonly property var fatal: 10 <= LogStore.runtimeMaxLevel ? _fatalImpl : _noopLog
    readonly property var error: 20 <= LogStore.runtimeMaxLevel ? _errorImpl : _noopLog
    readonly property var warn:  30 <= LogStore.runtimeMaxLevel ? _warnImpl : _noopLog
    readonly property var info:  40 <= LogStore.runtimeMaxLevel ? _infoImpl : _noopLog
    readonly property var debug: 50 <= LogStore.runtimeMaxLevel ? _debugImpl : _noopLog
    readonly property var trace: 60 <= LogStore.runtimeMaxLevel ? _traceImpl : _noopLog

    readonly property var beginTrace: 60 <= LogStore.runtimeMaxLevel ? _beginTraceImpl : _nullBeginTrace
    readonly property var endTrace: 60 <= LogStore.runtimeMaxLevel ? _endTraceImpl : _noopEndTrace

    Component.onCompleted: {
        LogStore.configure({
            installedMaxLevel: installedMaxLevel,
            runtimeMaxLevel: runtimeMaxLevel,
            maxEvents: Config.behaviour.loggerMaxEvents || 20000,
            maxPayloads: Config.behaviour.loggerMaxPayloads || 10000
        })

        root.installed = true
    }

    function _noopLog(name, defaults, payloadProvider) {}
    function _nullBeginTrace(name, defaults, payloadProvider) { return null }
    function _noopEndTrace(span, payloadProvider) {}

    function _logImpl(level, name, defaults, payloadProvider) {
        const nameId = LogStore.internName(name)
        const categoryId = LogStore.internCategory(
            (defaults && defaults.category) || inferCategory(name)
        )

        let payload = null
        if (typeof payloadProvider === "function")
            payload = payloadProvider()
        else if (payloadProvider !== undefined)
            payload = payloadProvider

        LogStore.appendLog(level, nameId, categoryId, payload)
    }

    function _fatalImpl(name, defaults, payloadProvider) {
        root._logImpl(10, name, defaults, payloadProvider)
    }
    function _errorImpl(name, defaults, payloadProvider) {
        root._logImpl(20, name, defaults, payloadProvider)
    }
    function _warnImpl(name, defaults, payloadProvider) {
        root._logImpl(30, name, defaults, payloadProvider)
    }
    function _infoImpl(name, defaults, payloadProvider) {
        root._logImpl(40, name, defaults, payloadProvider)
    }
    function _debugImpl(name, defaults, payloadProvider) {
        root._logImpl(50, name, defaults, payloadProvider)
    }
    function _traceImpl(name, defaults, payloadProvider) {
        root._logImpl(60, name, defaults, payloadProvider)
    }

    function _beginTraceImpl(name, defaults, payloadProvider) {
        const nameId = LogStore.internName(name)
        const categoryId = LogStore.internCategory(
            (defaults && defaults.category) || inferCategory(name)
        )

        let payload = null
        if (typeof payloadProvider === "function")
            payload = payloadProvider()
        else if (payloadProvider !== undefined)
            payload = payloadProvider

        return LogStore.beginTrace(60, nameId, categoryId, payload)
    }

    function _endTraceImpl(span, payloadProvider) {
        if (span === null || span === undefined)
            return

        let payload = null
        if (typeof payloadProvider === "function")
            payload = payloadProvider()
        else if (payloadProvider !== undefined)
            payload = payloadProvider

        LogStore.endTrace(span, payload)
    }

    function levelFromName(name) {
        return LogStore.levelFromName(name)
    }

    function levelName(level) {
        return LogStore.levelName(level)
    }

    function setLevel(name) {
        const level = LogStore.levelFromName(name)
        if (level < 0)
            return { ok: false, error: "Invalid level: " + name }

        LogStore.runtimeMaxLevel = level
        runtimeMaxLevel = level
        return { ok: true, level: name }
    }

    function disable() {
        return setLevel("off")
    }

    function status() {
        return {
            installed: installed,
            installedMaxLevel: LogStore.levelName(installedMaxLevel),
            runtimeMaxLevel: LogStore.levelName(LogStore.runtimeMaxLevel),
            eventCount: LogStore.eventCount,
            droppedEventCount: LogStore.droppedEventCount,
            payloadCount: LogStore.payloadCount,
            droppedPayloadCount: LogStore.droppedPayloadCount
        }
    }

    function reset() {
        LogStore.reset()
        return { ok: true }
    }

    function collect(options) {
        return LogStats.collect(options || {})
    }

    function report(options) {
        return LogStats.textReport(options || {})
    }

    function traceFn(name, defaults, fn, payloadProvider) {
        return function traceFnWrapper() {
            const span = root.beginTrace(name, defaults, payloadProvider)

            try {
                return fn.apply(this, arguments)
            } catch (error) {
                if (span !== null)
                    LogStore.markTraceError(span, error)
                throw error
            } finally {
                root.endTrace(span)
            }
        }
    }

    function traced(name, fn, options) {
        options = options || {}
        const level = options.level !== undefined
            ? LogStore.levelFromName(options.level)
            : 60

        if (level > installedMaxLevel)
            return fn

        const s = root.scope(name, options)
        return function tracedWrapper() {
            const span = s.beginTrace(name, options)

            try {
                return fn.apply(this, arguments)
            } catch (error) {
                if (span !== null)
                    LogStore.markTraceError(span, error)
                throw error
            } finally {
                s.endTrace(span)
            }
        }
    }

    function tap(name, value, defaults, summarizer) {
        if (typeof summarizer === "function")
            root.debug(name, defaults, function() { return summarizer(value) })

        return value
    }

    function scope(prefix, defaults) {
        defaults = defaults || {}

        const makeName = function(name) {
            return prefix + "." + name
        }

        return {
            fatal: function(name, payloadProvider) {
                root.fatal(makeName(name), defaults, payloadProvider)
            },

            error: function(name, payloadProvider) {
                root.error(makeName(name), defaults, payloadProvider)
            },

            warn: function(name, payloadProvider) {
                root.warn(makeName(name), defaults, payloadProvider)
            },

            info: function(name, payloadProvider) {
                root.info(makeName(name), defaults, payloadProvider)
            },

            debug: function(name, payloadProvider) {
                root.debug(makeName(name), defaults, payloadProvider)
            },

            trace: function(name, payloadProvider) {
                root.trace(makeName(name), defaults, payloadProvider)
            },

            beginTrace: function(name, payloadProvider) {
                return root.beginTrace(makeName(name), defaults, payloadProvider)
            },

            endTrace: function(span, payloadProvider) {
                root.endTrace(span, payloadProvider)
            },

            traceFn: function(name, fn, payloadProvider) {
                return root.traceFn(makeName(name), defaults, fn, payloadProvider)
            },

            traced: function(name, fn, options) {
                const merged = mergeOptions(defaults, options || {})
                merged.name = makeName(name)
                return root.traced(merged.name, fn, merged)
            },

            tap: function(name, value, summarizer) {
                return root.tap(makeName(name), value, defaults, summarizer)
            }
        }
    }

    function inferCategory(name) {
        const dot = name.indexOf(".")
        return dot > 0 ? name.slice(0, dot) : "general"
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
}
