// Evaluation.js — canonical Evaluation object construction
// The pipeline owns truth. Evaluation preserves truth. UI renders truth. IPC serializes truth.

.pragma library

function emptyBackendTrace(backendId) {
    return {
        backend: String(backendId || ""),
        participated: false,
        candidateCount: 0,
        visibleCount: 0,
        durationMs: 0,
        reasons: []
    };
}

function emptyStats() {
    return {
        durationMs: 0,
        backendCount: 0,
        participatingBackendCount: 0,
        candidateCount: 0,
        evaluatedNodeCount: 0,
        finalVisibleRowCount: 0,
        finalVisibleTreeNodeCount: 0,
        evaluatedVisibleCandidateCount: 0,
        hiddenCandidateCount: 0,
        prunedNodeCount: 0,
        visibleNodeCount: 0
    };
}

function emptyDecision() {
    return {
        visibility: {
            value: { visible: true },
            source: "fallback",
            reasons: [{ code: "fallback_decision", text: "Fallback decision — no explicit trace recorded." }]
        },
        placement: {
            value: "standalone",
            source: "fallback",
            reasons: [{ code: "fallback_decision", text: "Fallback decision — no explicit trace recorded." }]
        },
        flattening: null,
        breadcrumbs: null,
        defaultAction: null,
        childVisibility: null
    };
}

function makeActionResolution(nodeId, input, exists, name, label, source, reasons, steps) {
    return {
        nodeId: String(nodeId || ""),
        input: String(input || "enter"),
        exists: !!exists,
        name: name || "",
        label: label || "",
        source: source || "",
        reasons: (reasons || []).slice(),
        steps: (steps || []).slice()
    };
}

function safePayload(args) {
    if (args === null || args === undefined) return null;
    if (typeof args !== "object") return String(args);
    if (Array.isArray(args)) return args.map(function(a) { return safePayload(a); });
    var out = {};
    for (var k in args) {
        if (!Object.prototype.hasOwnProperty.call(args, k)) continue;
        var v = args[k];
        if (typeof v === "function" || typeof v === "undefined") continue;
        if (typeof v === "object" && v !== null && !Array.isArray(v) && !(v instanceof String) && !(v instanceof Number) && !(v instanceof Boolean)) {
            if (Object.keys(v).length <= 5) out[k] = safePayload(v);
            else out[k] = "[object]";
        } else if (typeof v === "string" && v.length > 200) {
            out[k] = v.substring(0, 200) + "...";
        } else {
            out[k] = v;
        }
    }
    return out;
}

function makeActionStep(index, kind, label, payloadSummary) {
    return {
        index: index,
        kind: String(kind || ""),
        label: label || "",
        payloadSummary: payloadSummary || null
    };
}

function countEvaluatedNodes(evaluated) {
    if (!evaluated) return 0;
    var count = 1;
    var kids = evaluated.children || [];
    for (var i = 0; i < kids.length; i += 1) count += countEvaluatedNodes(kids[i]);
    return count;
}

function countAllRows(rowList) {
    if (!rowList) return 0;
    var count = 0;
    for (var i = 0; i < rowList.length; i += 1) {
        count += 1;
        count += countAllRows(rowList[i].children);
    }
    return count;
}

function countVisibleNodes(evaluated) {
    if (!evaluated) return 0;
    var count = 0;
    // don't count root/backend nodes as "visible" for stats
    if (evaluated.visible && evaluated.node && evaluated.node.kind !== "root" && evaluated.node.kind !== "backend") count = 1;
    var kids = evaluated.children || [];
    for (var i = 0; i < kids.length; i += 1) count += countVisibleNodes(kids[i]);
    return count;
}

function countPrunedNodes(evaluated) {
    if (!evaluated) return 0;
    var count = evaluated.pruned ? 1 : 0;
    var kids = evaluated.children || [];
    for (var i = 0; i < kids.length; i += 1) count += countPrunedNodes(kids[i]);
    return count;
}

function collectNodeIds(evaluated, out) {
    if (!out) out = {};
    if (!evaluated) return out;
    if (evaluated.node && evaluated.node.id) out[evaluated.node.id] = true;
    var kids = evaluated.children || [];
    for (var i = 0; i < kids.length; i += 1) collectNodeIds(kids[i], out);
    return out;
}

