import QtQml
import qs.services
import "../logic/"
import "../logic/EvaluationProfiles.js" as EvalProfiles
import "../logic/RoutingTree.js" as RoutingTree

QtObject {
    id: root

    readonly property var tracer: Logger.scope("backend.launcherBackendBase", { category: "backend" })
    readonly property var prof: Profiler.scope("backend.launcherBackendBase", { category: "backend" })

    property string backendId: ""
    property string name: ""
    property string category: ""
    property string helpTitle: name
    property string helpDescription: ""
    property string helpIcon: "system-search"
    property var helpPrefixes: []
    property bool enabled: true
    property int priority: 0
    property int maxResults: 5
    property var routes: []
    property var controller: null
    property var _registeredEndpoints: []
    property string activeQuery: ""
    property int activeGeneration: 0

    Component.onCompleted: {
        tracer.info("completed", function() { return { backendId: root.backendId, routeCount: (root.routes || []).length }; });
        root.registerRoutesOnTree();
    }

    Component.onDestruction: {
        tracer.info("destruction", function() { return { backendId: root.backendId }; });
        root.unregisterRoutesFromTree();
    }

    function registerRoutesOnTree() {
        if (!root.controller || !root.controller.routingTree)
            return;
        for (var i = 0; i < (root.routes || []).length; i += 1) {
            RoutingTree.registerEndpoint(root.controller.routingTree, root.routes[i], root);
            root._registeredEndpoints.push(root.routes[i]);
        }
    }

    function unregisterRoutesFromTree() {
        if (!root.controller || !root.controller.routingTree)
            return;
        for (var i = 0; i < root._registeredEndpoints.length; i += 1)
            RoutingTree.unregisterEndpoint(root.controller.routingTree, root);
        root._registeredEndpoints = [];
    }

    signal backendError(string message)

    function beginSearch(query, generation) {
        if (root.activeQuery && root.activeGeneration !== generation)
            root.cancelSearch(root.activeQuery, root.activeGeneration);
        root.activeQuery = query || "";
        root.activeGeneration = generation || 0;
    }

    function finishSearch(query, generation) {
        if (generation !== undefined && generation !== root.activeGeneration)
            return;
        root.activeQuery = "";
        root.activeGeneration = 0;
    }

    function cancelSearch(query, generation) {
        root.activeQuery = "";
        root.activeGeneration = 0;
    }

    function activate(result, action) {
        tracer.debug("activate", function() { return { resultId: result?.id, actionId: action?.id }; });
    }

    function actionDto(id, label, payload) {
        return Tokenize.makeAction(id, label, payload || {});
    }

    function nodeDto(options) {
        const opts = options || {};
        return Tokenize.makeNode(Object.assign({
            backendId: root.backendId,
            kind: "backend-result",
            icon: root.helpIcon || "system-search"
        }, opts));
    }

    function backendRootDto(children, options) {
        const opts = options || {};
        return Tokenize.makeNode(Object.assign({
            id: "backend." + root.backendId,
            backendId: root.backendId,
            backendPriority: root.priority,
            kind: "backend",
            label: root.helpTitle || root.name || root.backendId,
            subtitle: root.helpDescription || "",
            icon: root.helpIcon || "system-search",
            children: children || [],
            behavior: Object.assign({
                exclusiveWhen: (root.routes || []).filter(function(route) { return route && (route.mode === "exclusive" || route.combine === "exclusive"); })
            }, opts.behavior || {}),
            evaluationProfile: EvalProfiles.backendRootProfile({ strategies: ["exact", "prefix", "compact", "substring", "acronym"] })
        }, opts));
    }

    function queryText(query) {
        if (root.controller && root.controller.routingTree) {
            var result = RoutingTree.routeQuery(root.controller.routingTree, query || "");
            if (result && result.endpoints && result.endpoints.length > 0)
                return result.strippedQuery || "";
        }
        return query || "";
    }

    function resultNodes(query, context) {
        return [];
    }

    function rootNode(query, context) {
        const children = root.resultNodes(query, context) || [];
        tracer.trace("rootNode", function() { return { backendId: root.backendId, childCount: children.length }; });
        return root.backendRootDto(children);
    }

    function node(options) {
        const opts = options || {};
        return root.nodeDto(Object.assign({
            kind: "computed-result",
            icon: root.helpIcon || "system-search"
        }, opts));
    }

    function action(id, label, payload) {
        return root.actionDto(id, label, payload || {});
    }
}
