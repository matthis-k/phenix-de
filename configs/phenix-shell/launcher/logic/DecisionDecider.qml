pragma Singleton
import QtQml
import Quickshell
import qs.services
import "DecisionSelection.js" as DecisionSelection

// Reducer for normalized policy votes.
// Pipeline: decision kind → decider → policy votes → final decision
Singleton {
    readonly property var prof: Profiler.scope("launcher.decisionDecider", { category: "launcher" })
    readonly property var tracer: Logger.scope("launcher.decisionDecider", { category: "launcher" })

    function reduce(kind, votes, options) {
        tracer.trace("reduce", function() { return { kind: kind, voteCount: (votes || []).length, mode: (options && options.mode) || "highest-priority" }; });
        options = options || {};
        var mode = options.mode || "highest-priority";
        var tieBreak = options.tieBreak || "first";

        var filtered = [];
        for (var i = 0; i < (votes || []).length; i += 1) {
            if (votes[i] !== null && votes[i] !== undefined)
                filtered.push(votes[i]);
        }

        var selected = null;

        switch (mode) {
        case "highest-priority":
            selected = DecisionSelection.highestPriority(filtered, tieBreak);
            break;
        case "first-wins":
            selected = filtered.length > 0 ? filtered[0] : null;
            break;
        case "best-wins":
            selected = DecisionSelection.best(filtered, tieBreak);
            break;
        case "accumulate":
            return {
                kind: kind,
                decision: filtered,
                selectedPolicy: "",
                priority: 0,
                reasons: [{ code: "accumulated", text: "All " + filtered.length + " votes accumulated" }],
                votes: filtered
            };
        case "all-and": {
            var allTrue = filtered.every(function(v) { return v.decision === true; });
            return {
                kind: kind,
                decision: allTrue,
                selectedPolicy: "",
                priority: 0,
                reasons: [{ code: "all_and", text: allTrue ? "All votes true" : "Not all votes true" }],
                votes: filtered
            };
        }
        case "all-or": {
            var anyTrue = filtered.some(function(v) { return v.decision === true; });
            return {
                kind: kind,
                decision: anyTrue,
                selectedPolicy: "",
                priority: 0,
                reasons: [{ code: "all_or", text: anyTrue ? "Some votes true" : "No votes true" }],
                votes: filtered
            };
        }
        default:
            if (typeof options.custom === "function")
                selected = options.custom(filtered, options.context);
            else
                selected = DecisionSelection.highestPriority(filtered, tieBreak);
        }

        return {
            kind: kind,
            decision: selected ? selected.decision : null,
            selectedPolicy: selected ? selected.policy : "",
            priority: selected ? selected.priority : 0,
            reasons: selected ? (selected.reasons || []).slice() : [],
            votes: filtered
        };
    }

    function highestPriority(votes, tieBreak) {
        return DecisionSelection.highestPriority(votes, tieBreak);
    }

    function bestWins(votes, tieBreak) {
        return DecisionSelection.best(votes, tieBreak);
    }

    function toDebug(result) {
        if (!result) return null;
        return {
            kind: result.kind || "",
            decision: result.decision,
            selectedPolicy: result.selectedPolicy || "",
            priority: result.priority || 0,
            reasons: (result.reasons || []).slice(),
            voteCount: (result.votes || []).length
        };
    }
}
