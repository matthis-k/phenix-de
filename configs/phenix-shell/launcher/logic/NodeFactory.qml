import QtQml
import qs.services
import "EvaluationProfiles.js" as EvalProfiles
import "EntryData.js" as EntryData

QtObject {
    id: root

    readonly property var tracer: Logger.scope("launcher.nodeFactory", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.nodeFactory", { category: "launcher" })

    function makeAction(id, label, payload) {
        tracer.trace("makeAction", function() { return { id: id, hasPayload: !!payload }; });
        return { id: id, label: label || id, icon: null, default: false, payload: payload || null };
    }

    function unique(items) {
        var out = [];
        for (var i = 0; i < (items || []).length; i += 1) {
            if (out.indexOf(items[i]) < 0)
                out.push(items[i]);
        }
        return out;
    }

    function makeNode(props) {
        tracer.trace("makeNode", function() { return { id: props?.id, label: props?.label, childCount: (props?.children || []).length }; });
        var node = props || {};
        if (node.__compositePrepared) return node;

        var runtimeTags = node.tags || [];
        var display = EntryData.displayFor(node);
        var match = EntryData.matchFor(node);

        node.id = node.id || "";
        node.backendId = node.backendId || "";
        node.kind = node.kind || "node";

        // Canonical data ownership. Flat fields remain derived compatibility
        // projections for the existing evaluator and delegates.
        node.display = display;
        node.match = match;
        node.label = display.title;
        node.title = display.title;
        node.subtitle = display.subtitle;
        node.icon = display.icon;
        node.iconColor = display.iconColor;
        node.aliases = match.aliases;
        node.keywords = match.keywords;
        node.tags = root.unique(runtimeTags.concat(match.tags || []));
        node.fieldWeights = match.fieldWeights;
        node.semanticTerms = match.semanticTerms;
        node.semanticBoostRequiresAny = match.semanticBoostRequiresAny;
        node.command = match.command || "";
        node.path = match.path || "";
        node.usageCount = match.usageCount || 0;
        node.lastUsedDaysAgo = match.lastUsedDaysAgo === undefined ? 9999 : match.lastUsedDaysAgo;
        node.evaluationProfile = match.evaluationProfile || EvalProfiles.defaultNodeProfile();

        node.children = node.children || node._children || [];
        node.behavior = node.behavior || {};
        node.actionList = node.actionList || [];
        node.meta = node.meta || node.metadata || {};
        for (var i = 0; i < node.children.length; i += 1) {
            node.children[i] = root.makeNode(node.children[i]);
            node.children[i].parent = node;
        }
        node.__compositePrepared = true;
        return node;
    }
}