function collectCandidateIndex(evaluated) {
    var index = {};
    function walk(ev) {
        if (!ev || !ev.node) return;
        var id = ev.node.id;
        if (id && !ev.pruned) {
            index[id] = {
                nodeId: id,
                label: ev.node.label || "",
                kind: ev.node.kind || "",
                backendId: ev.node.backendId || "",
                path: ev.node.path || [],
                placement: ev._placement || "",
                visible: !!ev.visible,
                score: ev.score || 0,
                ownScore: ev.ownScore || 0
            };
        }
        var kids = ev.children || [];
        for (var i = 0; i < kids.length; i += 1) walk(kids[i]);
    }
    walk(evaluated);
    return index;
}

function attachDecisionReasons(node, row, decisionTrace, evidenceTrace, scoreTrace) {
    if (!node) return;
    var reasons = {};
    var nid = node.id;

    // Shown reason
    var shownReasons = [];
    if (row) {
        if (row.ownVisible && row.ownScore > 0) {
            shownReasons.push({ code: "own_match", text: "Node matches query with own evidence (score=" + (row.ownScore || 0).toFixed(3) + ")" });
        } else if (row.ownVisible) {
            shownReasons.push({ code: "own_visible", text: "Node is own-visible in results (score=" + (row.ownScore || 0).toFixed(3) + ")" });
        } else {
            shownReasons.push({ code: "visible", text: "Node is visible in results" });
        }
    } else {
        shownReasons.push({ code: "visible", text: "Node is visible in results" });
    }

    // Placement reason
    var placementReasons = [];
    var placement = node.placement || "";
    var decision = decisionTrace ? decisionTrace[nid] : null;
    if (decision && decision.placement) {
        placementReasons.push(decision.placement.reasons && decision.placement.reasons.length > 0
            ? decision.placement.reasons[0]
            : { code: "placement", text: "Placement: " + placement });
    } else {
        placementReasons.push({ code: "placement", text: "Placement: " + placement });
    }

    // Action reason
    var actionReasons = [];
    if (row) {
        var ra = row.actions || [];
        if (ra.length > 0) {
            actionReasons.push({ code: "has_actions", text: "Node has " + ra.length + " action(s)" });
        } else if (row.switchActions) {
            var sk = Object.keys(row.switchActions);
            actionReasons.push({ code: "has_switch_actions", text: "Node has " + sk.length + " switch action(s)" });
        }
    }

    node.reasons = {
        shown: shownReasons,
        placement: placementReasons,
        children: decision && decision.childVisibility ? [{ code: "child_visibility", text: "Child visibility decided by policies" }] : [],
        action: actionReasons
    };

    // Compact match info
    var evidence = evidenceTrace ? evidenceTrace[nid] : null;
    if (evidence) {
        node.compactMatch = {
            matchedTokens: (evidence.matchedTokens || []).slice(0, 10),
            consumedTokens: (evidence.consumedTokens || []).slice(0, 10),
            missingTokens: (evidence.missingTokens || []).slice(0, 5)
        };
    }

    // Compact score
    var score = scoreTrace ? scoreTrace[nid] : null;
    if (score) {
        node.compactScore = {
            final: score.final !== undefined ? score.final : null,
            own: score.own !== undefined ? score.own : null,
            parent: score.parent !== undefined ? score.parent : null,
            child: score.child !== undefined ? score.child : null
        };
    }

    // Hidden/filtered counts
    node.hiddenChildCount = 0;
    node.filteredChildCount = 0;
}

function collectVisibleTree(rows, decisionTrace, evidenceTrace, scoreTrace, maxDepth) {
    if (maxDepth === undefined) maxDepth = 10;
    var result = [];
    if (!rows) return result;
    for (var ri = 0; ri < rows.length; ri += 1) {
        var row = rows[ri];
        var node = rowToVisibleNode(row, 0, maxDepth, decisionTrace, evidenceTrace, scoreTrace);
        if (node) result.push(node);
    }
    return result;
}

