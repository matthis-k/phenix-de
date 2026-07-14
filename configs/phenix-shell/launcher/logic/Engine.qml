pragma Singleton
import QtQml
import Quickshell
import qs.services
import "Tokenize.qml"
import "IndexBuilder.qml"
import "Evaluate.qml"
import "ResultShaping.qml"
import "RenderedRows.qml"
import "Rows.qml"
import "ScoreBundle.qml"
import "RoutingTree.js" as JsRoutingTree
import "Evaluation.js" as EvalBuilder
import "FormatUtils.qml"

Singleton {
    readonly property var prof: Profiler.scope("launcher.engine", { category: "launcher" })
    readonly property var tracer: Logger.scope("launcher.pipeline", { category: "launcher" })
    function buildDirectiveFromRoute(rawQuery, route, backends) {
        if (!route || !route.endpoints || route.endpoints.length === 0)
            return { active: false, raw: rawQuery, searchRaw: rawQuery, prefix: "", label: "All", tags: [], kinds: [], backendIds: [] };

        var backendIds = [];
        var seen = {};
        for (var i = 0; i < route.endpoints.length; i += 1) {
            var ep = route.endpoints[i];
            var id = String(ep.node && ep.node.backendId || "");
            if (id && !seen[id]) {
                seen[id] = true;
                backendIds.push(id);
            }
        }

        var prefix = route.endpoints[0] ? (route.endpoints[0].prefix || "") : "";
        var label = backendIds.length === 1 ? findHelpTitle(backends, backendIds[0]) : (backendIds.length > 1 ? "Multiple" : "All");

        return {
            active: route.combine === "exclusive" || (backendIds.length > 0 && prefix !== ""),
            raw: rawQuery,
            searchRaw: route.strippedQuery !== undefined && route.strippedQuery !== null ? route.strippedQuery : rawQuery,
            prefix: prefix,
            label: label,
            tags: [],
            kinds: [],
            backendIds: backendIds
        };
    }

    function findHelpTitle(backends, backendId) {
        for (var i = 0; i < (backends || []).length; i += 1) {
            var b = backends[i];
            if (b && b.backendId === backendId)
                return b.helpTitle || b.name || b.backendId;
        }
        return backendId;
    }

    function suppressFallbackRows(rows, ctx) {
        if (!rows || !rows.length || ctx.directive.active)
            return rows;

        var hasNonFallback = rows.some(function(row) { return row.source !== "web"; });
        if (!hasNonFallback)
            return rows;

        return rows.filter(function(row) { return row.source !== "web"; });
    }

    function buildRowsFromShaped(shapedResult, state, ctx) {
        var maxTreeDepth = shapedResult.maxTreeDepth;

        function canDescendDuringExploration(ev) {
            var behavior = ev && ev.node && ev.node.behavior || {};
            var exploration = behavior.exploration || {};
            return exploration.descend !== false;
        }

        function buildChildTree(ev, currentDepth, maxDepth, includeAllChildren, exploringFromAncestor) {
            if (maxDepth <= 0 || !ev.children) return [];
            if (exploringFromAncestor && !canDescendDuringExploration(ev)) return [];
            var filtered = ev.children.filter(function(c) {
                return c.allowed && c.node.kind !== "backend" && (includeAllChildren || c.visible || c.score >= 0.02);
            });
            return buildChildRows(filtered, currentDepth, maxDepth, includeAllChildren, exploringFromAncestor);
        }

        function buildChildRows(children, currentDepth, maxDepth, includeAllChildren, exploringFromAncestor) {
            if (maxDepth <= 0 || !children) return [];
            var filtered = children.filter(function(c) {
                return c.allowed && c.node.kind !== "backend" && (includeAllChildren || c.visible || c.score >= 0.02);
            });
            return filtered.map(function(child) {
                var grandChildren = buildChildTree(child, currentDepth + 1, maxDepth - 1, includeAllChildren, exploringFromAncestor || includeAllChildren);
                var childShapedItem = { ev: child, depth: currentDepth + 1, placement: "group-child", decision: { placement: "group-child", mode: "normal", showParent: false }, options: {} };
                return RenderedRows.toResultRow(child, currentDepth + 1, state, ctx, grandChildren, { explicitBrowseChild: includeAllChildren }, childShapedItem);
            });
        }

        return shapedResult.shaped.map(function(item) {
            var includeAllChildren = item.options && item.options.includeAllChildren;
            var childRows;
            if (item.childEvs != null) {
                if (item.childEvs.length > 0)
                    childRows = buildChildRows(item.childEvs, item.depth, maxTreeDepth, includeAllChildren, false);
            } else {
                childRows = buildChildTree(item.ev, item.depth, maxTreeDepth, false, false);
            }
            if (!childRows) childRows = [];
            return RenderedRows.toResultRow(item.ev, item.depth, state, ctx, childRows, item.options, item);
        });
    }

    function search(backends, rawQuery, state, options) {
        var opts = Object.assign({}, options || {}, { sync: true });
        return searchAsync(backends, rawQuery, state, opts, function() { return true; }, null);
    }

    function searchAsync(backends, rawQuery, state, options, isCurrent, onComplete) {
        tracer.info("searchAsync", function() { return { query: rawQuery } })

        var sync = options && options.sync;
        var schedule = sync ? function(fn) { fn(); } : Qt.callLater;
        var totalStart = Tokenize.nowMs();
        var routingTree = options && options.routingTree;
        var ctx = Object.assign({ query: null, directive: null, routingTree: routingTree, route: null, visibilityThreshold: 0.18, showHidden: false, includePath: true, _policyTimings: null }, options || {});
        if (ctx.trace) {
            ctx._evidenceTrace = {};
            ctx._scoreTrace = {};
            ctx._policyTrace = {};
        }

        var active = null;
        var children = null;
        var root = null;
        var route = null;
        var directive = null;
        var query = null;
        var timings = null;
        var phases = [];
        var syncResult = null;

        function abort() {
            if (onComplete) onComplete(null);
        }

        function phase0() {
            if (!isCurrent()) { abort(); return; }

            tracer.info("tokenize", function() { return { query: rawQuery } })

            if (routingTree)
                route = JsRoutingTree.routeQuery(routingTree, rawQuery);
            directive = route
                ? buildDirectiveFromRoute(rawQuery, route, backends)
                : Tokenize.parseDirective(rawQuery, backends);
            query = Tokenize.tokenize(directive.searchRaw);
            ctx.query = query;
            ctx.directive = directive;
            ctx.route = route;

            active = (backends || []).filter(function(b) {
                if (!b || !b.enabled) return false;
                if (typeof b.shouldParticipate === "function" && !b.shouldParticipate(rawQuery, directive, query)) return false;
                return !directive.active || directive.backendIds.indexOf(b.backendId) >= 0;
            }).sort(function(a, b) { return (b.priority || 0) - (a.priority || 0); });
            ctx._activeBackends = backends || [];
            ctx._participatingBackends = active;
            ctx._backendCandidateCounts = {};
            ctx._backendVisibleCounts = {};

            if (ctx.trace) {
                phases.push({
                    phase: 0, name: "directive-tokenize",
                    directive: { active: directive.active, prefix: directive.prefix || "", label: directive.label || "", backendIds: directive.backendIds || [] },
                    tokens: query.tokens.map(function(t) { return { raw: t.raw, normalized: t.normalized }; }),
                    searchRaw: directive.searchRaw,
                    activeBackendIds: active.map(function(b) { return b.backendId || b.name || ""; }),
                    routeEndpoints: route && route.endpoints ? route.endpoints.map(function(ep) { return { prefix: ep.prefix || "", nodeId: ep.node && ep.node.id ? ep.node.id : "" }; }) : []
                });
            }

            schedule(phase1);
        }

        function phase1() {
            if (!isCurrent()) { abort(); return; }

            tracer.info("gateBackends", function() { return { activeCount: active.length } })

            children = [];
            var backendTimings = {};
            var rootNodeStart = Tokenize.nowMs();
            for (var i = 0; i < active.length; i += 1) {
                var backend = active[i];
                var bStart = Tokenize.nowMs();
                var node = backend.rootNode ? backend.rootNode(query, ctx) : null;
                var bMs = Tokenize.nowMs() - bStart;
                if (node) {
                    node.backendId = node.backendId || backend.backendId;
                    node.backendPriority = backend.priority || 0;
                    children.push(Tokenize.makeNode(node));
                }
                backendTimings["root:" + (backend.backendId || i)] = bMs;
            }
            ctx.backendTimings = backendTimings;
            ctx.rootNodeMs = Tokenize.nowMs() - rootNodeStart;
            root = Tokenize.makeNode({ id: "root", kind: "root", label: "Root", children: children, evaluationProfile: { strategies: [] } });

            if (ctx.trace) {
                phases.push({
                    phase: 1, name: "root-nodes",
                    rootNodeMs: ctx.rootNodeMs,
                    perBackendMs: ctx.backendTimings,
                    roots: children.map(function(c) {
                        return { backendId: c.backendId || "", label: c.label || "", kind: c.kind || "", childrenCount: (c.children || []).length };
                    })
                });
            }

            schedule(phase2);
        }

        function phase2() {
            if (!isCurrent()) { abort(); return; }

            tracer.info("collectCandidates", function() { return {} })

            var candidateStart = Tokenize.nowMs();
            ctx.candidateIds = IndexBuilder.collectCandidateIdsForRoots(children, query, ctx.candidateCap || 256);
            ctx.candidateMs = Tokenize.nowMs() - candidateStart;
            ctx.candidateCount = Tokenize.countKeys(ctx.candidateIds);

            if (ctx.trace) {
                phases.push({
                    phase: 2, name: "candidates",
                    candidateMs: ctx.candidateMs,
                    candidateCount: ctx.candidateCount
                });
            }

            schedule(phase3);
        }

        function phase3() {
            if (!isCurrent()) { abort(); return; }

            tracer.info("scoreCandidates", function() { return {} })

            var evaluateStart = Tokenize.nowMs();
            var evaluated = Evaluate.evaluateNode(root, query, ctx);
            ctx.evaluateMs = Tokenize.nowMs() - evaluateStart;
            ctx.evaluated = evaluated;

            if (ctx.trace) {
                function countEval(ev) {
                    if (!ev) return 0;
                    var c = 1;
                    for (var i = 0; i < (ev.children || []).length; i += 1)
                        c += countEval(ev.children[i]);
                    return c;
                }
                function countEvalVisible(ev) {
                    if (!ev) return 0;
                    var c = (ev.visible && ev.ownVisible && ev.node && ev.node.kind !== "root" && ev.node.kind !== "backend") ? 1 : 0;
                    for (var i = 0; i < (ev.children || []).length; i += 1)
                        c += countEvalVisible(ev.children[i]);
                    return c;
                }
                var childScoreBundles = (evaluated && evaluated.children || []).map(function(ev) {
                    var bundle = ev.scoreBundle || ScoreBundle.fromEvaluated(ev, query);
                    return {
                        label: ev.node ? ev.node.label : "", kind: ev.node ? ev.node.kind : "", backendId: ev.node ? ev.node.backendId : "",
                        score: ev.score || 0, ownScore: ev.ownScore || 0, visible: !!ev.visible, childrenCount: (ev.children || []).length,
                        scoreBundle: ScoreBundle.toDebug(bundle),
                        evidenceCount: (ev.evidence || []).length
                    };
                });
                phases.push({
                    phase: 3, name: "evaluation",
                    evaluateMs: ctx.evaluateMs,
                    totalNodes: countEval(evaluated),
                    visibleNodes: countEvalVisible(evaluated),
                    childScoreBundles: childScoreBundles
                });
            }

            schedule(phase5);
        }

        function phase5() {
            if (!isCurrent()) { abort(); return; }

            tracer.info("decidePresentation", function() { return {} })

            var shapeStart = Tokenize.nowMs();
            var shapedResult = ResultShaping.shape(ctx.evaluated, state, ctx);
            var rows = buildRowsFromShaped(shapedResult, state, ctx);
            rows = suppressFallbackRows(rows, ctx);
            rows = Rows.finalizeRows(rows, query, directive, ctx);
            var shapeMs = Tokenize.nowMs() - shapeStart;

            var policyTimingsOut = {};
            if (ctx._policyTimings) {
                var evTimings = ctx._policyTimings.evidence;
                var boTimings = ctx._policyTimings.boost;
                if (evTimings) {
                    policyTimingsOut.evidence = {};
                    for (var pkey in evTimings)
                        if (evTimings.hasOwnProperty(pkey))
                            policyTimingsOut.evidence[pkey] = evTimings[pkey];
                }
                if (boTimings) {
                    policyTimingsOut.boost = {};
                    for (var pkey2 in boTimings)
                        if (boTimings.hasOwnProperty(pkey2))
                            policyTimingsOut.boost[pkey2] = boTimings[pkey2];
                }
            }

            timings = {
                totalMs: Tokenize.nowMs() - totalStart, rootNodeMs: ctx.rootNodeMs, candidateMs: ctx.candidateMs,
                evaluateMs: ctx.evaluateMs, pathMs: ctx.pathMs, shapeMs: shapeMs,
                activeBackends: active.length, backendRoots: children.length, candidateIds: ctx.candidateCount,
                backends: ctx.backendTimings, rows: rows.length,
                policyTimings: ctx._policyTimings ? policyTimingsOut : undefined
            };

            if (ctx.trace) {
                var placements = {};
                var shapedItems = [];
                if (shapedResult && shapedResult.shaped) {
                    for (var si = 0; si < shapedResult.shaped.length; si += 1) {
                        var item = shapedResult.shaped[si];
                        var pl = item.placement || "unknown";
                        placements[pl] = (placements[pl] || 0) + 1;
                        shapedItems.push({
                            title: item.ev && item.ev.node ? item.ev.node.label : "",
                            nodeId: item.ev && item.ev.node ? item.ev.node.id : "",
                            kind: item.ev && item.ev.node ? item.ev.node.kind : "",
                            backendId: item.ev && item.ev.node ? item.ev.node.backendId : "",
                            placement: pl,
                            depth: item.depth || 0,
                            score: item.ev ? (item.ev.score || 0) : 0,
                            ownScore: item.ev ? (item.ev.ownScore || 0) : 0,
                            inheritedScore: item.ev ? (item.ev.inheritedScore || 0) : 0,
                            descendantScore: item.ev ? (item.ev.descendantScore || 0) : 0,
                            children: (item.childEvs || (item.ev && item.ev.children) || []).length,
                            decision: item.decision ? { mode: item.decision.mode || "normal", reason: item.decision.reason || "", showParent: item.decision.showParent !== false, suppressParentActions: !!item.decision.suppressParentActions } : null
                        });
                    }
                }
                phases.push({
                    phase: 5, name: "shaping",
                    shapeMs: shapeMs,
                    shapedCount: shapedResult && shapedResult.shaped ? shapedResult.shaped.length : 0,
                    placements: placements,
                    shaped: shapedItems,
                    rows: rows.length,
                    totalMs: timings.totalMs
                });
            }

            var evaluation = EvalBuilder.build(query, {
                rows: rows, query: query, directive: directive, route: route,
                evaluatedRoot: ctx.evaluated, shapedResult: shapedResult,
                timings: timings, phases: phases
            }, ctx);
            FormatUtils.mergeToEvaluation(evaluation);
            evaluation._stages = phases.map(function(p) {
                return { name: p.name || "", durationMs: p.evaluateMs || p.shapeMs || p.candidateMs || p.rootNodeMs || 0 };
            });

            tracer.info("searchComplete", function() {
                return {
                    rows: rows.length,
                    totalMs: timings.totalMs,
                    activeBackends: timings.activeBackends
                }
            })

            var result = { rows: rows, query: query, directive: directive, route: route, evaluatedRoot: ctx.evaluated, shapedResult: shapedResult, timings: timings, phases: phases, evaluation: evaluation };
            syncResult = result;
            if (onComplete) onComplete(result);
        }

        schedule(phase0);
        return syncResult;
    }
}
