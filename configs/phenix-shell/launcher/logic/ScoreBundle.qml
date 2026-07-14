pragma Singleton
import QtQml
import Quickshell
import qs.services

Singleton {
    readonly property var prof: Profiler.scope("launcher.scoreBundle", { category: "launcher" })
    readonly property var tracer: Logger.scope("launcher.scoreBundle", { category: "launcher" })
    function makeScorePart(value, evidenceItems, query) {
        var covered = {};
        var missing = [];
        for (var ti = 0; ti < (query && query.tokens || []).length; ti += 1) {
            var tokenIndex = -1;
            for (var ei = 0; ei < (evidenceItems || []).length; ei += 1) {
                var e = evidenceItems[ei];
                var idxs = e.tokenIndex !== undefined ? [e.tokenIndex] : (e.tokenIndexes || []);
                for (var ii = 0; ii < idxs.length; ii += 1) {
                    if (idxs[ii] === ti) {
                        tokenIndex = ti;
                        break;
                    }
                }
                if (tokenIndex >= 0) break;
            }
            if (tokenIndex >= 0) covered[ti] = true;
            else missing.push(ti);
        }
        var total = Math.max(1, (query && query.tokens || []).length);
        return {
            value: value,
            evidence: evidenceItems || [],
            coverage: {
                coveredTokens: Object.keys(covered).map(Number),
                missingTokens: missing,
                coverageRatio: Object.keys(covered).length / total
            }
        };
    }

    function make(ownValue, inheritedValue, childrenValue, rankingValue, evidenceItems, query, groupValue, activationValue) {
        var ownScore = ownValue || 0;
        var inheritedScore = inheritedValue || 0;
        var childrenScore = childrenValue || 0;
        var ranking = rankingValue !== undefined ? rankingValue : Math.max(ownScore, inheritedScore, childrenScore);

        return {
            own: makeScorePart(ownScore, evidenceItems || [], query),
            inherited: makeScorePart(inheritedScore, [], query),
            children: makeScorePart(childrenScore, [], query),
            aggregate: makeScorePart(ranking, [], query),
            ranking: ranking,
            group: groupValue !== undefined ? groupValue : ownScore,
            activation: activationValue !== undefined ? activationValue : ownScore,
            confidence: computeConfidence(ownScore, evidenceItems, query)
        };
    }

    function _fromEvaluated(ev, query) {
        tracer.trace("fromEvaluated", function() { return { nodeId: ev && ev.node && ev.node.id, ownScore: ev && ev.ownScore }; });
        if (!ev) return null;
        var evidenceItems = (ev.ownEvidence || ev.evidence || []);
        var node = ev.node;
        var ownScore = ev.ownScore || 0;
        var group = ownScore;
        var activation = ownScore;
        if (node) {
            var hasActions = (node.actionList && node.actionList.length > 0) || !!node.switchActions;
            if (!hasActions)
                activation = 0;
            if ((node.children || []).length > 0 && ev.ownVisible)
                group = Math.min(1, group + 0.03);
        }
        return make(
            ownScore,
            ev.inheritedScore || 0,
            ev.descendantScore || 0,
            ev.score || 0,
            evidenceItems,
            query,
            group,
            activation
        );
    }
    readonly property var fromEvaluated: prof.fn("fromEvaluated", _fromEvaluated)

    function attachToEvaluated(ev, query) {
        if (!ev) return;
        ev.scoreBundle = fromEvaluated(ev, query);
        if (ev.children) {
            for (var i = 0; i < ev.children.length; i += 1)
                attachToEvaluated(ev.children[i], query);
        }
    }

    function computeConfidence(ownScore, evidenceItems, query) {
        if (!evidenceItems || !evidenceItems.length) return 0;
        var totalWeight = 0;
        for (var i = 0; i < evidenceItems.length; i += 1)
            totalWeight += evidenceItems[i].weight || evidenceItems[i].effective || 0;
        var maxPossible = (query && query.tokens || []).length || 1;
        return Math.min(1, totalWeight / maxPossible);
    }

    function toDebug(bundle) {
        if (!bundle) return null;
        return {
            own: { value: bundle.own.value, coverage: bundle.own.coverage.coverageRatio },
            inherited: { value: bundle.inherited.value, coverage: bundle.inherited.coverage.coverageRatio },
            children: { value: bundle.children.value },
            aggregate: { value: bundle.aggregate.value },
            ranking: bundle.ranking,
            group: bundle.group,
            activation: bundle.activation,
            confidence: bundle.confidence
        };
    }

    function applyToRow(row, bundle) {
        if (!row || !bundle) return row;
        row.scoreBundle = bundle;
        return row;
    }
}
