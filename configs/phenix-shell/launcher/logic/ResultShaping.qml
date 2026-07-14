pragma Singleton
import QtQml
import Quickshell
import qs.services
import "Tokenize.qml"
import "Evidence.qml"
import "Evaluate.qml"
import "PolicyChain.qml"
import "ResultSemantics.qml"
import "TakeoverEngine.qml"
import "DecisionTrace.qml"
import "DecisionDecider.qml"
import "CompositeSearchPolicyRegistry.js" as JsRegistry

Singleton {
    id: root
    readonly property var prof: Profiler.scope("launcher.shaping", { category: "launcher" })
    readonly property var tracer: Logger.scope("launcher.shaping", { category: "launcher" })

    function resultReason(result, fallback) {
        if (!result) return fallback || "";
        var r = result.reason;
        if (r) return r;
        if (result.reasons && result.reasons.length > 0)
            return result.reasons[0].text;
        return fallback || "";
    }

    function _shape(evaluatedRoot, state, ctx) {
        tracer.trace("shape", function() { return { rootId: evaluatedRoot && evaluatedRoot.node && evaluatedRoot.node.id, childCount: (evaluatedRoot && evaluatedRoot.children || []).length }; });
        var collected = [];

        function structuralDepth(ev) {
            return Math.max(0, Evaluate.collectParentChain(ev.node).length - 2);
        }

        function canInclude(ev) {
            if (ctx.directive && ctx.directive.active && !ev.allowed) return false;
            if (!(ev.visible || ctx.showHidden)) return false;
            if (ev.node.kind === "backend") return false;
            return true;
        }

        function makeShaped(ev, depth, sortScore, childEvs, forceInclude, options, placement, decision) {
            var acceptOwnScore = ev.ownScoreBase !== undefined ? ev.ownScoreBase > 0 : ev.ownScore > 0;
            if (ev.node.kind !== "root" && (forceInclude || canInclude(ev) || acceptOwnScore)) {
                collected.push({
                    ev: ev,
                    depth: depth,
                    sortScore: sortScore === undefined ? ev.score : sortScore,
                    childEvs: childEvs || [],
                    placement: placement || "standalone",
                    decision: decision || { placement: placement || "standalone", mode: "normal", showParent: true },
                    presentationHints: (decision && decision.presentationHints) || {},
                    options: options || {},
                    semantics: ResultSemantics.build(ev, decision || { placement: placement || "standalone", mode: "normal", showParent: true }, placement || "standalone", ctx)
                });
            }
        }

        function isDiscoverable(node) {
            var directive = ctx.directive;
            if (!directive || !directive.active) return false;
            if (!ctx.query.isEmpty) return false;
            var chain = Evaluate.collectParentChain(node);
            for (var i = 0; i < chain.length; i += 1) {
                var behavior = chain[i].behavior || {};
                if (behavior.displayPolicy && behavior.displayPolicy.discoverable) return true;
            }
            return false;
        }

        function collect(ev, depth, forceInclude) {
            if (ev.node.kind === "root") {
                for (var i = 0; i < ev.children.length; i += 1) collect(ev.children[i], depth + 1, forceInclude);
                return;
            }
            if (ev.node.kind === "backend") {
                for (var bi = 0; bi < ev.children.length; bi += 1) collect(ev.children[bi], depth, forceInclude);
                return;
            }
            if (!ev.visible && isDiscoverable(ev.node)) {
                makeShaped(ev, depth, 0, [], true, {}, "standalone", { placement: "standalone", mode: "normal", showParent: true });
                return;
            }
            var decision = decidePlacement(ev, ctx);
            DecisionTrace.placement(ev, ctx, decision);
            if (decision.mode === "flatten-all-children") {
                for (var ai = 0; ai < decision.children.length; ai += 1) {
                    var child = decision.children[ai];
                    if (child.children && child.children.length > 0)
                        collect(child, depth + 1, true);
                    else if (child.visible || child.score >= 0.02)
                        makeShaped(child, depth + 1, child.score, [], true, {}, "flattened", { placement: "flattened", mode: "flattened", showParent: true });
                }
                return;
            }
            if (decision.mode === "normal") {
                var hasBaseScore = ev.ownScoreBase !== undefined ? ev.ownScoreBase > 0 : ev.ownScore > 0;
                if (forceInclude || ev.ownVisible || hasBaseScore || (ev.children && ev.children.some(function(c) { return c.visible || c.score >= 0.02; }))) {
                    makeShaped(ev, depth, undefined, [], forceInclude, {}, "standalone", decision);
                }
                for (var n = 0; n < ev.children.length; n += 1) {
                    var nc = ev.children[n];
                    if (nc.visible || nc.score >= 0.02 || ctx.showHidden)
                        collect(nc, depth + 1, forceInclude);
                }
                return;
            }
            if (decision.showParent) {
                var childMaxScore = decision.children.length
                    ? Math.max.apply(null, decision.children.map(function(c) { return c.score; }))
                    : 0;
                var score = decision.mode === "nested-group"
                    ? Math.max(0, Math.max(ev.score, childMaxScore) - 0.015)
                    : ev.score;
                if (decision.mode === "nested-group") {
                    makeShaped(ev, depth, score, decision.children, forceInclude,
                        { suppressParentActions: !!decision.suppressParentActions, includeAllChildren: !!decision.includeAllChildren },
                        "nested-group", decision);
                    return;
                }
                if (decision.mode !== "group" || ev.ownScore > 0 || ev.ownVisible)
                    makeShaped(ev, depth, score, [], forceInclude, {}, decision.placement || "group", decision);
            }
            if (decision.mode === "group") return;
            if (decision.mode === "flatten-children") {
                for (var di = 0; di < decision.children.length; di += 1) {
                    var fc = decision.children[di];
                    if (fc.visible || fc.score >= 0.02)
                        collect(fc, depth, false);
                }
                return;
            }
            for (var ci = 0; ci < decision.children.length; ci += 1) {
                var cc = decision.children[ci];
                if (cc.visible || cc.score >= 0.02 || ctx.showHidden)
                    collect(cc, depth + 1, forceInclude);
            }
        }

        collect(evaluatedRoot, -1, false);

        collected.sort(function(a, b) {
            var delta = b.sortScore - a.sortScore;
            if (Math.abs(delta) > 0.0001) return delta;
            var structuralDepthDelta = structuralDepth(a.ev) - structuralDepth(b.ev);
            if (structuralDepthDelta !== 0) return structuralDepthDelta;
            return a.depth - b.depth;
        });

        tracer.info("shapeComplete", function() { return { collectedCount: collected.length, maxTreeDepth: ctx.maxTreeDepth >= 0 ? ctx.maxTreeDepth : 3 }; });
        return {
            shaped: collected,
            maxTreeDepth: ctx.maxTreeDepth >= 0 ? ctx.maxTreeDepth : 3
        };
    }

    readonly property var shape: prof.fn("shape", _shape)

    function runDecisionPolicies(ev, ctx, kind, names, registry, reducerOptions) {
        if (!names || names.length === 0) return null;
        DecisionTrace.initPolicyTrace(ev, ctx);
        var votes = [];
        var chainResult = PolicyChain.run(names, function(name, spec) {
            var policy = PolicyChain.lookupPolicy(registry, spec);
            if (!policy) return null;
            return policy.apply(ev, ctx, spec && spec.args);
        }, "accumulate-votes", function(tr) {
            DecisionTrace.policyVote(ev, ctx, kind, tr.returned, tr.effect);
        });
        votes = chainResult && chainResult.decision ? chainResult.decision : [];
        var opts = reducerOptions || { mode: "highest-priority", tieBreak: "first" };
        var reduced = DecisionDecider.reduce(kind, votes, opts);
        DecisionTrace.aggregate(ev, ctx, kind, opts.mode, {
            selectedPolicy: reduced.selectedPolicy,
            priority: reduced.priority,
            decision: reduced.decision
        }, reduced.reasons || []);
        return reduced;
    }

    function eligibleChildren(children, options) {
        var opts = options || {};
        var includeAll = opts.includeAllChildren === true;
        return (children || []).filter(function(c) {
            if (!c.allowed) return false;
            if (includeAll) return true;
            return c.visible || c.score >= (opts.minScore === undefined ? 0.25 : opts.minScore);
        }).sort(Evaluate.compareEvaluated);
    }

    function resolveNesting(ev, ctx) {
        var profile = (ev.node.evaluationProfile && ev.node.evaluationProfile.profile) || {};
        var nestingNames = profile.nesting || [];
        if (nestingNames.length === 0) return null;
        var reduced = runDecisionPolicies(ev, ctx, "nesting", nestingNames, JsRegistry.nesting, { mode: "highest-priority", tieBreak: "first" });
        return reduced && reduced.decision;
    }

    function directExpandDecision(ev, ctx) {
        if (!ev || !ev.children || ev.children.length === 0) return null;
        var tf = ev.tokenFlow;
        var hasResidual = tf && tf.passed && tf.passed.length > 0;
        var hasOwnMatch = ev.ownVisible || (ev.ownScore || 0) > 0;
        var trailing = ctx && ctx.query && ctx.query.lastTokenEmpty;
        if (!hasOwnMatch || !(trailing || hasResidual)) return null;

        var includeAll = trailing && !hasResidual;
        var minScore = trailing ? 0 : (hasResidual ? 0.02 : 0.25);

        return {
            decision: {
                expand: true,
                includeAllChildren: includeAll,
                minScore: minScore,
                promoteSingleResidual: hasResidual,
                childFilter: hasResidual ? "residual-label-contains" : null
            },
            priority: 100,
            policy: "implicit-direct-expand",
            kind: "expand",
            reasons: [{ code: "direct_expand", text: "Direct expand: " + (trailing ? "trailing space" : "residual tokens") }]
        };
    }

    function _decidePlacement(ev, ctx) {
        var placementTracer = tracer;
        placementTracer.trace("decidePlacement", function() { return { nodeId: ev.node.id, label: ev.node.label }; });
        var profile = (ev.node.evaluationProfile && ev.node.evaluationProfile.profile) || {};
        var expandNames = profile.expand || [];
        var retainNames = profile.retainParent || [];

        var takeoverClaims = ev.children && ev.children.length > 0
            ? TakeoverEngine.evaluateTakeoverRequests(ev, ev.children, ctx)
            : [];
        var takeoverDecision = takeoverClaims.length > 0
            ? TakeoverEngine.decideTakeover(ev, takeoverClaims, ctx)
            : null;

        DecisionTrace.initPolicyTrace(ev, ctx);
        if (takeoverClaims.length > 0) {
            DecisionTrace.policy(ev, ctx, "takeover", "takeover-claims", takeoverClaims.map(function(c) { return { claimantId: c.claimantId, kind: c.kind, strength: c.strength }; }), takeoverDecision && takeoverDecision.accepted ? "accepted" : "rejected", [{ code: "takeover_result", text: "accepted=" + (takeoverDecision && takeoverDecision.accepted) + " representation=" + (takeoverDecision && takeoverDecision.representation || "") }]);
        }
        if (takeoverDecision && takeoverDecision.accepted) {
            DecisionTrace.final(ev, ctx, "takeover", { accepted: true, representation: takeoverDecision.representation, retainParent: takeoverDecision.retainParent !== false, selectedOwnerId: takeoverDecision.selectedOwnerId }, [{ code: "takeover_accepted", text: "Takeover accepted: " + takeoverDecision.representation + " by " + (takeoverDecision.selectedOwnerId || "") }]);
        } else if (takeoverClaims.length > 0) {
            DecisionTrace.final(ev, ctx, "takeover", { accepted: false, reason: takeoverDecision ? takeoverDecision.reason : "no decision" }, [{ code: "takeover_rejected", text: "Takeover rejected: " + (takeoverDecision ? takeoverDecision.reason : "no decision") }]);
        }

        var nestingResult = resolveNesting(ev, ctx);

        function _d(obj) {
            return attachNesting(attachTakeover(obj, takeoverClaims, takeoverDecision), nestingResult, null);
        }

        // Evaluate retain decision once (used by all paths)
        var retainReduced = retainNames.length > 0
            ? runDecisionPolicies(ev, ctx, "retainParent", retainNames, JsRegistry.retainParent, { mode: "highest-priority", tieBreak: "first" })
            : null;
        var retainResult = retainReduced && retainReduced.decision;

        // 1. Takeover (still needed for parent-level promotion, but nesting can override)
        if (takeoverDecision && takeoverDecision.accepted) {
            var takeoverChildren = eligibleChildren(ev.children, {
                includeAllChildren: takeoverDecision.includeAllChildren === true,
                minScore: 0.02
            });
            if (takeoverChildren.length > 0) {
                var takeoverShowParent = takeoverDecision.retainParent !== false;
                if (takeoverDecision.representation === "flatten" || takeoverDecision.representation === "promote-child") {
                    // If nesting says this node should be self-group, override takeover
                    if (nestingResult && nestingResult.intent === "self-group") {
                        var nestingKids = nestingResult.includeChildren === "all" ? eligibleChildren(ev.children, { includeAllChildren: true })
                            : nestingResult.includeChildren === "matching" ? eligibleChildren(ev.children, { includeAllChildren: false, minScore: 0.05 })
                            : [];
                        if (nestingKids.length > 0) {
                            DecisionTrace.final(ev, ctx, "nesting", { override: "takeover", children: nestingKids.length }, [{ code: "nesting_override", text: resultReason(nestingResult, "nesting override") }]);
                            return _d({
                                placement: "nested-group",
                                mode: "nested-group",
                                showParent: true,
                                suppressParentActions: false,
                                children: nestingKids
                            });
                        }
                    }
                    DecisionTrace.final(ev, ctx, "takeover", { accepted: true, representation: "flatten", children: takeoverChildren.length }, [{ code: "takeover_flatten", text: "Takeover flattens to " + takeoverChildren.length + " children" }]);
                    return _d({
                        placement: takeoverChildren.length === 1 ? "promoted-child" : "flattened",
                        mode: takeoverChildren.length === 1 ? "flatten-children" : "flatten-all-children",
                        showParent: takeoverShowParent,
                        suppressParentActions: takeoverDecision.suppressParentActions || false,
                        children: takeoverChildren
                    });
                }
                if (takeoverDecision.representation === "nested-group") {
                    DecisionTrace.final(ev, ctx, "takeover", { accepted: true, representation: "nested-group", children: takeoverChildren.length }, [{ code: "takeover_nested_group", text: "Takeover nested-group with " + takeoverChildren.length + " children" }]);
                    return _d({
                        placement: "nested-group",
                        mode: "nested-group",
                        showParent: takeoverShowParent,
                        suppressParentActions: takeoverDecision.suppressParentActions || false,
                        children: takeoverChildren
                    });
                }
            }
        }

        // 2. Collect expand votes (direct expand + policy expand) and reduce via decider
        var expandVotes = [];

        // Direct expand vote (priority 100, always beats policy expand)
        var directVote = directExpandDecision(ev, ctx);
        if (directVote) {
            DecisionTrace.initPolicyTrace(ev, ctx);
            DecisionTrace.policyVote(ev, ctx, "expand", directVote, "candidate");
            expandVotes.push(directVote);
        }

        // Policy expand votes (accumulated via runDecisionPolicies)
        if (expandNames.length > 0) {
            var policyReduced = runDecisionPolicies(ev, ctx, "expand", expandNames, JsRegistry.expand, { mode: "highest-priority", tieBreak: "first" });
            if (policyReduced && policyReduced.decision && policyReduced.decision.expand)
                expandVotes.push(policyReduced);
        }

        // Reduce expand votes
        var expandReduced = expandVotes.length > 0
            ? DecisionDecider.reduce("expand", expandVotes, { mode: "highest-priority", tieBreak: "first" })
            : null;
        var expandResult = expandReduced && expandReduced.decision;
        var isDirectExpand = directVote !== null && expandReduced && expandReduced.selectedPolicy === "implicit-direct-expand";

        // Apply expand decision
        if (expandResult && expandResult.expand && ev.children && ev.children.length > 0) {
            var expandKids = eligibleChildren(ev.children, {
                includeAllChildren: !!expandResult.includeAllChildren,
                minScore: expandResult.minScore === undefined ? (expandResult.includeAllChildren ? 0 : 0.25) : expandResult.minScore
            });

            // Residual label filtering (direct expand only)
            if (isDirectExpand && expandResult.childFilter === "residual-label-contains") {
                var tf = ev.tokenFlow;
                var hasResidual = tf && tf.passed && tf.passed.length > 0;
                if (hasResidual && !expandResult.includeAllChildren) {
                    var passedTokenTexts = [];
                    for (var pt = 0; pt < tf.passed.length; pt += 1) {
                        var ptok = typeof tf.passed[pt] === "string" ? tf.passed[pt] : (tf.passed[pt].raw || tf.passed[pt].normalized || "");
                        if (ptok) passedTokenTexts.push(ptok.toLowerCase());
                    }
                    if (passedTokenTexts.length > 0) {
                        expandKids = expandKids.filter(function(c) {
                            var label = c.node && c.node.label || "";
                            if (!label) return false;
                            var labelLow = label.toLowerCase();
                            for (var pti = 0; pti < passedTokenTexts.length; pti += 1) {
                                if (labelLow.indexOf(passedTokenTexts[pti]) >= 0) return true;
                            }
                            return false;
                        });
                    }
                }
                // Fallback: if residual search produced no matching children, try with zero threshold
                if (expandKids.length === 0 && hasResidual && !expandResult.includeAllChildren) {
                    expandKids = eligibleChildren(ev.children, { minScore: 0 });
                }
            }

            // Policy expand: apply maxChildren cap
            if (!isDirectExpand && expandResult.maxChildren !== undefined) {
                expandKids = expandKids.slice(0, expandResult.maxChildren);
            }

            if (expandKids.length > 0) {
                var expandShowParent = true;
                if (retainResult && retainResult.retain === false)
                    expandShowParent = false;

                // Single residual child promotion (direct expand only)
                if (isDirectExpand && expandResult.promoteSingleResidual) {
                    var hasResidual = ev.tokenFlow && ev.tokenFlow.passed && ev.tokenFlow.passed.length > 0;
                    if (hasResidual && expandKids.length === 1) {
                        DecisionTrace.final(ev, ctx, "expand", { promote: true, child: 1, minScore: expandResult.minScore }, [{ code: "expand_promote", text: "Single residual match promotes child" }]);
                        return _d({
                            placement: "promoted-child",
                            mode: "flatten-children",
                            showParent: false,
                            suppressParentActions: true,
                            children: expandKids
                        });
                    }
                }

                DecisionTrace.final(ev, ctx, "expand", { expand: true, children: expandKids.length, minScore: expandResult.minScore }, [{ code: isDirectExpand ? "expand_direct" : "expand_policy", text: (isDirectExpand ? "Direct" : "Policy") + " expand " + expandKids.length + " children" }]);
                return _d({
                    placement: "nested-group",
                    mode: "nested-group",
                    showParent: expandShowParent,
                    suppressParentActions: false,
                    includeAllChildren: !!expandResult.includeAllChildren,
                    children: expandKids
                });
            }
        }

        // 3. Retain-only (no expand or expand produced no children)
        if (retainResult && retainResult.retain === false && ev.children && ev.children.length > 0) {
            var retainKids = eligibleChildren(ev.children, { includeAllChildren: true });
            DecisionTrace.final(ev, ctx, "retain", { retain: false, children: retainKids.length }, [{ code: "retain_suppress", text: "Retain suppressed parent, flattening " + retainKids.length + " children" }]);
            return _d({
                placement: "flattened",
                mode: "flatten-all-children",
                showParent: false,
                suppressParentActions: false,
                children: flattenActionableChildren(retainKids, 16)
            });
        }

        // 4. Default
        return _d({
            placement: "standalone",
            mode: "normal",
            showParent: true,
            children: ev.children || []
        });
    }

    readonly property var decidePlacement: prof.fn("decidePlacement", _decidePlacement)

    function attachTakeover(decision, claims, takeoverDecision) {
        if (!takeoverDecision) return decision;
        return Object.assign({}, decision, {
            takeover: {
                claims: claims,
                decision: takeoverDecision
            }
        });
    }

    function attachNesting(decision, nestingResult, ownershipResult) {
        if (!nestingResult && !ownershipResult) return decision;
        var ext = {};
        if (nestingResult) {
            var nestingReason = resultReason(nestingResult, "nesting");
            ext.nesting = { intent: nestingResult.intent, includeChildren: nestingResult.includeChildren, reason: nestingReason };
        }
        if (ownershipResult) ext.ownership = { visualOwnerId: ownershipResult.visualOwnerId, selectedOwnerId: ownershipResult.selectedOwnerId, actionOwnerId: ownershipResult.actionOwnerId, suppressParentActions: ownershipResult.suppressParentActions, reason: ownershipResult.reason };
        return Object.assign({}, decision, ext);
    }

    function flattenActionableChildren(children, limit) {
        var out = [];
        function visit(child) {
            if (!child || out.length >= limit) return;
            if ((child.node.actionList && child.node.actionList.length) || child.node.switchActions) {
                out.push(child);
                return;
            }
            for (var i = 0; i < (child.children || []).length && out.length < limit; i += 1)
                visit(child.children[i]);
        }
        for (var i = 0; i < (children || []).length && out.length < limit; i += 1)
            visit(children[i]);
        return out;
    }

    function placementForMode(mode) {
        switch (mode) {
        case "flatten-children": return "promoted-child";
        case "flatten-all-children": return "flattened";
        case "nested-group": return "nested-group";
        case "group": return "group";
        case "normal": return "standalone";
        default: return mode || "standalone";
        }
    }

    function placementLabel(placement) {
        switch (placement) {
        case "hidden": return "hidden";
        case "standalone": return "standalone row";
        case "group": return "group header (children hidden)";
        case "filtered-group": return "filtered group";
        case "group-child": return "child of a group";
        case "flattened": return "flattened (no parent)";
        case "promoted-child": return "promoted to standalone";
        case "nested-group": return "nested group with visible children";
        default: return "unknown";
        }
    }

    function buildChildTree(ev, currentDepth, maxDepth, includeAllChildren) {
        if (maxDepth <= 0 || !ev.children) return [];
        return buildChildRows(ev.children, currentDepth, maxDepth, includeAllChildren);
    }

    function buildChildRows(children, currentDepth, maxDepth, includeAllChildren) {
        if (maxDepth <= 0 || !children) return [];
        var filtered = children.filter(function(c) {
            return c.allowed && c.node.kind !== "backend" && (includeAllChildren || c.visible || c.score >= 0.02);
        });
        return filtered.map(function(child) {
            var grandChildren = buildChildTree(child, currentDepth + 1, maxDepth - 1, includeAllChildren);
            return { ev: child, depth: currentDepth + 1, children: grandChildren };
        });
    }

    function toDebug(shapedResult) {
        if (!shapedResult || !shapedResult.shaped) return [];
        return shapedResult.shaped.map(function(item) {
            var decision = item.decision || {};
            return {
                title: item.ev.node.label,
                nodeId: item.ev.node.id,
                score: item.sortScore,
                depth: item.depth,
                placement: item.placement,
                childCount: (item.childEvs || []).length,
                showParent: decision.showParent !== false,
                mode: decision.mode || "normal",
                nesting: decision.nesting || null,
                ownership: decision.ownership || null,
                semantics: ResultSemantics.toDebug(item.semantics)
            };
        });
    }
}
