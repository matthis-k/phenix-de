import QtQml
import qs.services
import "../" as Launcher
import "../logic/"

QtObject {
    property string policyId
    property string factor: "auto"

    readonly property var tracer: Logger.scope("policy.descendantBoost", { category: "policy" })
    readonly property var prof: Profiler.scope("policy.descendantBoost", { category: "policy" })

    function policyApply(node, query, ctx, evaluatedChildren, scores, specArgs) {
        tracer.trace("policyApply", function() { return { policyId: policyId, nodeId: node?.id, childCount: evaluatedChildren ? evaluatedChildren.length : 0 }; });
        var directiveActive = !!(ctx.directive && ctx.directive.active);
        var ownScore = scores ? scores.ownScore || 0 : 0;

        var retained = (evaluatedChildren || []).filter(function(c) {
            return c.candidate || c.visible || ctx.showHidden;
        });

        var bestChildScore = 0;
        var bestChildMatchDepth = 9999;
        for (var b = 0; b < retained.length; b += 1) {
            if (retained[b].visible || ctx.showHidden) {
                if (retained[b].score > bestChildScore + 0.0001) {
                    bestChildScore = retained[b].score;
                    bestChildMatchDepth = (retained[b].matchDepth === undefined ? 0 : retained[b].matchDepth) + 1;
                } else if (Math.abs(retained[b].score - bestChildScore) <= 0.0001) {
                    bestChildMatchDepth = Math.min(bestChildMatchDepth, (retained[b].matchDepth === undefined ? 0 : retained[b].matchDepth) + 1);
                }
            }
        }
        if (bestChildScore <= 0)
            return 0;

        var effectiveFactor = specArgs && specArgs.factor !== undefined
            ? Tokenize.clamp(Number(specArgs.factor), 0, 1)
            : factor;

        var depthPenalty = bestChildMatchDepth < 9999 ? Math.pow(0.92, bestChildMatchDepth) : 1;
        var factorVal;
        if (effectiveFactor !== "auto") {
            factorVal = Tokenize.clamp(parseFloat(effectiveFactor), 0, 1);
            factorVal = isFinite(factorVal) ? factorVal : 0.28;
        } else {
            factorVal = node.switchActions ? (ownScore > 0 ? 1 : 0.82)
                : node.kind === "backend" ? 0.82
                : node.behavior && node.behavior.filterable ? 1.0
                : 0.28;
        }

        var result = bestChildScore * depthPenalty * factorVal;
        tracer.trace("policyApply.result", function() { return { policyId: policyId, nodeId: node?.id, bestChildScore: bestChildScore, depthPenalty: depthPenalty, factor: factorVal, result: result }; });
        return result;
    }

    Component.onCompleted: {
        Launcher.PolicyRegistry.registerBoost(policyId, policyApply);
    }
}
