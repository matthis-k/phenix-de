import Quickshell
import qs.services

ModelTreeBackendBase {
    id: root

    readonly property var tracer: Logger.scope("backend.backends", { category: "backend" })
    readonly property var prof: Profiler.scope("backend.backends", { category: "backend" })

    property var describedBackends: []

    category: qsTr("Launcher Backends")

    backendId: "backends"
    name: qsTr("Launcher Backends")
    helpDescription: qsTr("Show available launcher sources")
    helpIcon: "help-about"
    helpPrefixes: ["?"]
    priority: 110
    maxResults: 16
    routes: [{ prefix: "?", priority: 110, combine: "exclusive", afterEmpty: "fallthrough" }]

    treeRoots: backendTree

    function shouldParticipate(rawQuery, directive, query) {
        return !!(directive && directive.active && directive.prefix === "?");
    }

    readonly property var backendTree: (root.describedBackends || []).filter(backend =>
        backend && backend.enabled && backend.helpPrefixes && backend.helpPrefixes.length > 0
    ).map(backend => ({
        id: backend.backendId,
        title: backend.helpTitle,
        subtitle: backend.helpPrefixes.join(", ") + " - " + backend.helpDescription,
        icon: backend.helpIcon || "system-search",
        action: { prefix: backend.helpPrefixes[0], replaceQuery: backend.helpPrefixes[0] + " " },
        behavior: { displayPolicy: { discoverable: true } }
    }))

    function activate(result, action) {
        const metadata = result ? result.metadata || {} : {};
        tracer.info("activate", function() { return { resultId: result ? result.id : null, hasReplaceQuery: !!(action?.payload?.replaceQuery || metadata?.action?.payload?.replaceQuery) }; });
        const cmdAction = (action && action.payload) || (metadata.action && metadata.action.payload) || metadata.action || {};
        if (cmdAction.replaceQuery) {
            if (controller)
                controller.queryReplacementRequested(cmdAction.replaceQuery);
        }
    }
}