function rowToVisibleNode(row, depth, maxDepth, decisionTrace, evidenceTrace, scoreTrace) {
    if (!row || depth > maxDepth) return null;
    var nid = row.nodeId || row.id || "";
    if (!nid) return null;
    var trace = decisionTrace ? decisionTrace[nid] : null;
    var decisions = {
        visibility: trace && trace.visibility ? { value: trace.visibility.value, reasons: (trace.visibility.reasons || []) } : {
            value: { visible: true },
            source: "row-materialization",
            reasons: [{ code: "materialized_visible_row", text: "Row is visible because result shaping materialized it into the final row model." }]
        },
        placement: trace && trace.placement ? { value: trace.placement.value, reasons: (trace.placement.reasons || []) } : {
            value: row.placement || "standalone",
            source: "row-materialization",
            reasons: [{ code: "materialized_placement", text: "Placement was assigned during result shaping row materialization." }]
        },
        flattening: trace && trace.flattening ? { value: trace.flattening.value, reasons: (trace.flattening.reasons || []) } : null,
        breadcrumbs: trace ? trace.breadcrumbs || null : null,
        defaultAction: trace ? trace.defaultAction || null : null,
        childVisibility: trace ? trace.childVisibility || null : null
    };
    var node = {
        id: nid,
        title: row.title || row.label || "",
        kind: row.kind || "",
        depth: depth,
        placement: row.placement || "",
        visible: true,
        executable: !!row.executable || !!row.hasAction,
        score: row.score || 0,
        ownScore: row.ownScore || 0,
        defaultAction: row.defaultAction ? { name: row.defaultAction.id || "", label: row.defaultAction.label || "" } : null,
        breadcrumbText: row.breadcrumbText || "",
        decisions: decisions,
        children: []
    };
    attachDecisionReasons(node, row, decisionTrace, evidenceTrace, scoreTrace);
    var childRows = row.children || [];
    for (var ci = 0; ci < childRows.length; ci += 1) {
        var childResult = rowToVisibleNode(childRows[ci], depth + 1, maxDepth, decisionTrace, evidenceTrace, scoreTrace);
        if (childResult) node.children.push(childResult);
    }
    return node;
}

function collectFlatVisibleRows(rows) {
    if (!rows) return [];
    var result = [];
    function walk(rowList) {
        if (!rowList) return;
        for (var i = 0; i < rowList.length; i += 1) {
            var r = rowList[i];
            result.push({
                id: r.nodeId || r.id || "",
                title: r.title || r.label || "",
                kind: r.kind || "",
                placement: r.placement || "",
                visible: true,
                score: r.score || 0,
                ownScore: r.ownScore || 0
            });
            walk(r.children);
        }
    }
    walk(rows);
    return result;
}

