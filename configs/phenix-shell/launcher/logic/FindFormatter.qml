import QtQml
import qs.services

BaseFormatter {
    readonly property var tracer: Logger.scope("launcher.formatter.find", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.formatter.find", { category: "launcher" })
    formatterName: "find"

    function serialize(evaluation, request) {
        tracer.trace("serialize", function() { return { search: request?.search, backend: request?.backend }; });
        if (!evaluation) return { error: { code: "no_evaluation", message: "No evaluation available" } };
        var search = String(request.search || "").toLowerCase().trim();
        if (!search) return { error: { code: "no_search", message: "search string is required" } };

        var backend = request.backend || "";
        var includeHidden = request.includeHidden !== false;
        var maxResults = Math.max(1, Math.min((request.maxResults || 50), 200));

        var matches = [];

        var candidateIndex = evaluation.candidateIndex || {};
        var visibleIds = collectVisibleIds(evaluation.visibleTree || []);

        for (var id in candidateIndex) {
            var ci = candidateIndex[id];
            if (backend && ci.backendId !== backend) continue;
            if (!matchesCandidate(ci, search)) continue;

            var visible = visibleIds.indexOf(id) >= 0;
            var reasons = buildFindReasons(ci, id, evaluation, visible);

            var et = evaluation.evidenceTrace ? evaluation.evidenceTrace[id] : null;
            var st = evaluation.scoreTrace ? evaluation.scoreTrace[id] : null;

            matches.push({
                id: id,
                title: ci.label || "",
                kind: ci.kind || "",
                backend: ci.backendId || "",
                path: ci.path || [],
                visible: visible,
                placement: ci.placement || "",
                compactMatch: {
                    matchedTokens: et ? (et.matchedTokens || []) : [],
                    consumedTokens: et ? (et.consumedTokens || []) : [],
                    missingTokens: et ? (et.missingTokens || []) : []
                },
                compactScore: {
                    final: st ? st.final : (ci.score || 0),
                    own: st ? st.own : (ci.ownScore || 0),
                    parent: st ? st.parent : null,
                    child: st ? st.child : null
                },
                reasons: reasons,
                inspectable: true
            });

            if (matches.length >= maxResults) break;
        }

        // notFound diagnostics when nothing matches
        var notFoundDiagnostics = [];

        if (matches.length === 0) {
            // Check if search term exists in any candidate label at all
            var allLabels = Object.keys(candidateIndex).map(function(cid) {
                return { id: cid, label: (candidateIndex[cid].label || "").toLowerCase(), backendId: candidateIndex[cid].backendId || "" };
            });
            var partialMatch = allLabels.some(function(l) { return l.label.indexOf(search) >= 0; });

            if (!partialMatch) {
                notFoundDiagnostics.push({ code: "no_partial_match", text: "No candidate label contains '" + search + "' — check search spelling, backend availability, or query constraints" });
            } else if (backend) {
                notFoundDiagnostics.push({ code: "backend_filter", text: "Candidates exist matching '" + search + "' but none from backend '" + backend + "' — check backend participation in stats" });
            }

            // Fallback: search visible tree directly
            var visibleMatches = searchVisibleTree(evaluation.visibleTree || [], search, backend);
            for (var vi = 0; vi < visibleMatches.length && matches.length < maxResults; vi += 1) {
                var vm = visibleMatches[vi];
                matches.push({
                    id: vm.id,
                    title: vm.title,
                    kind: vm.kind || "",
                    backend: vm.backend || "",
                    path: [],
                    visible: true,
                    placement: vm.placement || "",
                    compactMatch: { matchedTokens: [], consumedTokens: [], missingTokens: [] },
                    compactScore: { final: vm.score || 0, own: vm.ownScore || 0, parent: null, child: null },
                    reasons: { found: [{ code: "visible_tree_match", text: "Found in visible tree matching '" + search + "'" }], visibility: [{ code: "visible", text: "Node is visible" }] },
                    inspectable: true
                });
            }

            if (matches.length === 0) {
                // Still nothing — add backend-level diagnostics (backendTrace is an array, iterate explicitly)
                var backendTraces = evaluation.backendTrace || [];
                for (var bti = 0; bti < backendTraces.length; bti += 1) {
                    var bt = backendTraces[bti];
                    if (!bt) continue;
                    var btId = bt.backend || String(bti);
                    if (!bt.participated) {
                        notFoundDiagnostics.push({ code: "backend_not_participating", text: "Backend '" + btId + "' did not participate: " + (bt.reasons ? bt.reasons.join(", ") : "no reason") + " (duration " + bt.durationMs + "ms)" });
                    } else if (bt.candidateCount === 0) {
                        notFoundDiagnostics.push({ code: "backend_no_candidates", text: "Backend '" + btId + "' participated but returned 0 candidates (duration " + bt.durationMs + "ms)" });
                    }
                }
            }
        }

        return {
            search: search,
            matches: matches,
            truncated: matches.length >= maxResults,
            notFound: notFoundDiagnostics.length > 0 ? notFoundDiagnostics : undefined
        };
    }

    function matchesCandidate(ci, search) {
        var label = (ci.label || "").toLowerCase();
        if (label.indexOf(search) >= 0) return true;
        var id = (ci.nodeId || "").toLowerCase();
        if (id.indexOf(search) >= 0) return true;
        var kind = (ci.kind || "").toLowerCase();
        if (kind.indexOf(search) >= 0) return true;
        var backend = (ci.backendId || "").toLowerCase();
        if (backend.indexOf(search) >= 0) return true;
        var path = (ci.path || []).join(" ").toLowerCase();
        if (path.indexOf(search) >= 0) return true;
        return false;
    }

    function buildFindReasons(ci, id, evaluation, visible) {
        var reasons = {
            found: [{ code: "candidate_index_match", text: "Found in candidate index matching search" }],
            visibility: [],
            hidden: [],
            placement: [],
            evidence: [],
            score: [],
            diagnostics: []
        };

        // Use real evidence trace for match explanations
        var et = evaluation.evidenceTrace ? evaluation.evidenceTrace[id] : null;
        if (et) {
            var matched = et.matchedTokens || [];
            var consumed = et.consumedTokens || [];
            var missing = et.missingTokens || [];
            var fields = et.fields || [];
            if (matched.length > 0) {
                reasons.found = [{ code: "evidence_match", text: "Node matched " + matched.length + " token(s): " + matched.join(", ") }];
            } else {
                reasons.found = [{ code: "no_token_match", text: "Node in candidate index but has no token match evidence" }];
                reasons.diagnostics.push({ code: "no_token_evidence", text: "Candidate exists in index but produced no evidence traces — check backend evaluation" });
            }
            if (fields.length > 0) {
                reasons.evidence = fields.slice(0, 5).map(function(f) {
                    return { code: "field", text: "Field '" + f.name + "' matched '" + (f.value || "").slice(0, 40) + "' (weight=" + f.weight + ")" };
                });
            }
            reasons.matching = {
                matchedCount: matched.length,
                consumedCount: consumed.length,
                missingCount: missing.length
            };
        }

        // Score trace diagnostics
        var st = evaluation.scoreTrace ? evaluation.scoreTrace[id] : null;
        if (st) {
            reasons.score.push({ code: "final_score", text: "Final score: " + (st.final || 0).toFixed(4) });
            if (st.own !== undefined) reasons.score.push({ code: "own_score", text: "Own score: " + (st.own || 0).toFixed(4) });
            if (st.parent !== undefined) reasons.score.push({ code: "parent_score", text: "Parent score: " + st.parent.toFixed(4) });
            if (st.child !== undefined) reasons.score.push({ code: "child_score", text: "Child score: " + st.child.toFixed(4) });
        }

        // Decision trace for visibility/placement/policy
        var dt = evaluation.decisionTrace ? evaluation.decisionTrace[id] : null;

        if (visible) {
            reasons.visibility.push({ code: "visible", text: "Node is visible in results" });
            if (dt && dt.visibility) {
                reasons.visibility.push(dt.visibility);
            }
        } else {
            reasons.visibility.push({ code: "hidden", text: "Node is not visible in final results" });

            // Specific hidden diagnostics
            if (dt && dt.visibility) {
                reasons.hidden.push(dt.visibility);
            }

            // Score threshold check
            if (st && st.final !== undefined) {
                var threshold = 0.1;
                if (st.final < threshold) {
                    reasons.hidden.push({ code: "below_score_threshold", text: "Score " + (st.final || 0).toFixed(4) + " is below visibility threshold " + threshold });
                }
            }

            // Parent suppression check
            if (dt && dt.parent && dt.parent.value === "suppress") {
                reasons.hidden.push({ code: "parent_suppressed", text: "Parent decision suppressed visibility: " + (dt.parent.reason || "policy decision") });
            }

            // Child visibility filtering
            if (dt && dt.childVisibility && dt.childVisibility.value === "hide") {
                reasons.hidden.push({ code: "child_visibility_filtered", text: "Child visibility filter hid node: " + (dt.childVisibility.reason || "policy decision") });
            }

            // Backend participation
            var bt = backendTraceById(evaluation.backendTrace, ci.backendId || "");
            if (bt && !bt.participated) {
                reasons.hidden.push({ code: "backend_skipped", text: "Backend '" + (ci.backendId || "") + "' did not participate (reasons: " + (bt.reasons || []).join(", ") + ")" });
            }
        }

        var placement = ci.placement || "";
        if (placement) {
            reasons.placement.push({ code: "placement", text: "Placement: " + placement });
        }

        return reasons;
    }

    function collectVisibleIds(nodes) {
        var ids = [];
        function walk(list) {
            for (var i = 0; i < (list || []).length; i += 1) {
                ids.push(list[i].id || "");
                walk(list[i].children);
            }
        }
        walk(nodes);
        return ids;
    }

    function backendTraceById(backendTrace, backendId) {
        if (!backendTrace || !backendId) return null;
        for (var bti = 0; bti < backendTrace.length; bti += 1) {
            if (backendTrace[bti] && (backendTrace[bti].backend || "") === backendId)
                return backendTrace[bti];
        }
        return null;
    }

    function searchVisibleTree(nodes, search, backend) {
        var matches = [];
        function walk(list) {
            for (var i = 0; i < (list || []).length; i += 1) {
                var n = list[i];
                var title = (n.title || "").toLowerCase();
                var id = (n.id || "").toLowerCase();
                if ((title.indexOf(search) >= 0 || id.indexOf(search) >= 0) && (!backend || (n.backend || "") === backend)) {
                    matches.push(n);
                }
                walk(n.children);
            }
        }
        walk(nodes);
        return matches;
    }
}
