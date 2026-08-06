import QtQml
import qs.services
import "../../logic/EntryData.js" as EntryData

QtObject {
    id: root

    readonly property var tracer: Logger.scope("backend.tree.nodeMaterializer", { category: "backend" })
    readonly property var prof: Profiler.scope("backend.tree.nodeMaterializer", { category: "backend" })

    property var defaults: null
    property var switchInferer: null
    property var nodeFactory: null
    property string backendId: ""
    property var priority: 0
    property var helpIcon: "system-search"

    function compositeNode(node, path) {
        tracer.trace("compositeNode", function() { return { nodeId: node?.id, pathLen: (path || []).length }; });
        const display = EntryData.displayFor(node);
        const match = EntryData.matchFor(node);
        const semanticTerms = root._semanticTermsForNode(display, match);
        const canonicalMatch = Object.assign({}, match, { semanticTerms: semanticTerms });
        const children = (node.children || []).map(function(child) {
            return root.compositeNode(child, path.concat([node]));
        });
        const action = defaults ? defaults.defaultAction(node) : null;
        const rawSwitchActions = node.switchActions || (node.switchState === undefined ? null : (switchInferer ? switchInferer.switchActionMap(node, children) : null));
        const switchActions = switchInferer ? switchInferer.actionDtosForSwitchActions(rawSwitchActions) : null;
        const kind = switchActions && children.length === 0 ? "switch" : (children.length > 0 || node.template === "action-group" || node.template === "flat-action-group") ? "action-group" : "desktop-action";
        const evaluationProfile = root._evaluationProfileForNode(node, canonicalMatch, !!rawSwitchActions, children.length > 0);
        const actions = switchActions
            ? [switchActions.toggle, switchActions.on, switchActions.off].filter(Boolean)
            : action ? [root._actionDto(action.actionId || action.id || "run", action.title || qsTr("Run"), action)] : [];
        if (switchActions && actions.length > 0)
            actions[0].default = true;

        const nodeBehavior = defaults ? defaults.behaviorForNode(node, children, {}) : {};
        const pathNodes = path.concat([node]);

        return root._makeNodeDto({
            id: root.backendId + ":" + pathNodes.map(root._nodeIdentity).join(":"),
            kind: kind,
            label: display.title,
            subtitle: display.subtitle,
            icon: display.icon || root.helpIcon || "system-search",
            iconColor: display.iconColor,
            display: display,
            match: canonicalMatch,
            aliases: canonicalMatch.aliases,
            keywords: canonicalMatch.keywords,
            tags: root._unique([root.backendId].concat(canonicalMatch.tags || []).filter(Boolean)),
            fieldWeights: canonicalMatch.fieldWeights,
            semanticBoostRequiresAny: canonicalMatch.semanticBoostRequiresAny,
            command: canonicalMatch.command || "",
            path: canonicalMatch.path || "",
            actionList: actions,
            switchActions: switchActions,
            switchState: node.switchState === undefined ? null : node.switchState,
            control: node.control || null,
            presentation: display,
            dangerous: !!node.dangerous,
            risk: node.risk || null,
            children: children,
            showWhenQueryEmpty: path.length === 0,
            usageCount: canonicalMatch.usageCount || 0,
            lastUsedDaysAgo: canonicalMatch.lastUsedDaysAgo === undefined ? 9999 : canonicalMatch.lastUsedDaysAgo,
            behavior: Object.assign({
                tokenPolicy: canonicalMatch.tokenPolicy ? canonicalMatch.tokenPolicy : canonicalMatch.aliases && canonicalMatch.aliases.length ? { tokens: canonicalMatch.aliases, weight: 0.62 } : null,
                displayPolicy: nodeBehavior.displayPolicy || null
            }, node.behavior || {}),
            semanticTerms: semanticTerms,
            evaluationProfile: evaluationProfile,
            meta: {
                action: action,
                commandPath: pathNodes.map(root._nodeIdentity),
                replaceQuery: node.replaceQuery || null
            }
        });
    }

    function _nodeIdentity(node) {
        if (!node)
            return "";
        var display = EntryData.displayFor(node);
        return node.id || display.title;
    }

    function _unique(items) {
        var out = [];
        for (var i = 0; i < (items || []).length; i += 1) {
            if (out.indexOf(items[i]) < 0)
                out.push(items[i]);
        }
        return out;
    }

    function _semanticTermsForNode(display, match) {
        tracer.trace("_semanticTermsForNode", function() { return { aliasCount: (match.aliases || []).length }; });
        if (match.semanticTerms && match.semanticTerms.length > 0)
            return match.semanticTerms.slice();
        const aliases = match.aliases || [];
        return aliases.map(function(alias) {
            return { triggers: [String(alias).toLowerCase()], matches: [String(alias).toLowerCase(), String(display.title || "").toLowerCase()], field: "semantic", score: 0.74, weight: 0.32 };
        });
    }

    function _actionDto(id, label, payload) {
        tracer.trace("_actionDto", function() { return { id: id, hasPayload: !!payload }; });
        return nodeFactory ? nodeFactory.actionDto(id, label, payload) : { id: id, label: label || id, icon: null, default: false, payload: payload || null };
    }

    function _evaluationProfileForNode(node, match, hasSwitchActions, hasChildren) {
        const hasExplicitProfile = !!match.evaluationProfile;

        if (hasExplicitProfile)
            return match.evaluationProfile;

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
