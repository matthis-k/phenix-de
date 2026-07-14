import QtQml
import qs.services
import "tree"
import "../logic/"
import "../logic/EvaluationProfiles.js" as EvalProfiles

LauncherBackendBase {
    readonly property var tracer: Logger.scope("launcher.treeBackend", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.treeBackend", { category: "launcher" })
    id: root

    default property list<QtObject> nodes

    property var treeRoots: []
    property var compositeRootCache: null
    property string compositeRootCacheKey: ""
    property bool prewarmCompositeRootCache: true
    property bool dynamicCompositeRoot: false

    property TreeNodeDefaults nodeDefaults: TreeNodeDefaults {
        defaultPriority: root.priority || 0
    }
    property SwitchActionInferer switchInferer: SwitchActionInferer {
        nodeFactory: root
    }
    property TreeNodeMaterializer nodeMaterializer: TreeNodeMaterializer {
        defaults: root.nodeDefaults
        switchInferer: root.switchInferer
        nodeFactory: root
        backendId: root.backendId
        priority: root.priority || 0
        helpIcon: root.helpIcon || "system-search"
    }
    property ActionPathResolver actionPathResolver: ActionPathResolver {
        treeRootsProvider: root.effectiveTreeRoots
    }

    Component.onCompleted: {
        if (root.prewarmCompositeRootCache)
            Qt.callLater(root.prewarmCompositeRoot);
    }

    function prewarmCompositeRoot() {
        if (root.enabled) {
            tracer.trace("prewarmCompositeRoot", function() { return { backendId: root.backendId }; });
            root.rootNode({ raw: "" }, {});
        }
    }

    function _rootNode(query, context) {
        const roots = root.effectiveTreeRoots();
        const cacheKey = root.backendId + ":" + roots.length;
        if (!root.dynamicCompositeRoot && root.compositeRootCache && root.compositeRootCacheKey === cacheKey)
            return root.compositeRootCache;

        root.compositeRootCacheKey = cacheKey;
        const compositeRoot = root.backendRootDto(roots.map(function(node) { return root.nodeMaterializer.compositeNode(node, []); }), {
            tags: [root.backendId],
            evaluationProfile: EvalProfiles.backendRootProfile()
        });
        IndexBuilder.buildSearchIndex(compositeRoot);
        if (!root.dynamicCompositeRoot)
            root.compositeRootCache = compositeRoot;
        tracer.trace("rootNode", function() { return { backendId: root.backendId, rootsCount: roots.length, cacheHit: root.compositeRootCacheKey === cacheKey }; });
        return compositeRoot;
    }

    readonly property var rootNode: prof.fn("rootNode", _rootNode)

    function invalidateCompositeRootCache() {
        tracer.trace("invalidateCompositeRootCache", function() { return { backendId: root.backendId }; });
        root.compositeRootCache = null;
        root.compositeRootCacheKey = "";
    }

    function effectiveTreeRoots() {
        var roots = [];
        for (var i = 0; i < (root.treeRoots || []).length; i += 1)
            roots.push(materializeTreeNode(root.treeRoots[i]));
        for (var ni = 0; ni < root.nodes.length; ni += 1) {
            var node = root.nodes[ni];
            if (node && typeof node.toTreeObject === "function")
                roots.push(node.toTreeObject());
        }
        return roots.filter(Boolean);
    }

    function materializeTreeNode(node) {
        return node && typeof node.toTreeObject === "function" ? node.toTreeObject() : node;
    }

    function defaultAction(node) {
        return root.nodeDefaults.defaultAction(node);
    }

    function behaviorForNode(node, children) {
        return root.nodeDefaults.behaviorForNode(node, children, {});
    }

    function categoryGroupBehavior(options) {
        return root.nodeDefaults.categoryGroupBehavior(options);
    }

    function switchActionMap(node, children) {
        return root.switchInferer.switchActionMap(node, children);
    }

    function actionDtosForSwitchActions(switchActions) {
        return root.switchInferer.actionDtosForSwitchActions(switchActions);
    }

    function originalNodeForPath(commandPath) {
        return root.actionPathResolver.originalNodeForPath(commandPath);
    }

    function actionPayloadForPath(commandPath, actionId) {
        return root.actionPathResolver.actionPayloadForPath(commandPath, actionId);
    }

    function actionPayload(actionId, props, executor) {
        var payload = Object.assign({ actionId: actionId }, props || {});
        if (executor)
            payload.execute = executor;
        return payload;
    }

    function actionNode(options) {
        var opts = options || {};
        var actionId = opts.actionId || opts.id || "run";
        return {
            id: opts.id || actionId,
            aliases: opts.aliases || [],
            keywords: opts.keywords || [],
            title: opts.title || opts.id || actionId,
            subtitle: opts.subtitle || "",
            icon: opts.icon || root.helpIcon || "system-run",
            iconColor: opts.iconColor || null,
            action: root.actionPayload(actionId, opts.actionProps || {}, opts.execute),
            dangerous: !!opts.dangerous,
            risk: opts.risk || null,
            behavior: opts.behavior || null,
            children: opts.children || []
        };
    }
}
