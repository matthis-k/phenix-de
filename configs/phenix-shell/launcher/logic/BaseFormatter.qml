import QtQml
import qs.services

QtObject {
    readonly property var tracer: Logger.scope("launcher.formatter.base", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.formatter.base", { category: "launcher" })

    property string formatterName: "base"

    function serialize(evaluation, request) {
        console.warn("BaseFormatter.serialize() not implemented for", formatterName)
        return ({})
    }
}
