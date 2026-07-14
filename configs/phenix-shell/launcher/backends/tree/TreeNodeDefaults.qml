import QtQml
import qs.services
import "../../logic/EvaluationProfiles.js" as EvalProfiles

QtObject {
    id: root

    readonly property var tracer: Logger.scope("backend.tree.nodeDefaults", { category: "backend" })
    readonly property var prof: Profiler.scope("backend.tree.nodeDefaults", { category: "backend" })

    property var defaultEvaluationProfile: EvalProfiles.defaultNodeProfile()

    property var switchProfile: EvalProfiles.switchProfile({
        retainParent: []
    })

    property var defaultPriority: 0

    function groupProfile(options) {
        var opts = options || {};
        tracer.trace("groupProfile", function() { return { hasOptions: !!options }; });
        return EvalProfiles.groupProfile({
            strategies: opts.strategies !== undefined ? opts.strategies : ["exact", "prefix", "compact", "substring", "acronym", "fuzzy", "semantic", "usage", "recency"],
            evidence: opts.evidence !== undefined ? opts.evidence : ["field-match", "switch-action", "semantic", "token-claim", "usage", "recency"],
            boost: opts.boost,
            childVisible: opts.childVisible,
            tokenFlow: opts.tokenFlow,
            takeoverRequest: opts.takeoverRequest,
            takeoverAccept: opts.takeoverAccept,
            expand: opts.expand,
            retainParent: opts.retainParent,
            defaultAction: opts.defaultAction,
            riskGate: opts.riskGate,
            fields: opts.fields,
            scorePolicy: opts.scorePolicy
        });
    }

    function leafProfile(options) {
        var opts = options || {};
        tracer.trace("leafProfile", function() { return { hasOptions: !!options }; });
        return EvalProfiles.leafProfile({
            strategies: opts.strategies,
            evidence: opts.evidence,
            boost: opts.boost,
            childVisible: opts.childVisible,
            tokenFlow: opts.tokenFlow,
            defaultAction: opts.defaultAction,
            riskGate: opts.riskGate,
            fields: opts.fields,
            scorePolicy: opts.scorePolicy
        });
    }

    function isGroupTemplate(node) {
        var result = node && (node.template === "action-group" || node.template === "flat-action-group" || node.template === "switch");
        tracer.trace("isGroupTemplate", function() { return { nodeId: node?.id, result: result }; });
        return result;
    }

    function behaviorForNode(node, children, extra) {
        if (node.behavior)
            return Object.assign({}, extra || {}, node.behavior);
        return extra || {};
    }

    function defaultAction(node) {
        return node.defaultAction || node.action || null;
    }
}
