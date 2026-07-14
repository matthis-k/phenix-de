import QtQml
import qs.services
import "EvaluationProfiles.js" as EvalProfiles

QtObject {
    id: root

    readonly property var tracer: Logger.scope("launcher.nodeFactory", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.nodeFactory", { category: "launcher" })

    function makeAction(id, label, payload) {
        tracer.trace("makeAction", function() { return { id: id, hasPayload: !!payload }; });
        return { id: id, label: label || id, icon: null, default: false, payload: payload || null };
    }

    function makeNode(props) {
        tracer.trace("makeNode", function() { return { id: props?.id, label: props?.label, childCount: (props?.children || []).length }; });
        var node = props || {};
        if (node.__compositePrepared) return node;
        node.id = node.id || "";
        node.backendId = node.backendId || "";
        node.kind = node.kind || "node";
        node.label = node.label || node.title || "";
        node.title = node.label;
        node.subtitle = node.subtitle || "";
        node.icon = node.icon || null;
        node.iconColor = node.iconColor || null;
        node.children = node.children || node._children || [];
        node.aliases = node.aliases || [];
        node.keywords = node.keywords || [];
        node.tags = node.tags || [];
        node.fieldWeights = node.fieldWeights || {};
        node.behavior = node.behavior || {};
        node.semanticTerms = node.semanticTerms || [];
        node.semanticBoostRequiresAny = node.semanticBoostRequiresAny || [];
        node.command = node.command || "";
        node.path = node.path || "";
        node.usageCount = node.usageCount || 0;
        node.lastUsedDaysAgo = node.lastUsedDaysAgo === undefined ? 9999 : node.lastUsedDaysAgo;
        node.evaluationProfile = node.evaluationProfile || EvalProfiles.defaultNodeProfile();
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
