// PolicyChain + DecisionDecider invariants — loadable via newshell-runtime or dev shell
// Verifies:
// 1. Policy priority from spec affects normalization
// 2. Trace preservation: evaluated entries not overwritten
// 3. DecisionTrace.policy() preserves nonzero priority
// 4. DecisionDecider is used for structural decisions (not first-wins)
// 5. best-wins handles numeric vs structural decisions
// 6. Trace aggregate exists after runDecisionPolicies path
//
// Usage: newshell ipc call debugPolicies '{"check":"policy-chain-invariants"}'

import QtQml
import Quickshell
import qs.services
import "../logic/PolicyChain.qml"
import "../logic/DecisionTrace.qml"
import "../logic/DecisionDecider.qml"

QtObject {
    readonly property var tracer: Logger.scope("test.policyChain", { category: "test" })

    function result(ok, label, detail) {
        return { ok: ok, label: label, detail: detail || "" };
    }

    function runAll() {
        var results = [];
        results.push(testPriorityFromSpec());
        results.push(testPriorityFromResult());
        results.push(testTieBreakFirst());
        results.push(testDeciderHighestPriority());
        results.push(testDeciderCustom());
        results.push(testDecisionTracePriority());
        results.push(testNormalizeReasons());
        results.push(testNormalizeDecisionField());
        results.push(testDeciderForStructural());
        results.push(testBestWinsNumeric());
        results.push(testBestWinsStructural());
        results.push(testBestWinsNonNumeric());
        results.push(testAccumulateVotesPreservesMetadata());
        results.push(testStructuralPolicyPriority());
        results.push(testTiePreservesFirst());
        results.push(testTraceAggregate());
        results.push(testNoTraceOverwrite());
        results.push(testPriorityChangesDecision());
        return { name: "PolicyChain", results: results };
    }

    function testPriorityFromSpec() {
        // [["policy-a", {}, 10], ["policy-b", {}, 80]] with highest-priority/best-wins
        // must select "policy-b" even when policy result has no priority
        var result = PolicyChain.run([
            ["policy-a", {}, 10],
            ["policy-b", {}, 80]
        ], function(name, spec) {
            if (name === "policy-a") return { decision: { value: 1 } };
            if (name === "policy-b") return { decision: { value: 2 } };
            return null;
        }, "best-wins");

        var ok = result && result.policy === "policy-b" && result.priority === 80;
        return result(ok, "priority-from-spec", ok ? "Selected policy-b (priority 80)" : "Selected " + (result ? result.policy : "none") + " (priority " + (result ? result.priority : 0) + ")");
    }

    function testPriorityFromResult() {
        // Priority from result overrides spec priority
        var result = PolicyChain.run([
            ["policy-a", {}, 10]
        ], function(name, spec) {
            return { decision: { value: 1 }, priority: 50 };
        }, "best-wins");

        var ok = result && result.priority === 50;
        return result(ok, "priority-from-result", ok ? "Priority 50 from result" : "Priority " + (result ? result.priority : 0));
    }

    function testTieBreakFirst() {
        // Same priority preserves profile order (first wins)
        var result = PolicyChain.run([
            ["policy-a", {}, 50],
            ["policy-b", {}, 50]
        ], function(name, spec) {
            if (name === "policy-a") return { decision: { value: 1 } };
            if (name === "policy-b") return { decision: { value: 2 } };
            return null;
        }, "first-wins");

        var ok = result && result.policy === "policy-a";
        return result(ok, "tie-break-first-wins", ok ? "policy-a selected (first in profile)" : "policy-b selected");
    }

    function testDeciderHighestPriority() {
        var votes = [
            { decision: { value: 1 }, priority: 10, policy: "policy-a", reasons: [] },
            { decision: { value: 2 }, priority: 80, policy: "policy-b", reasons: [] },
            { decision: { value: 3 }, priority: 50, policy: "policy-c", reasons: [] }
        ];
        var decider = DecisionDecider.reduce("test-kind", votes, { mode: "highest-priority" });
        var ok = decider && decider.selectedPolicy === "policy-b" && decider.priority === 80;
        return result(ok, "decider-highest-priority", ok ? "policy-b selected (priority 80)" : "Selected " + (decider ? decider.selectedPolicy : "none"));
    }

    function testDeciderCustom() {
        var votes = [
            { decision: { value: "a" }, priority: 10, policy: "policy-a", reasons: [] },
            { decision: { value: "b" }, priority: 80, policy: "policy-b", reasons: [] }
        ];
        var decider = DecisionDecider.reduce("test-kind", votes, {
            mode: "custom",
            custom: function(v, ctx) {
                for (var i = 0; i < v.length; i += 1) {
                    if (v[i].policy === "policy-a") return v[i];
                }
                return null;
            }
        });
        var ok = decider && decider.selectedPolicy === "policy-a";
        return result(ok, "decider-custom", ok ? "policy-a selected via custom reducer" : "Selected " + (decider ? decider.selectedPolicy : "none"));
    }

    function testDecisionTracePriority() {
        // Verify DecisionTrace.policy() preserves nonzero priority from vote object
        var ev = { node: { id: "test-node" } };
        var ctx = { _policyTrace: {} };
        var vote = { decision: { value: true }, priority: 75, policy: "test-policy", reasons: [{ code: "test", text: "test" }] };
        DecisionTrace.policy(ev, ctx, "expand", vote, vote.decision, "selected", [{ code: "test", text: "test" }]);

        var trace = ctx._policyTrace["test-node"];
        var ok = trace && trace.expand && trace.expand.evaluated.length === 1 && trace.expand.evaluated[0].priority === 75;
        var actual = trace && trace.expand ? trace.expand.evaluated[0].priority : 0;
        return result(ok, "trace-priority", ok ? "Priority 75 preserved in trace" : "Got priority " + actual);
    }

    function testNormalizeReasons() {
        var r = PolicyChain.normalizePolicyResult({
            decision: { value: true },
            reasons: [{ code: "test", text: "test reason" }]
        }, null);
        var ok = r && r.reasons && r.reasons.length === 1 && r.reasons[0].code === "test";
        return result(ok, "normalize-reasons-array", ok ? "Reasons array preserved" : "Got " + (r ? JSON.stringify(r.reasons) : "null"));
    }

    function testNormalizeDecisionField() {
        var r = PolicyChain.normalizePolicyResult({
            decision: { expand: true, maxChildren: 8 }
        }, { name: "expand-on-trailing-space", kind: "expand" });
        var ok = r && r.decision && r.decision.expand === true && r.decision.maxChildren === 8 && r.policy === "expand-on-trailing-space";
        return result(ok, "normalize-decision-field", ok ? "Decision field extracted, policy attached" : "Got " + (r ? JSON.stringify(r) : "null"));
    }

    function testDeciderForStructural() {
        // Verify that structural decision kinds use DecisionDecider (not first-wins in PolicyChain)
        // Two expand policy votes, higher priority must win
        var votes = [
            { decision: { expand: true, maxChildren: 4 }, priority: 0, policy: "expand-on-trailing-space", reasons: [] },
            { decision: { expand: true, includeAllChildren: true, minScore: 0.02 }, priority: 100, policy: "implicit-direct-expand", reasons: [] }
        ];
        var reduced = DecisionDecider.reduce("expand", votes, { mode: "highest-priority", tieBreak: "first" });
        var ok = reduced && reduced.selectedPolicy === "implicit-direct-expand" && reduced.priority === 100 && reduced.decision.includeAllChildren === true;
        return result(ok, "decider-for-structural", ok ? "Direct expand wins via highest-priority (100 > 0)" : "Selected " + (reduced ? reduced.selectedPolicy : "none") + " at priority " + (reduced ? reduced.priority : 0));
    }

    function testBestWinsNumeric() {
        // best-wins with numeric decisions: highest value at same priority wins
        var votes = [
            { decision: 0.5, priority: 50, policy: "policy-a", reasons: [] },
            { decision: 0.8, priority: 50, policy: "policy-b", reasons: [] }
        ];
        var reduced = DecisionDecider.reduce("boost", votes, { mode: "best-wins", tieBreak: "first" });
        var ok = reduced && reduced.selectedPolicy === "policy-b" && reduced.decision === 0.8;
        return result(ok, "best-wins-numeric", ok ? "policy-b wins (0.8 > 0.5 at same priority)" : "Selected " + (reduced ? reduced.selectedPolicy : "none"));
    }

    function testBestWinsStructural() {
        // best-wins with structural (object) decisions: falls back to highest-priority
        var votes = [
            { decision: { expand: true, maxChildren: 4 }, priority: 0, policy: "expand-a", reasons: [] },
            { decision: { expand: true, maxChildren: 8 }, priority: 80, policy: "expand-b", reasons: [] }
        ];
        var reduced = DecisionDecider.reduce("expand", votes, { mode: "best-wins", tieBreak: "first" });
        // best-wins with non-numeric decision should fall back to priority comparison
        var ok = reduced && reduced.selectedPolicy === "expand-b" && reduced.priority === 80;
        return result(ok, "best-wins-structural", ok ? "expand-b wins via higher priority fallback" : "Selected " + (reduced ? reduced.selectedPolicy : "none"));
    }

    function testTraceAggregate() {
        // Verify trace has evaluated + aggregate + final sections after runDecisionPolicies path
        var ev = { node: { id: "trace-test" } };
        var ctx = { _policyTrace: {} };
        var vote1 = { decision: { expand: true }, priority: 10, policy: "policy-a", kind: "expand", reasons: [{ code: "test1", text: "test" }] };
        var vote2 = { decision: { expand: true, includeAllChildren: true }, priority: 50, policy: "policy-b", kind: "expand", reasons: [{ code: "test2", text: "test" }] };

        DecisionTrace.initPolicyTrace(ev, ctx);
        DecisionTrace.policyVote(ev, ctx, "expand", vote1, "accumulated");
        DecisionTrace.policyVote(ev, ctx, "expand", vote2, "accumulated");

        var reduced = DecisionDecider.reduce("expand", [vote1, vote2], { mode: "highest-priority", tieBreak: "first" });
        DecisionTrace.aggregate(ev, ctx, "expand", "highest-priority", {
            selectedPolicy: reduced.selectedPolicy,
            priority: reduced.priority,
            decision: reduced.decision
        }, reduced.reasons || []);
        DecisionTrace.final(ev, ctx, "expand", { expand: true, children: 3 }, [{ code: "expand_done", text: "expanded" }]);

        var trace = ctx._policyTrace["trace-test"];
        var hasEvaluated = trace && trace.expand && trace.expand.evaluated && trace.expand.evaluated.length === 2;
        var hasAggregate = trace && trace.expand && trace.expand.aggregate !== null;
        var hasFinal = trace && trace.expand && trace.expand.final !== null;
        var aggregateResult = trace && trace.expand && trace.expand.aggregate && trace.expand.aggregate.result;
        var aggregateHasPriority = aggregateResult && aggregateResult.priority === 50;
        var ok = hasEvaluated && hasAggregate && hasFinal && aggregateHasPriority;
        return result(ok, "trace-aggregate", ok ? "Trace has evaluated (" + (trace.expand.evaluated.length) + "), aggregate (" + (trace.expand.aggregate.strategy) + "), and final" : "evaluated=" + hasEvaluated + " aggregate=" + hasAggregate + " final=" + hasFinal);
    }

    function testNoTraceOverwrite() {
        // Verify aggregate/final do not overwrite evaluated entries
        var ev = { node: { id: "no-overwrite" } };
        var ctx = { _policyTrace: {} };
        var vote = { decision: { expand: true }, priority: 10, policy: "test-policy", kind: "expand", reasons: [{ code: "test", text: "test" }] };

        DecisionTrace.initPolicyTrace(ev, ctx);
        DecisionTrace.policyVote(ev, ctx, "expand", vote, "accumulated");
        DecisionTrace.aggregate(ev, ctx, "expand", "highest-priority", { selectedPolicy: "test-policy", priority: 10, decision: vote.decision }, vote.reasons);
        DecisionTrace.final(ev, ctx, "expand", { expand: true, children: 1 }, [{ code: "done", text: "done" }]);

        var trace = ctx._policyTrace["no-overwrite"];
        var evaluatedCount = trace && trace.expand && trace.expand.evaluated.length;
        var ok = evaluatedCount === 1;
        return result(ok, "no-trace-overwrite", ok ? "Evaluated entries preserved after aggregate+final (" + evaluatedCount + ")" : "Evaluated count changed: " + evaluatedCount);
    }

    function testPriorityChangesDecision() {
        // Changing priority must change which expand policy is selected
        // This would fail if ResultShaping still used first-wins
        var votes = [
            { decision: { expand: true, maxChildren: 4 }, priority: 10, policy: "expand-limited", reasons: [] },
            { decision: { expand: true, includeAllChildren: true }, priority: 80, policy: "expand-all", reasons: [] }
        ];
        var reduced = DecisionDecider.reduce("expand", votes, { mode: "highest-priority", tieBreak: "first" });
        var defaultSelected = reduced && reduced.selectedPolicy;

        // Swap priorities
        votes = [
            { decision: { expand: true, maxChildren: 4 }, priority: 80, policy: "expand-limited", reasons: [] },
            { decision: { expand: true, includeAllChildren: true }, priority: 10, policy: "expand-all", reasons: [] }
        ];
        var swapped = DecisionDecider.reduce("expand", votes, { mode: "highest-priority", tieBreak: "first" });
        var swappedSelected = swapped && swapped.selectedPolicy;

        var ok = defaultSelected !== swappedSelected && swappedSelected === "expand-limited";
        return result(ok, "priority-changes-decision", ok ? "Priority changes selection: " + defaultSelected + " -> " + swappedSelected : "Same selection: " + defaultSelected + " / " + swappedSelected);
    }

    function testAccumulateVotesPreservesMetadata() {
        // accumulate-votes must return full normalized results, not just .value
        var chainResult = PolicyChain.run([
            { name: "retain-parent-when", args: { condition: "own-match" }, priority: 80 },
            { name: "retain-always", priority: 50 }
        ], function(name, spec) {
            if (name === "retain-parent-when")
                return { decision: { retain: true }, priority: 80 };
            if (name === "retain-always")
                return { decision: { retain: true } };
            return null;
        }, "accumulate-votes");

        var votes = chainResult && chainResult.decision ? chainResult.decision : [];
        var ok = votes.length === 2
            && votes[0].policy === "retain-parent-when"
            && votes[0].priority === 80
            && votes[0].decision.retain === true
            && votes[1].policy === "retain-always"
            && votes[1].decision.retain === true;
        return result(ok, "accumulate-votes-preserves-metadata", ok ? "Votes preserve policy, priority, decision" : "Got " + (votes ? votes.length : 0) + " votes: " + JSON.stringify(votes));
    }

    function testStructuralPolicyPriority() {
        // Two structural votes with different priorities; higher priority must win
        var votes = [
            { decision: { retain: false }, priority: 30, policy: "retain-never", kind: "retainParent", reasons: [] },
            { decision: { retain: true }, priority: 80, policy: "retain-parent-when", kind: "retainParent", reasons: [{ code: "test", text: "test" }] }
        ];
        var reduced = DecisionDecider.reduce("retainParent", votes, { mode: "highest-priority", tieBreak: "first" });
        var ok = reduced && reduced.selectedPolicy === "retain-parent-when" && reduced.priority === 80 && reduced.decision.retain === true;
        return result(ok, "structural-policy-priority", ok ? "retain-parent-when wins (80 > 30)" : "Selected " + (reduced ? reduced.selectedPolicy : "none") + " at priority " + (reduced ? reduced.priority : 0));
    }

    function testBestWinsNonNumeric() {
        // best-wins with non-numeric decisions must not compare object decisions
        var result = PolicyChain.run([
            { name: "policy-a", priority: 50 },
            { name: "policy-b", priority: 50 }
        ], function(name, spec) {
            if (name === "policy-a") return { decision: { x: 1 } };
            if (name === "policy-b") return { decision: { x: 2 } };
            return null;
        }, "best-wins");

        // Same priority, first should win (no object comparison crash or unpredictable selection)
        var ok = result && result.policy === "policy-a";
        return result(ok, "best-wins-non-numeric", ok ? "policy-a wins (first at tie)" : "Selected " + (result ? result.policy : "none"));
    }

    function testTiePreservesFirst() {
        // Equal priority should preserve profile order (first wins)
        var votes = [
            { decision: { expand: true, maxChildren: 4 }, priority: 50, policy: "expand-a", reasons: [] },
            { decision: { expand: true, includeAllChildren: true }, priority: 50, policy: "expand-b", reasons: [] }
        ];
        var reduced = DecisionDecider.reduce("expand", votes, { mode: "highest-priority", tieBreak: "first" });
        var ok = reduced && reduced.selectedPolicy === "expand-a";
        return result(ok, "tie-preserves-first", ok ? "expand-a wins (first at tie)" : "Selected " + (reduced ? reduced.selectedPolicy : "none"));
    }
}
