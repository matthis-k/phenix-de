pragma Singleton
import QtQml
import Quickshell
import qs.services
import "PolicyChain.qml"
import "DecisionDecider.qml"
import "CompositeSearchPolicyRegistry.js" as JsRegistry

Singleton {
    readonly property var prof: Profiler.scope("launcher.takeover", { category: "launcher" })
    readonly property var tracer: Logger.scope("launcher.takeover", { category: "launcher" })
    function _evaluateTakeoverRequests(parentEv, childEvs, ctx) {
        tracer.trace("evaluateTakeoverRequests", function() { return { parentId: parentEv && parentEv.node && parentEv.node.id, childCount: (childEvs || []).length }; });
        var claims = [];
        if (!childEvs || !childEvs.length) return claims;

        for (var ci = 0; ci < childEvs.length; ci += 1) {
            var child = childEvs[ci];
            if (!child.visible && !child.candidate) continue;
            var childClaims = emitClaims(child, parentEv, ctx);
            claims = claims.concat(childClaims);
        }

        claims.sort(function(a, b) { return b.strength - a.strength; });
        return claims;
    }

    readonly property var evaluateTakeoverRequests: prof.fn("evaluateTakeoverRequests", _evaluateTakeoverRequests)

    function emitClaims(childEv, parentEv, ctx) {
        var claims = [];
        var child = childEv.node;
        var parent = parentEv.node;
        if (!child || !parent) return claims;

        var profile = (parentEv.node.evaluationProfile && parentEv.node.evaluationProfile.profile) || {};
        var takeoverRequestRaw = profile.takeoverRequest;
        var takeoverNames = takeoverRequestRaw === undefined
            ? ["child-own-match-parent-no-own-match", "explicit-child-token", "child-covers-passed-tokens", "own-score-dominates-takeover"]
            : takeoverRequestRaw;

        PolicyChain.run(takeoverNames, function(name, spec) {
            var policy = PolicyChain.lookupPolicy(JsRegistry.takeoverRequest, spec);
            if (!policy) return null;
            var result = policy.apply(childEv, parentEv, ctx, spec && spec.args);
            if (result && Array.isArray(result)) {
                claims = claims.concat(result);
                return result.length > 0 ? true : null;
            }
            if (result && result.claimantId) {
                claims.push(result);
                return result;
            }
            return null;
        }, "accumulate");

        return claims;
    }

    function _decideTakeover(parentEv, claims, ctx) {
        tracer.trace("decideTakeover", function() { return { parentId: parentEv && parentEv.node && parentEv.node.id, claimCount: (claims || []).length }; });
        if (!claims || !claims.length) {
            return {
                accepted: false,
                ownerId: parentEv.node ? parentEv.node.id : "",
                representation: "keep-parent",
                retainParent: true,
                suppressParentActions: false,
                selectedOwnerId: parentEv.node ? parentEv.node.id : "",
                defaultActionOwnerId: parentEv.node ? parentEv.node.id : "",
                activation: "normal",
                reason: "no takeover claims"
            };
        }

        var profile = (parentEv.node.evaluationProfile && parentEv.node.evaluationProfile.profile) || {};
        var takeoverAcceptRaw = profile.takeoverAccept;
        var acceptNames = takeoverAcceptRaw === undefined ? ["accept-dominated-claims"] : takeoverAcceptRaw;
        var acceptVotes = [];
        PolicyChain.run(acceptNames, function(name, spec) {
            var policy = PolicyChain.lookupPolicy(JsRegistry.takeoverAccept, spec);
            if (!policy) return null;
            var vote = policy.apply(parentEv, claims, ctx, spec && spec.args);
            if (vote && vote.decision) acceptVotes.push(vote);
            return vote;
        }, "accumulate");

        var acceptReduced = DecisionDecider.reduce("takeoverAccept", acceptVotes, { mode: "first-wins", tieBreak: "first" });
        var accepted = acceptReduced && acceptReduced.decision;
        if (!accepted || !accepted.accepted) {
            return {
                accepted: false,
                ownerId: parentEv.node ? parentEv.node.id : "",
                representation: "keep-parent",
                retainParent: true,
                suppressParentActions: false,
                selectedOwnerId: parentEv.node ? parentEv.node.id : "",
                defaultActionOwnerId: parentEv.node ? parentEv.node.id : "",
                activation: "normal",
                reason: accepted ? accepted.reason : "no accept policy matched"
            };
        }

        return accepted;
    }

    readonly property var decideTakeover: prof.fn("decideTakeover", _decideTakeover)

    function defaultAcceptPolicy(parentEv, claims, ctx, args) {
        tracer.trace("defaultAcceptPolicy", function() { return { parentId: parentEv && parentEv.node && parentEv.node.id, claimCount: (claims || []).length }; });
        if (!claims || !claims.length) {
            return { decision: { accepted: false, reason: "no claims" }, reasons: [{ code: "no_claims", text: "no claims" }] };
        }

        var bestClaim = claims[0];
        var scoreDominance = false;

        var retainParentWhenParentMatched = !!(args && args.retainParentWhenParentMatched);
        var parentHasOwnMatch = !!(parentEv && (parentEv.ownVisible || (parentEv.ownScore || 0) > 0));

        if (bestClaim.claimantId && bestClaim.targetId === parentEv.node.id) {
            var claimantEv = findChildEv(parentEv, bestClaim.claimantId);
            if (claimantEv && claimantEv.score && parentEv.score) {
                scoreDominance = claimantEv.score > parentEv.score + 0.15;
            }
        }

        var selectedOwnerId = bestClaim.claimantId || parentEv.node.id;
        var defaultActionOwnerId = parentEv.node.id;
        var suppressParentActions = false;
        var retainParent = true;
        var representation = "keep-parent";
        var activation = "normal";
        var reason = "";

        var dominanceClaim = claims.filter(function(c) { return c.kind === "selection" || c.kind === "defaultAction" || c.kind === "structuralChildOwnMatch"; });
        if (dominanceClaim.length > 0) {
            var dc = dominanceClaim[0];
            selectedOwnerId = dc.claimantId;
            if (dc.kind === "defaultAction" || dc.kind === "structuralChildOwnMatch" || (dc.kind === "selection" && scoreDominance)) {
                if (retainParentWhenParentMatched && parentHasOwnMatch) {
                    defaultActionOwnerId = dc.claimantId;
                    retainParent = true;
                    representation = "nested-group";
                    suppressParentActions = true;
                    reason = "child selected, parent retained (retainParentWhenParentMatched): " + dc.reason;
                } else {
                    defaultActionOwnerId = dc.claimantId;
                    retainParent = false;
                    representation = "promote-child";
                    suppressParentActions = true;
                    reason = "child " + (dc.claimantId || "") + " dominates via " + dc.reason;
                }
            } else {
                reason = "child " + (dc.claimantId || "") + " claims " + (dc.kind || "selection") + " via " + dc.reason;
            }
        } else {
            reason = "no dominant claim, keeping parent";
        }

        if (parentEv.node && (parentEv.node.risk || parentEv.node.dangerous)) {
            activation = "confirm";
            reason += " (parent risk requires confirmation)";
        }

        return {
            decision: {
                accepted: true,
                ownerId: selectedOwnerId,
                representation: representation,
                retainParent: retainParent,
                suppressParentActions: suppressParentActions,
                selectedOwnerId: selectedOwnerId,
                defaultActionOwnerId: defaultActionOwnerId,
                activation: activation,
                includeAllChildren: false,
                reason: reason
            },
            reasons: [{ code: "default_accept", text: reason }]
        };
    }

    function findChildEv(parentEv, childId) {
        if (!parentEv || !parentEv.children) return null;
        for (var i = 0; i < parentEv.children.length; i += 1) {
            if (parentEv.children[i].node && parentEv.children[i].node.id === childId)
                return parentEv.children[i];
        }
        return null;
    }

    function childOwnMatchParentNoOwnMatch(childEv, parentEv, ctx, args) {
        tracer.trace("childOwnMatchParentNoOwnMatch", function() { return { childId: childEv && childEv.node && childEv.node.id, parentId: parentEv && parentEv.node && parentEv.node.id }; });
        var claims = [];
        if (!childEv || !parentEv || !childEv.node || !parentEv.node) return claims;
        var minChildScore = (args && args.minChildScore) || 0.05;
        var maxParentScore = (args && args.maxParentScore) || 0;
        var childOwn = !!(childEv.ownVisible || (childEv.ownScore || 0) > minChildScore);
        var parentOwn = !!(parentEv.ownVisible || (parentEv.ownScore || 0) > maxParentScore);
        if (childOwn && !parentOwn) {
            claims.push({
                claimantId: childEv.node.id,
                targetId: parentEv.node.id,
                kind: "structuralChildOwnMatch",
                strength: 0.95,
                reason: "child-own-match-parent-no-own-match: parent is context only",
                evidence: [{ field: "structural-child-own-match", value: childEv.ownScore || childEv.score || 0 }]
            });
        }
        return claims;
    }

    function explicitChildToken(childEv, parentEv, ctx, args) {
        tracer.trace("explicitChildToken", function() { return { childId: childEv && childEv.node && childEv.node.id }; });
        var claims = [];
        if (!childEv.visible || !childEv.ownScore) return claims;
        var tokens = ctx.query && ctx.query.tokens || [];

        if (tokens.length === 0) return claims;

        var childCovered = {};
        var evidence = childEv.ownEvidence || childEv.evidence || [];
        for (var ei = 0; ei < evidence.length; ei += 1) {
            var e = evidence[ei];
            if (e.tokenIndex !== undefined) childCovered[e.tokenIndex] = true;
        }

        var parentCovered = {};
        var parentEvidence = parentEv.ownEvidence || parentEv.evidence || [];
        for (var pi = 0; pi < parentEvidence.length; pi += 1) {
            var pe = parentEvidence[pi];
            if (pe.tokenIndex !== undefined) parentCovered[pe.tokenIndex] = true;
        }

        var uniqueTokens = 0;
        for (var ti = 0; ti < tokens.length; ti += 1) {
            if (childCovered[ti] && !parentCovered[ti]) uniqueTokens += 1;
        }

        if (uniqueTokens > 0) {
            claims.push({
                claimantId: childEv.node.id,
                targetId: parentEv.node.id,
                kind: "selection",
                strength: 0.6 + (uniqueTokens / tokens.length) * 0.3,
                reason: "explicit-child-token: child covers " + uniqueTokens + " unique tokens",
                evidence: [{ field: "token-coverage", value: uniqueTokens / tokens.length }]
            });
        }

        return claims;
    }

    function childCoversPassedTokens(childEv, parentEv, ctx, args) {
        tracer.trace("childCoversPassedTokens", function() { return { childId: childEv && childEv.node && childEv.node.id }; });
        var claims = [];
        var tokenFlow = parentEv.tokenFlow;
        if (!tokenFlow || !tokenFlow.passed || tokenFlow.passed.length === 0) return claims;

        var passedTokenIndexes = {};
        var queryTokens = ctx.query && ctx.query.tokens || [];
        for (var pti = 0; pti < tokenFlow.passed.length; pti += 1) {
            var originalIndex = queryTokens.indexOf(tokenFlow.passed[pti]);
            if (originalIndex >= 0)
                passedTokenIndexes[originalIndex] = true;
        }
        var childEvidence = childEv.ownEvidence || childEv.evidence || [];
        var coveredTokens = 0;

        for (var ei = 0; ei < childEvidence.length; ei += 1) {
            var e = childEvidence[ei];
            if (e.tokenIndex !== undefined && passedTokenIndexes[e.tokenIndex]) {
                coveredTokens += 1;
            }
        }

        if (coveredTokens > 0) {
            claims.push({
                claimantId: childEv.node.id,
                targetId: parentEv.node.id,
                kind: "defaultAction",
                strength: 0.5 + (coveredTokens / tokenFlow.passed.length) * 0.3,
                reason: "child-covers-passed-tokens: covers " + coveredTokens + " of " + tokenFlow.passed.length + " passed tokens",
                evidence: [{ field: "passed-token-coverage", value: coveredTokens / tokenFlow.passed.length }]
            });
        }

        return claims;
    }

    function ownScoreDominatesTakeover(childEv, parentEv, ctx, args) {
        tracer.trace("ownScoreDominatesTakeover", function() { return { childId: childEv && childEv.node && childEv.node.id }; });
        var claims = [];
        var margin = (args && args.margin) || 0.18;
        if (!childEv.ownScore || !parentEv.ownScore) return claims;
        if (childEv.ownScore >= parentEv.ownScore + margin) {
            claims.push({
                claimantId: childEv.node.id,
                targetId: parentEv.node.id,
                kind: "selection",
                strength: 0.7,
                reason: "own-score-dominates: child score " + childEv.ownScore.toFixed(3) + " beats parent " + parentEv.ownScore.toFixed(3) + " by " + margin,
                evidence: [{ field: "score-margin", value: childEv.ownScore - parentEv.ownScore }]
            });
        }
        return claims;
    }

    function exactActionTokenTakeover(childEv, parentEv, ctx, args) {
        tracer.trace("exactActionTokenTakeover", function() { return { childId: childEv && childEv.node && childEv.node.id }; });
        var claims = [];
        if (!childEv.node || !childEv.node.switchActions) return claims;
        var tokens = ctx.query && ctx.query.tokens || [];
        if (tokens.length === 0) return claims;

        var lastToken = tokens[tokens.length - 1];
        var actionLabels = ["on", "off", "toggle", "enable", "disable", "connect", "disconnect"];
        if (actionLabels.indexOf(lastToken.normalized) < 0) return claims;

        claims.push({
            claimantId: childEv.node.id,
            targetId: parentEv.node.id,
            kind: "defaultAction",
            strength: 0.85,
            reason: "exact-action-token: last token '" + lastToken.raw + "' matches switch action alias",
            evidence: [{ field: "action-token-match", value: 1.0 }]
        });

        return claims;
    }
}
