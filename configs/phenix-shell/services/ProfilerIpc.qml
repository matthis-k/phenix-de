pragma Singleton
import QtQml
import qs.services

QtObject {
    function handle(request) {
        switch (request.op) {
        case "status":
            return Profiler.status()

        case "enable":
            return Profiler.enable()

        case "disable":
            return Profiler.disable()

        case "toggle":
            return Profiler.toggle()

        case "setMode":
            return Profiler.setMode(request.mode)

        case "reset":
            return Profiler.reset()

        case "collect":
            return Profiler.collect(request)

        case "report":
            return {
                ok: true,
                text: Profiler.report(request)
            }

        case "flamegraph":
            return {
                ok: true,
                flamegraph: Profiler.flamegraph(request)
            }

        default:
            return {
                ok: false,
                error: "Unknown profiler op: " + request.op
            }
        }
    }
}
