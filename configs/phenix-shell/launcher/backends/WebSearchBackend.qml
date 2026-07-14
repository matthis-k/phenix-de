import Quickshell
import qs.services

LauncherBackendBase {
    id: root

    readonly property var tracer: Logger.scope("backend.webSearch", { category: "backend" })
    readonly property var prof: Profiler.scope("backend.webSearch", { category: "backend" })

    category: qsTr("Web Search")

    backendId: "web"
    name: qsTr("Web Search")
    helpDescription: qsTr("Search the web in the default browser")
    helpIcon: "internet-web-browser"
    helpPrefixes: ["@web", "web"]
    priority: 20
    maxResults: 1
    routes: [
        { prefix: "@web", priority: 20, combine: "exclusive", afterEmpty: "fallthrough" },
        { prefix: "web", priority: 20, combine: "exclusive", afterEmpty: "fallthrough" },
        { priority: 0, combine: "shared", afterEmpty: "fallthrough" }
    ]

    function resultNodes(query, context) {
        const searchText = query ? query.raw.trim() : "";
        tracer.debug("resultNodes", function() { return { query: searchText, directive: context?.directive?.prefix || null }; });
        const directivePrefix = context && context.directive ? context.directive.prefix : "";
        const queryTokens = (query && query.tokens || []).map(function(token) { return token.raw; });
        if (!directivePrefix && (searchText[0] === "/" || searchText[0] === "~" || searchText.indexOf("file://") === 0 || /^@files?(\s|$)/.test(searchText)))
            return [];

        if (!searchText)
            return [];

        return [root.node({
            id: "web:" + searchText,
            kind: "desktop-action",
            label: searchText,
            subtitle: qsTr("Search Web"),
            icon: root.helpIcon,
            aliases: ["web", "search", "browser"],
            keywords: ["web", "search", "browser", searchText],
            behavior: { tokenPolicy: { tokens: queryTokens, weight: 1.0 } },
            actionList: [root.action("search", qsTr("Search"), { query: searchText })],
            semanticTerms: [{ triggers: ["search", "web", "browser"], matches: ["search", "web", "browser"], field: "semantic", score: 0.74, weight: 0.34 }]
        })];
    }

    function activate(result, action) {
        tracer.info("activate", function() { return { resultId: result ? result.id : null, testMode: TestMode.isActive }; });
        if (TestMode.isActive)
            return;

        const metadata = result ? result.metadata || {} : {};
        const cmdAction = metadata.action || {};
        const searchQuery = metadata.query || cmdAction.query || (action && action.payload && action.payload.query) || "";
        if (!searchQuery)
            return;

        tracer.debug("activate.search", function() { return { query: searchQuery, browser: Quickshell.env("BROWSER") || "xdg-open" }; });
        Quickshell.execDetached({ command: [Quickshell.env("BROWSER") || "xdg-open", searchQuery] });
    }
}
