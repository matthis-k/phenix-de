import QtQml
import qs.services

QtObject {
    id: root

    readonly property var tracer: Logger.scope("backend.tree.nodeMaterializer", { category: "backend" })
    readonly property var prof: Profiler.scope("backend.tree.nodeMaterializer", { category: "backend" })

    property var defaults: null
    property var switchInferer: null
    property var nodeFactory: null
    property var backendId: ""
    property var priority: 0
    property var helpIcon: "system-search"

    function compositeNode(node, path) {
        tracer.trace("compositeNode", function() { return { nodeId: node?.id, pathLen: (path || []).length }; });
        const children = (node.children || []).map(function(child) {
            return root.compositeNode(child, path.concat([node]));
        });
        const action = defaults ? defaults.defaultAction(node) : null;
        const rawSwitchActions = node.switchActions || (node.switchState === undefined ? null : (switchInferer ? switchInferer.switchActionMap(node, children) : null));
        const switchActions = switchInferer ? switchInferer.actionDtosForSwitchActions(rawSwitchActions) : null;
        const kind = switchActions && children.length === 0 ? "switch" : (children.length > 0 || node.template === "action-group" || node.template === "flat-action-group") ? "action-group" : "desktop-action";
        const evaluationProfile = root._evaluationProfileForNode(node, !!rawSwitchActions, children.length > 0);
        const actions = switchActions
            ? [switchActions.toggle, switchActions.on, switchActions.off].filter(Boolean)
            : action ? [root._actionDto(action.actionId || action.id || "run", action.title || qsTr("Run"), action)] : [];
        if (switchActions && actions.length > 0)
            actions[0].default = true;

        const nodeBehavior = defaults ? defaults.behaviorForNode(node, children, {}) : {};

        return root._makeNodeDto({
            id: root.backendId + ":" + path.concat([node]).map(function(item) { return item.id || item.title; }).join(":"),
            kind: kind,
            label: node.title || node.id,
            subtitle: node.subtitle || "",
            icon: node.icon || root.helpIcon || "system-search",
            iconColor: node.iconColor || null,
            aliases: node.aliases || [],
            keywords: node.keywords || [],
            tags: [root.backendId, ""].filter(Boolean),
            actionList: actions,
            switchActions: switchActions,
            switchState: node.switchState === undefined ? null : node.switchState,
            control: node.control || null,
            presentation: node.presentation || null,
            dangerous: !!node.dangerous,
            risk: node.risk || null,
            children: children,
            showWhenQueryEmpty: path.length === 0,
            usageCount: node.usageCount || 0,
            lastUsedDaysAgo: node.lastUsedDaysAgo === undefined ? 9999 : node.lastUsedDaysAgo,
            behavior: Object.assign({
                tokenPolicy: node.tokenPolicy ? node.tokenPolicy : node.aliases && node.aliases.length ? { tokens: node.aliases, weight: 0.62 } : null,
                displayPolicy: nodeBehavior.displayPolicy || null
            }, node.behavior || {}),
            semanticTerms: root._semanticTermsForNode(node),
            evaluationProfile: evaluationProfile,
            meta: {
                action: action,
                commandPath: path.concat([node]).map(function(item) { return item.id || item.title; }),
                replaceQuery: node.replaceQuery || null
            }
        });
    }

    function _semanticTermsForNode(node) {
        tracer.trace("_semanticTermsForNode", function() { return { nodeId: node?.id, aliasCount: (node?.aliases || []).length }; });
        const aliases = node.aliases || [];
        return aliases.map(function(alias) {
            return { triggers: [String(alias).toLowerCase()], matches: [String(alias).toLowerCase(), String(node.title || "").toLowerCase()], field: "semantic", score: 0.74, weight: 0.32 };
        });
    }

    function _actionDto(id, label, payload) {
        tracer.trace("_actionDto", function() { return { id: id, hasPayload: !!payload }; });
        return nodeFactory ? nodeFactory.actionDto(id, label, payload) : { id: id, label: label || id, icon: null, default: false, payload: payload || null };
    }

    function _evaluationProfileForNode(node, hasSwitchActions, hasChildren) {
        const hasExplicitProfile = !!node.evaluationProfile;

        if (hasExplicitProfile)
            return node.evaluationProfile;

        if (hasSwitchActions && defaults)
            return defaults.switchProfile;

        if (hasChildren && defaults)
            return defaults.groupProfile();

        return defaults ? defaults.defaultEvaluationProfile : {
            mode: "generic+custom",
            strategies: ["exact", "prefix", "compact", "substring", "acronym", "fuzzy", "semantic", "usage", "recency"],
            scorePolicy: "default",
            profile: {}
        };
    }

    function _makeNodeDto(options) {
        tracer.trace("_makeNodeDto", function() { return { hasNodeFactory: !!nodeFactory, nodeId: options?.id }; });
        return nodeFactory ? nodeFactory.nodeDto(options) : options;
    }
}
