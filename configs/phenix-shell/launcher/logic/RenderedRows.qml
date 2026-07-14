pragma Singleton
import QtQml
import Quickshell
import qs.services
import "Tokenize.qml"
import "Evidence.qml"
import "Evaluate.qml"
import "ScoreBundle.qml"
import "PolicyChain.qml"
import "DecisionDecider.qml"
import "PresentationContext.qml"
import "CompositeSearchPolicyRegistry.js" as JsRegistry

Singleton {
    readonly property var prof: Profiler.scope("launcher.renderedRows", { category: "launcher" })
    readonly property var tracer: Logger.scope("launcher.renderedRows", { category: "launcher" })
    function _toResultRow(ev, depth, state, ctx, childRows, options, shapedItem, parentPresentationContext) {
        options = options || {};
        var node = ev.node;
        tracer.trace("toResultRow", function() { return { nodeId: node.id, label: node.label, depth: depth, childRows: (childRows || []).length }; });
        var chain = Evaluate.collectParentChain(node);

        var presCtx = shapedItem
            ? PresentationContext.forShapedItem(ev, shapedItem, parentPresentationContext)
            : PresentationContext.emptyContext();

        var breadcrumbs = presCtx.breadcrumbs.length > 0
            ? presCtx.breadcrumbs
            : chain.slice(0, -1).map(function(n) { return n.label; });
        var brRoot = chain.find(function(n) { return n.behavior && n.behavior.visualRoot; });
        if (presCtx.breadcrumbs.length === 0 && brRoot)
            breadcrumbs = breadcrumbs.slice(chain.indexOf(brRoot));

        var displayPolicy = displayPolicyFor(node);
        var breadcrumbText = presCtx.showBreadcrumbs
            ? presCtx.breadcrumbText
            : breadcrumbTextFor(ev, breadcrumbs, displayPolicy, childRows);
        var selectedAction = ActionPolicy.selectDefaultAction(node, ctx.query, ev, ctx);
        var action = selectedAction ? selectedAction.action : null;
        var profile = (ev.node.evaluationProfile && ev.node.evaluationProfile.profile) || {};
        var _policyOverrode = false;
        var defaultActionNames = profile.defaultAction || [];
        if (defaultActionNames.length > 0) {
            var daVotes = [];
            PolicyChain.run(defaultActionNames, function(name, spec) {
                var policy = PolicyChain.lookupPolicy(JsRegistry.defaultAction, spec);
                if (!policy) return null;
                var vote = policy.apply(ev, ctx, spec && spec.args);
                if (vote) daVotes.push(vote);
                return vote;
            }, "accumulate");
            var daReduced = DecisionDecider.reduce("defaultAction", daVotes, { mode: "first-wins", tieBreak: "first" });
            var daResult = daReduced && daReduced.decision;
            if (daResult && daResult.actionId) {
                var overrideAction = null;
                if (daResult.actionId === "expand" || daResult.actionId === "noop" || daResult.actionId === "blocked") {
                    action = null;
                    selectedAction = null;
                    _policyOverrode = true;
                } else {
                    if (node.switchActions && node.switchActions[daResult.actionId])
                        overrideAction = node.switchActions[daResult.actionId];
                    else if (node.actionList) {
                        for (var dai = 0; dai < node.actionList.length; dai += 1) {
                            if (node.actionList[dai].id === daResult.actionId) {
                                overrideAction = node.actionList[dai];
                                break;
                            }
                        }
                    }
                    if (!overrideAction && ev.children) {
                        for (var dci = 0; dci < ev.children.length; dci += 1) {
                            var child = ev.children[dci].node;
                            if (!child) continue;
                            var childActions = child.actionList || [];
                            for (var dai2 = 0; dai2 < childActions.length; dai2 += 1) {
                                if (childActions[dai2].id === daResult.actionId) {
                                    overrideAction = childActions[dai2];
                                    break;
                                }
                            }
                            if (overrideAction) break;
                        }
                    }
                    if (overrideAction) {
                        selectedAction = { action: overrideAction, id: overrideAction.id, role: "policy-default", score: 1, priority: 100, reasons: [daResult.reason] };
                        action = overrideAction;
                        _policyOverrode = true;
                    } else if (daResult.actionId !== "") {
                        var synthAction = { id: daResult.actionId, label: daResult.actionId, payload: daResult.payload || null };
                        selectedAction = { action: synthAction, id: synthAction.id, role: "policy-default", score: 1, priority: 100, reasons: [daResult.reason] };
                        action = synthAction;
                        _policyOverrode = true;
                    }
                }
            } else if (daResult && daResult.expand === true) {
                action = null;
                selectedAction = null;
                _policyOverrode = true;
            }
        }
        var suppressOwnActions = false;
        if (!_policyOverrode) {
            suppressOwnActions = action && childRows && childRows.length && ctx.query.tokens.length > 1
                && (options.suppressParentActions || visibleFromChildrenOnly(ev));
            if (suppressOwnActions) {
                action = null;
                selectedAction = null;
            }
        }

        var takeoverDec = shapedItem && shapedItem.decision && shapedItem.decision.takeover && shapedItem.decision.takeover.decision;
        if (takeoverDec && takeoverDec.accepted && takeoverDec.defaultActionOwnerId && takeoverDec.defaultActionOwnerId !== node.id) {
            var targetOwnerId = takeoverDec.defaultActionOwnerId;
            var ownerAction = null;
            if (ev.children) {
                for (var toi = 0; toi < ev.children.length; toi += 1) {
                    var toChild = ev.children[toi];
                    if (!toChild || !toChild.node || toChild.node.id !== targetOwnerId) continue;
                    if (toChild.node.switchActions) {
                        var keys = Object.keys(toChild.node.switchActions);
                        if (keys.length > 0) ownerAction = toChild.node.switchActions[keys[0]];
                    } else if (toChild.node.actionList && toChild.node.actionList.length > 0) {
                        ownerAction = toChild.node.actionList[0];
                    }
                    break;
                }
            }
            if (ownerAction) {
                selectedAction = { action: ownerAction, id: ownerAction.id, role: "takeover-default", score: 1, priority: 200, reasons: ["takeover from " + targetOwnerId] };
                action = ownerAction;
            }
        }

        var sourceActions = suppressOwnActions ? [] : (node.actionList || []).slice();
        if (node.switchActions) {
            sourceActions = [node.switchActions.toggle, node.switchActions.on, node.switchActions.off].filter(Boolean);
        }
        var actions = copyActionList(sourceActions, action);
        var enterAction = action ? copyAction(action, true) : null;
        var hasAction = !!action;

        var placement = shapedItem ? shapedItem.placement : presCtx.placement;

        var replaceQueryInfo = replaceQuerySource(node, action, selectedAction);
        var hasReplaceQuery = !!replaceQueryInfo.value;

        var semantics = shapedItem && shapedItem.semantics ? shapedItem.semantics : null;
        var activation = semantics && semantics.activation ? semantics.activation : null;
        var canExecuteNow = hasAction && (!activation || activation.allowed !== false);
        var needsConfirmation = hasAction && activation && activation.allowed === false && !!activation.requiresConfirm;

        var row = {
            id: "row:" + node.id,
            nodeId: node.id,
            source: node.backendId,
            backendId: node.backendId,
            kind: node.kind,
            title: node.label,
            label: node.label,
            subtitle: node.subtitle,
            icon: node.icon,
            iconColor: node.iconColor || null,
            depth: depth,
            placement: placement,
            score: ev.score,
            ownScore: ev.ownScore,
            inheritedScore: ev.inheritedScore || 0,
            descendantScore: ev.descendantScore || 0,
            ownVisible: !!ev.ownVisible,
            matchDepth: ev.matchDepth === undefined ? depth : ev.matchDepth,
            evidence: copyEvidence(ev.evidence || []),
            selected: state.selectedNodeId === node.id,
            expandable: (childRows && childRows.length > 0) || (ev.children && ev.children.length > 0),
            expanded: state.expandedNodeIds[node.id] || node.kind === "backend",
            breadcrumbs: breadcrumbs,
            breadcrumbText: breadcrumbText,
            display: Object.assign({ breadcrumbText: breadcrumbText, showBreadcrumbs: presCtx.showBreadcrumbs, showBackendBadge: presCtx.showBackendBadge, showActionHint: presCtx.showActionHint, density: presCtx.density }, displayPolicy),
            labelMatches: copyRanges(rangesForField(ev.evidence, "label", node.id)),
            subtitleMatches: copyRanges(rangesForField(ev.evidence, "subtitle", node.id)),
            semantics: semantics,
            actions: actions,
            enter: hasReplaceQuery
                ? { type: "sequence", steps: [{ type: "edit-query", value: replaceQueryInfo.value }] }
                : enterAction
                ? { type: "sequence", steps: [{ type: "activate", action: enterAction }, { type: "close" }] }
                : { type: "noop" },
            shiftEnter: { type: "noop" },
            hasAction: hasAction,
            canExecuteNow: canExecuteNow,
            needsConfirmation: needsConfirmation,
            executable: canExecuteNow,
            dangerous: !!node.dangerous,
            risk: node.risk
                ? { level: node.risk.level || "none", activation: node.risk.activation || "normal" }
                : node.dangerous
                    ? { level: "state-change", activation: "confirm" }
                    : null,
            filterable: suppressOwnActions ? false : !!(node.behavior && node.behavior.filterable),
            filterChildren: !!(node.behavior && (node.behavior.filterChildren || node.behavior.filterable)),
            selectable: !(node.behavior && node.behavior.selectable === false),
            explicitBrowseChild: !!(options && options.explicitBrowseChild),
            lazy: !!node.lazy,
            alwaysExpanded: hasExplicitAlwaysExpanded(node)
                ? node.behavior.alwaysExpanded !== false
                : hasExplicitExpandPolicy(node)
                    ? shapedAsNestedGroup(shapedItem)
                    : (parentMatchShowsChildren(ev, ctx) || childHasGoodMatch(childRows) || switchHasResidualChildren(ev, ctx)),
            children: childRows || [],
            switchActions: suppressOwnActions ? null : copySwitchActions(node.switchActions, action),
            defaultAction: ActionPolicy.selectedActionMetadata(selectedAction),
            switchState: node.switchState === undefined ? null : node.switchState,
            control: node.control || null,
            presentation: node.presentation || null,
            presentationContext: PresentationContext.toDebug(presCtx),
            metadata: copyMetadata(node.meta, node, action),
            scoreBundle: ev.scoreBundle || null,
            interactions: node.interactions || null
        };

        if (hasReplaceQuery)
            row.recipes = { activate: [["edit-query", { mode: "replace", from: "metadata.replaceQuery" }]] };
        else if (action)
            row.recipes = { activate: [["run-action", { action: "default" }], ["close"]] };

        if (hasReplaceQuery || (!suppressOwnActions && node.behavior && node.behavior.filterable))
            row.recipes = row.recipes || {};
        if (hasReplaceQuery && (!row.recipes || !row.recipes.complete))
            row.recipes = row.recipes || {};
        if (hasReplaceQuery && row.recipes && !row.recipes.complete)
            row.recipes.complete = [["edit-query", { mode: "replace", from: "metadata.replaceQuery" }]];

        return row;
    }
    readonly property var toResultRow: prof.fn("toResultRow", _toResultRow)

    function displayPolicyFor(node) {
        var chain = Evaluate.collectParentChain(node);
        for (var i = chain.length - 1; i >= 0; i -= 1) {
            var behavior = chain[i].behavior || {};
            if (behavior.displayPolicy) return behavior.displayPolicy;
        }
        return {};
    }

    function breadcrumbTextFor(ev, breadcrumbs, policy, childRows) {
        var mode = policy.breadcrumbMode || "default";
        if (mode === "hidden" || !breadcrumbs.length) return "";
        if (mode === "when-parent-dominates") {
            var childMax = 0;
            for (var i = 0; i < (childRows || []).length; i += 1)
                childMax = Math.max(childMax, Number(childRows[i].ownScore || childRows[i].score || 0));
            if (childMax > 0 && childMax > Number(ev.ownScore || 0)) return "";
        } else if (mode !== "always") {
            return "";
        }
        return breadcrumbs.concat([ev.node.label]).join(" > ");
    }

    function rangesForField(evidenceItems, fieldName, nodeId) {
        var ranges = [];
        for (var i = 0; i < (evidenceItems || []).length; i += 1) {
            var e = evidenceItems[i];
            if (e.field === fieldName && (!nodeId || e.nodeId === nodeId))
                ranges = ranges.concat(e.ranges || []);
        }
        return ranges;
    }

    function visibleFromChildrenOnly(ev) {
        return (!ev.ownScore || ev.ownScore <= 0)
            && ev.children && ev.children.some(function(c) { return c.visible || c.score > 0; });
    }

    function hasExplicitAlwaysExpanded(node) {
        return !!(node && node.behavior && Object.prototype.hasOwnProperty.call(node.behavior, "alwaysExpanded"));
    }

    function hasExplicitExpandPolicy(node) {
        var profile = node && node.evaluationProfile && node.evaluationProfile.profile || {};
        return !!(profile.expand && profile.expand.length > 0);
    }

    function shapedAsNestedGroup(shapedItem) {
        return !!(shapedItem
            && shapedItem.decision
            && shapedItem.decision.mode === "nested-group");
    }

    function childHasGoodMatch(childRows) {
        for (var i = 0; i < (childRows || []).length; i += 1) {
            var child = childRows[i];
            if (child && ((child.ownVisible && (child.ownScore || child.score || 0) > 0) || (child.ownScore || child.score || 0) >= 0.25))
                return true;
        }
        return false;
    }

    function switchHasResidualChildren(ev, ctx) {
        if (!ctx || !ctx.query || !ctx.query.tokens) return false;
        if (!ev || !ev.node || !ev.node.switchActions) return false;
        var children = ev.children || [];
        if (children.length === 0) return false;
        var parentCov = Evidence.coveredTokenIndexes(ev.evidence || [], ctx.query);
        if (Object.keys(parentCov).length >= ctx.query.tokens.length) return false;
        for (var ci = 0; ci < children.length; ci += 1) {
            var child = children[ci];
            if (!child || !child.node) continue;
            var hl = Tokenize.normalizeText(String(child.node.label || "") + " " + (child.node.aliases || []).join(" "));
            for (var tj = 0; tj < ctx.query.tokens.length; tj += 1) {
                if (parentCov[tj]) continue;
                var tn = Tokenize.normalizeText(ctx.query.tokens[tj].raw);
                if (hl.indexOf(tn) === 0 || hl === tn) return true;
            }
        }
        return false;
    }

    function parentMatchShowsChildren(ev, ctx) {
        return false;
    }

    function copyEvidence(items) {
        return (items || []).map(function(e) {
            return {
                strategy: e.strategy || "",
                field: e.field || "",
                fieldText: e.fieldText || "",
                nodeId: e.nodeId || "",
                originNodeId: e.originNodeId || e.nodeId || "",
                originKind: e.originKind || "self",
                depth: e.depth === undefined ? 0 : Number(e.depth || 0),
                tokenIndex: e.tokenIndex === undefined ? null : e.tokenIndex,
                tokenIndexes: (e.tokenIndexes || []).slice(),
                coverageCount: e.coverageCount || 0,
                exactness: e.exactness || e.strategy || "",
                actionId: e.actionId || null,
                actionRole: e.actionRole || null,
                isExecutable: !!e.isExecutable,
                kind: e.kind || "",
                score: Number(e.score || 0),
                weight: Number(e.weight || 0),
                effective: Number(e.effective || 0),
                ranges: copyRanges(e.ranges),
                reason: e.reason || ""
            };
        });
    }

    function copyRange(r) { return r ? { start: Number(r.start || 0), end: Number(r.end || 0) } : null; }
    function copyRanges(rs) { return (rs || []).map(copyRange).filter(Boolean); }

    function copyPayload(p) {
        if (!p || typeof p !== "object") return p || null;
        var out = {};
        for (var k in p) {
            var v = p[k];
            if (typeof v === "function") continue;
            if (Array.isArray(v)) out[k] = v.slice();
            else if (!v || typeof v !== "object") out[k] = v;
        }
        return out;
    }

    function copyAction(a, isDef) {
        if (!a) return null;
        return {
            id: a.id || "", label: a.label || a.title || a.id || "",
            icon: a.icon || null, default: isDef === undefined ? !!a.default : !!isDef,
            intent: a.intent || null, payload: copyPayload(a.payload),
            dangerous: !!a.dangerous,
            risk: a.risk || null,
            state: a.state !== undefined ? a.state : undefined
        };
    }

    function copyActionList(actions, sel) {
        return (actions || []).map(function(a) { return copyAction(a, sel ? a.id === sel.id : a.default); }).filter(Boolean);
    }

    function copySwitchActions(sw, sel) {
        if (!sw) return null;
        var out = {};
        for (var k in sw) out[k] = copyAction(sw[k], sel ? sw[k].id === sel.id : sw[k].default);
        return out;
    }

    function replaceQuerySource(node, action, selectedAction) {
        var meta = node && node.meta || {};
        if (meta.replaceQuery) return { value: meta.replaceQuery, from: "metadata.replaceQuery" };
        if (action && action.payload && action.payload.replaceQuery) return { value: action.payload.replaceQuery, from: "defaultAction.payload.replaceQuery" };
        if (selectedAction && selectedAction.action && selectedAction.action.payload && selectedAction.action.payload.replaceQuery) return { value: selectedAction.action.payload.replaceQuery, from: "defaultAction.payload.replaceQuery" };
        if (meta.action && meta.action.replaceQuery) return { value: meta.action.replaceQuery, from: "metadata.action.replaceQuery" };
        if (meta.action && meta.action.payload && meta.action.payload.replaceQuery) return { value: meta.action.payload.replaceQuery, from: "metadata.action.payload.replaceQuery" };
        return { value: "", from: "metadata.replaceQuery" };
    }

    function copyMetadata(meta, node, action) {
        var out = {};
        for (var k in meta || {}) {
            if (k === "action") continue;
            var v = meta[k];
            if (Array.isArray(v)) out[k] = v.slice();
            else if (!v || typeof v !== "object") out[k] = v;
        }
        out.nodeId = node.id;
        if (action) out.actionId = action.id || "";
        var rq = replaceQuerySource(node, action, null);
        if (rq.value) out.replaceQuery = rq.value;
        return out;
    }

    function toDebug(row) {
        if (!row) return null;
        return {
            id: row.id, title: row.title, source: row.source, kind: row.kind,
            score: row.score, ownScore: row.ownScore, ownVisible: row.ownVisible,
            depth: row.depth, placement: row.placement, children: (row.children || []).length,
            actions: (row.actions || []).length,
            hasRecipes: !!row.recipes,
            hasInteractions: !!row.interactions,
            defaultAction: row.defaultAction,
            interactionKeys: row.interactions ? Object.keys(row.interactions) : []
        };
    }
}