function build(query, pipelineOutput, ctx) {
    var evaluated = pipelineOutput.evaluatedRoot;
    var shapedResult = pipelineOutput.shapedResult;
    var rows = pipelineOutput.rows || [];
    var timings = pipelineOutput.timings || {};
    var phases = pipelineOutput.phases || [];
    var directive = pipelineOutput.directive || { active: false };

    var stats = emptyStats();
    stats.durationMs = timings.totalMs || 0;
    stats.evaluatedNodeCount = evaluated ? countEvaluatedNodes(evaluated) : 0;
    stats.finalVisibleRowCount = (rows || []).length;
    stats.finalVisibleTreeNodeCount = rows ? countAllRows(rows) : 0;
    stats.visibleNodeCount = stats.finalVisibleTreeNodeCount;
    stats.evaluatedVisibleCandidateCount = evaluated ? countVisibleNodes(evaluated) : 0;
    stats.prunedNodeCount = evaluated ? countPrunedNodes(evaluated) : 0;
    stats.backendCount = (ctx._activeBackends || []).length;
    stats.participatingBackendCount = (ctx._participatingBackends || []).length;
    stats.candidateCount = ctx.candidateCount || 0;
    stats.hiddenCandidateCount = Math.max(0, stats.evaluatedNodeCount - stats.evaluatedVisibleCandidateCount - stats.prunedNodeCount);

    // Populate per-backend counts from actual evaluation data
    var backendRowCounts = {};
    for (var bri = 0; bri < rows.length; bri += 1) {
        var br = rows[bri];
        var bid = br.backendId || (br.metadata && br.metadata.backendId) || "";
        if (bid) {
            if (!backendRowCounts[bid]) backendRowCounts[bid] = 0;
            backendRowCounts[bid] += 1;
        }
    }

    var backendCandidateCounts = {};
    if (ctx.candidateIds) {
        for (var cid in ctx.candidateIds) {
            if (!Object.prototype.hasOwnProperty.call(ctx.candidateIds, cid)) continue;
            var cidParts = cid.split(":");
            var cBackend = cidParts.length > 0 ? cidParts[0] : "";
            if (!cBackend) continue;
            if (!backendCandidateCounts[cBackend]) backendCandidateCounts[cBackend] = 0;
            backendCandidateCounts[cBackend] += 1;
        }
    }

    // Backend traces
    var backendTrace = [];
    var activeBackends = ctx._activeBackends || [];
    for (var bi = 0; bi < activeBackends.length; bi += 1) {
        var b = activeBackends[bi];
        var bid = b.backendId || b.name || String(bi);
        var participated = (ctx._participatingBackends || []).indexOf(b) >= 0;
        backendTrace.push({
            backend: bid,
            participated: participated,
            candidateCount: backendCandidateCounts[bid] || 0,
            visibleCount: backendRowCounts[bid] || 0,
            durationMs: ctx.backendTimings ? (ctx.backendTimings["root:" + bid] || 0) : 0,
            reasons: participated
                ? [{ code: "backend_participated", text: bid + " participated in query evaluation" }]
                : [{ code: "backend_excluded", text: bid + " was excluded by directive or participation check" }]
        });
    }

    // Attach placement from shaped results to evaluated nodes (BEFORE visible tree construction)
    if (shapedResult && shapedResult.shaped) {
        for (var si = 0; si < shapedResult.shaped.length; si += 1) {
            var item = shapedResult.shaped[si];
            if (item.ev && item.ev.node) {
                item.ev._placement = item.placement || "";
            }
        }
    }

    // Candidate index
    var candidateIndex = evaluated ? collectCandidateIndex(evaluated) : {};

    // Trace containers (populated during evaluation)
    var evidenceTrace = ctx._evidenceTrace || {};
    var scoreTrace = ctx._scoreTrace || {};
    var policyTrace = ctx._policyTrace || {};
    var decisionTrace = ctx._decisionTrace || {};

    // Visible tree built from rows (what user actually sees), not raw evaluated tree
    var visibleTree = collectVisibleTree(rows, decisionTrace, evidenceTrace, scoreTrace);
    var flatVisibleRows = collectFlatVisibleRows(rows);

    // Selection state
    var selection = {
        selectedId: rows.length > 0 ? (rows[0].nodeId || "") : "",
        selectedIndex: 0,
        selectedTitle: rows.length > 0 ? (rows[0].title || "") : "",
        reasons: [{ code: "first_row_selected", text: "First visible row in sorted result is auto-selected" }]
    };

    // Collect actions from rows — uses REAL resolver paths (row.recipes from RenderedRows)
    var actionIndex = {};
    for (var ri = 0; ri < rows.length; ri += 1) {
        var row = rows[ri];
        var nid = row.nodeId || row.id || "";
        if (!nid) continue;
        var actions = {};

        if (row.enter) {
            var enterSteps = [];
            if (row.recipes && row.recipes.activate && Array.isArray(row.recipes.activate)) {
                enterSteps = row.recipes.activate.map(function(s, i) {
                    return makeActionStep(i, s.name || "step", s.name || "", s.args ? safePayload(s.args) : null);
                });
            } else if (row.enter.steps && Array.isArray(row.enter.steps)) {
                enterSteps = row.enter.steps.map(function(s, i) {
                    return makeActionStep(i, s.type || "step", s.type || "", s.value ? String(s.value) : null);
                });
            }
            actions["enter"] = makeActionResolution(
                nid, "enter", true,
                row.enter.type || "activate",
                row.title || "",
                "row-builder",
                [{ code: "enter_action", text: "Enter activates this row with type " + (row.enter.type || "activate") }],
                enterSteps
            );
        }

        if (row.shiftEnter) {
            actions["shift-enter"] = makeActionResolution(
                nid, "shift-enter", true,
                row.shiftEnter.type || "noop",
                row.title || "",
                "row-builder",
                [{ code: "shift_enter_action", text: "Shift+Enter activates this row" }],
                []
            );
        }

        // Tab/complete action from row.recipes
        if (row.recipes && row.recipes.complete && Array.isArray(row.recipes.complete)) {
            var completeSteps = row.recipes.complete.map(function(s, i) {
                return makeActionStep(i, s.name || "step", s.name || "", s.args ? safePayload(s.args) : null);
            });
            actions["complete"] = makeActionResolution(
                nid, "complete", true,
                "edit-query",
                row.title || "",
                "recipe-resolver",
                [{ code: "complete_recipe", text: "Complete replaces query from recipe" }],
                completeSteps
            );
        }

        // Interaction keys (h, l, m) from row.interactions
        if (row.interactions && typeof row.interactions === "object") {
            for (var ik in row.interactions) {
                if (!Object.prototype.hasOwnProperty.call(row.interactions, ik)) continue;
                var ikv = row.interactions[ik];
                if (!ikv || !ikv.recipe) continue;
                var ikSteps = (Array.isArray(ikv.recipe) ? ikv.recipe : []).map(function(s, i) {
                    return makeActionStep(i, s.name || "step", s.name || "", s.args ? safePayload(s.args) : null);
                });
                actions[ik] = makeActionResolution(
                    nid, ik, true,
                    ikv.label || ik,
                    row.title || "",
                    "recipe-resolver",
                    [{ code: "interaction_recipe", text: "Interaction key '" + ik + "' runs " + (ikv.label || ik) }],
                    ikSteps
                );
            }
        }

        if (Object.keys(actions).length > 0) actionIndex[nid] = actions;
    }

    // Trace containers (already declared above)
    // (declared before visible tree construction)

    // Validation: cross-check candidateIndex vs rows
    var validation = { ok: true, errors: [], warnings: [] };
    var visibleInRows = {};
    for (var fi = 0; fi < flatVisibleRows.length; fi += 1) {
        visibleInRows[flatVisibleRows[fi].id] = true;
    }
    for (var cid in candidateIndex) {
        if (!Object.prototype.hasOwnProperty.call(candidateIndex, cid)) continue;
        var ci = candidateIndex[cid];
        if (ci.visible && !visibleInRows[cid]) {
            validation.warnings.push({
                code: "candidate-visible-not-in-rows",
                nodeId: cid,
                label: ci.label,
                text: "Candidate marked visible in evaluated tree but does not appear in final rows"
            });
        }
    }

    // Validation: every executable visible row must have actionIndex enter
    for (var eri = 0; eri < rows.length; eri += 1) {
        var erow = rows[eri];
        var eid = erow.nodeId || erow.id || "";
        if (!eid) continue;
        if (erow.executable) {
            var act = actionIndex[eid];
            if (!act || !act.enter || !act.enter.exists) {
                validation.errors.push({
                    code: "executable_missing_action",
                    nodeId: eid,
                    label: erow.title || "",
                    text: "Executable visible row has no actionIndex.enter — must have enter action or set executable=false"
                });
                validation.ok = false;
            }
        }
    }

    // Validation: check stats consistency
    var visibleRowCount = (rows || []).length;
    if (stats.finalVisibleRowCount !== visibleRowCount) {
        validation.warnings.push({
            code: "stats-row-count-mismatch",
            nodeId: "",
            label: "",
            text: "stats.finalVisibleRowCount (" + stats.finalVisibleRowCount + ") != rows.length (" + visibleRowCount + ")"
        });
    }

    if (validation.warnings.length > 0) validation.ok = false;

    var evaluation = {
        queryRevision: 0,
        query: {
            raw: query ? query.raw || "" : "",
            normalized: query ? query.raw ? String(query.raw).toLowerCase().trim() : "" : "",
            tokens: (query && query.tokens || []).map(function(t, i) {
                return { index: i, text: t.raw || "", normalized: t.normalized || "" };
            }),
            isEmpty: query ? !!query.isEmpty : true,
            lastTokenEmpty: query ? !!query.lastTokenEmpty : false,
            directive: {
                active: !!directive.active,
                prefix: directive.prefix || "",
                label: directive.label || "",
                backendIds: directive.backendIds || []
            }
        },

        visibleTree: visibleTree,
        flatVisibleRows: flatVisibleRows,
        rows: rows,

        candidateIndex: candidateIndex,

        backendTrace: backendTrace,

        evidenceTrace: evidenceTrace,
        scoreTrace: scoreTrace,
        policyTrace: policyTrace,
        decisionTrace: decisionTrace,
        actionIndex: actionIndex,

        selection: selection,

        stats: stats,
        validation: validation
    };

    return evaluation;
}
