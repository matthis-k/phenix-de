pragma Singleton
import QtQml

QtObject {
    function handle(request) {
        switch (request.op) {
        case "status":
            return Logger.status()

        case "setLevel":
            return Logger.setLevel(request.level)

        case "disable":
            return Logger.disable()

        case "reset":
            return Logger.reset()

        case "collect":
            return Logger.collect({
                includeEvents: request.includeEvents,
                includePayloads: request.includePayloads,
                includeTraces: request.includeTraces,
                includeCounts: request.includeCounts,
                level: request.level,
                category: request.category,
                nameContains: request.nameContains,
                queryRevision: request.queryRevision,
                limit: request.limit || 500
            })

        case "report":
            return {
                ok: true,
                text: Logger.report({
                    slowMs: request.slowMs,
                    top: request.top,
                    limit: request.limit
                })
            }

        case "export":
            return {
                ok: false,
                text: "TODO: logger.export not yet implemented"
            }

        default:
            return {
                ok: false,
                error: "Unknown logger op: " + request.op
            }
        }
    }
}
