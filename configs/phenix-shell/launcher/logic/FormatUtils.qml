pragma Singleton
import QtQml
import Quickshell
import qs.services

QtObject {
    property int version: 1
    readonly property var prof: Profiler.scope("launcher.formatUtils", { category: "launcher" })
    readonly property var tracer: Logger.scope("launcher.formatUtils", { category: "launcher" })


    // ── Envelope ──────────────────────────────────────────────

    function make(mode, queryInfo, result, source) {
        tracer.trace("make", function() { return { mode: mode, queryLen: (queryInfo && queryInfo.raw || "").length, source: source || "query" }; });
        var envelope = {
            version: version,
            mode: String(mode || "unknown"),
            query: queryInfo ? (queryInfo.raw || "") : "",
            normalizedQuery: queryInfo ? (queryInfo.raw ? String(queryInfo.raw).toLowerCase().trim() : "") : "",
            tokens: (queryInfo && queryInfo.tokens || []).map(function(t, i) {
                return { index: i, text: t.raw || "", normalized: t.normalized || "" };
            }),
            evaluationId: null,
            source: source || "query",
            result: result !== undefined ? result : null,
            warnings: []
        };
        return envelope;
    }

    function withWarning(envelope, code, message) {
        if (!envelope.warnings) envelope.warnings = [];
        envelope.warnings.push({ code: code, message: message });
        return envelope;
    }

    function errorResult(code, message, extra) {
        tracer.warn("errorResult", function() { return { code: code, message: message }; });
        var err = { error: { code: code, message: message } };
        if (extra) {
            for (var key in extra) {
                err.error[key] = extra[key];
            }
        }
        return err;
    }

    function nodeNotFound(nodeId, availableIds) {
        var err = errorResult("node_not_found", "No candidate with id '" + nodeId + "' exists in this evaluation.");
        if (availableIds && availableIds.length > 0) {
            err.available_ids = availableIds.slice(0, 50);
        }
        return err;
    }

    function modeError(mode, reason) {
        return errorResult("mode_error", "Cannot resolve debug mode '" + mode + "': " + reason);
    }

    // ── JSON safety ──────────────────────────────────────────

    function findInvalidJsonValue(value, path, seen, seenPaths) {
        if (seen === undefined) seen = [];
        if (seenPaths === undefined) seenPaths = [];
        if (value === undefined)
            return { path: path, reason: "undefined", preview: "undefined" };
        if (typeof value === "function")
            return { path: path, reason: "function", preview: "function" };
        if (typeof value === "symbol")
            return { path: path, reason: "symbol", preview: "symbol" };
        if (typeof value === "number" && !isFinite(value))
            return { path: path, reason: "non-finite number", preview: String(value) };
        if (value === null || typeof value === "string" || typeof value === "number" || typeof value === "boolean")
            return null;
        if (typeof value !== "object")
            return { path: path, reason: typeof value, preview: String(value) };

        var proto = Object.getPrototypeOf(value);
        if (proto !== null && proto !== Object.prototype && proto !== Array.prototype)
            return { path: path, reason: "non-plain-object", preview: proto.constructor ? proto.constructor.name : "unknown" };
        if (value instanceof Date)
            return { path: path, reason: "Date", preview: String(value) };
        if (typeof Map !== "undefined" && value instanceof Map)
            return { path: path, reason: "Map", preview: "Map(" + value.size + ")" };
        if (typeof Set !== "undefined" && value instanceof Set)
            return { path: path, reason: "Set", preview: "Set(" + value.size + ")" };
        if (value instanceof RegExp)
            return { path: path, reason: "RegExp", preview: String(value) };
        if (typeof Promise !== "undefined" && value instanceof Promise)
            return { path: path, reason: "Promise", preview: "Promise" };

        var seenIndex = seen.indexOf(value);
        if (seenIndex >= 0)
            return { path: path, reason: "cycle", preview: "first seen at " + seenPaths[seenIndex] };

        seen.push(value);
        seenPaths.push(path);

        if (Array.isArray(value)) {
            for (var ai = 0; ai < value.length; ai += 1) {
                var arrInvalid = findInvalidJsonValue(value[ai], path + "[" + ai + "]", seen, seenPaths);
                if (arrInvalid) { seen.pop(); seenPaths.pop(); return arrInvalid; }
            }
        } else {
            for (var key in value) {
                var child = value[key];
                var invalid = findInvalidJsonValue(child, path + "." + key, seen, seenPaths);
                if (invalid) { seen.pop(); seenPaths.pop(); return invalid; }
            }
        }

        seen.pop();
        seenPaths.pop();
        return null;
    }

    function toJsonSafe(value) {
        var seen = [];
        return toJsonSafeImpl(value, seen);
    }

    function toJsonSafeImpl(value, seen) {
        if (value === undefined || value === null) return null;
        var t = typeof value;
        if (t === "string" || t === "number" || t === "boolean") return value;
        if (t === "function" || t === "symbol") return null;
        if (Array.isArray(value)) {
            var out = [];
            for (var i = 0; i < value.length; i += 1) {
                out.push(toJsonSafeImpl(value[i], seen));
            }
            return out;
        }
        if (t === "object") {
            var idx = seen.indexOf(value);
            if (idx >= 0) return "[cycle]";
            seen.push(value);

            var proto = Object.getPrototypeOf(value);
            if (proto !== null && proto !== Object.prototype && proto !== Array.prototype) {
                seen.pop();
                return String(value);
            }
            if (
                value instanceof Date ||
                (typeof Map !== "undefined" && value instanceof Map) ||
                (typeof Set !== "undefined" && value instanceof Set) ||
                value instanceof RegExp ||
                (typeof Promise !== "undefined" && value instanceof Promise)
            ) {
                seen.pop();
                return String(value);
            }
            var out = {};
            Object.keys(value).forEach(function(key) {
                var child = value[key];
                if (typeof child === "function" || typeof child === "symbol") return;
                out[key] = toJsonSafeImpl(child, seen);
            });
            seen.pop();
            return out;
        }
        return String(value);
    }

    function validateJsonSafe(label, value) {
        var invalid = findInvalidJsonValue(value, "$", [], []);
        if (invalid) {
            console.warn("[DEBUG IPC JSON INVALID] " + label + " path=" + invalid.path + " reason=" + invalid.reason + " preview=" + invalid.preview);
            return false;
        }
        return true;
    }

    function assertJsonSafe(value) {
        var invalid = findInvalidJsonValue(value, "$", [], []);
        if (invalid) throw new Error("JSON-safe violation: " + invalid.path + " " + invalid.reason);
        return true;
    }

    // ── Debug IDs ────────────────────────────────────────────

    function backendPrefix(backendId) {
        return String(backendId || "").toLowerCase().replace(/[^a-z0-9]/g, "-");
    }

    function sanitizeSegment(segment) {
        return String(segment || "").toLowerCase().replace(/[^a-z0-9_-]/g, "-").replace(/-+/g, "-").replace(/^-|-$/g, "");
    }

    function makeId(backendId, pathParts, actionId) {
        var parts = [sanitizeSegment(backendId)];
        if (pathParts && Array.isArray(pathParts)) {
            for (var i = 0; i < pathParts.length; i += 1) {
                var s = sanitizeSegment(pathParts[i]);
                if (s) parts.push(s);
            }
        } else if (pathParts && typeof pathParts === "string") {
            var s = sanitizeSegment(pathParts);
            if (s) parts.push(s);
        }
        if (actionId) {
            var a = sanitizeSegment(actionId);
            if (a) parts.push(a);
        }
        return parts.join(":");
    }

    function makeIdFromNode(node) {
        if (!node) return "";
        var backendId = node.backendId || node.source || node.backend || "";
        var label = node.label || node.title || node.name || "";
        var actionId = node.actionId || "";
        var path = node.path || [];
        if (!Array.isArray(path)) path = [path];
        var parts = [sanitizeSegment(backendId)];
        if (label) parts.push(sanitizeSegment(label));
        for (var i = 0; i < path.length; i += 1) {
            var s = sanitizeSegment(path[i]);
            if (s) parts.push(s);
        }
        if (actionId) parts.push(sanitizeSegment(actionId));
        return parts.join(":");
    }

    function validateUniqueIds(nodes) {
        var seen = {};
        var duplicates = [];
        function walk(node) {
            if (!node) return;
            if (node.id) {
                if (seen[node.id]) {
                    duplicates.push(node.id);
                } else {
                    seen[node.id] = true;
                }
            }
            var children = node.children || [];
            for (var i = 0; i < children.length; i += 1) walk(children[i]);
        }
        for (var i = 0; i < nodes.length; i += 1) walk(nodes[i]);
        return {
            ok: duplicates.length === 0,
            duplicates: duplicates,
            uniqueCount: Object.keys(seen).length
        };
    }

    function nodeIdPath(id) {
        if (!id) return [];
        return id.split(":").filter(function(p) { return p.length > 0; });
    }

    function idDepth(id) {
        return nodeIdPath(id).length;
    }

    function idPrefix(id) {
        var parts = nodeIdPath(id);
        if (parts.length <= 1) return "";
        return parts.slice(0, -1).join(":");
    }

    function idMatchesPrefix(id, prefix) {
        if (!prefix) return true;
        return id === prefix || id.indexOf(prefix + ":") === 0;
    }

    // ── Debug reasons ────────────────────────────────────────

    function reason(code, text, options) {
        var r = { code: code, text: text };
        if (options) {
            if (options.severity) r.severity = options.severity;
            if (options.relatedTokens) r.relatedTokens = options.relatedTokens;
            if (options.relatedNodeIds) r.relatedNodeIds = options.relatedNodeIds;
        }
        return r;
    }

    function groupReason(code, text, reasons) {
        return {
            code: code,
            text: text,
            subreasons: (reasons || []).slice()
        };
    }

    function warning(code, message) {
        return { code: code, message: message };
    }

    function validationIssue(code, message, severity, nodeId) {
        var v = { code: code, message: message, severity: severity || "warning" };
        if (nodeId) v.nodeId = nodeId;
        return v;
    }

    function mergeReasons(reasons) {
        var merged = [];
        for (var i = 0; i < (reasons || []).length; i += 1) {
            var r = reasons[i];
            if (!r) continue;
            merged.push(r);
        }
        return merged;
    }

    function reasonsToString(reasons) {
        return (reasons || []).map(function(r) { return "[" + r.code + "] " + r.text; }).join("; ");
    }

    // ── Validation ───────────────────────────────────────────

    function validate(evaluation) {
        if (!evaluation) {
            tracer.error("validate", function() { return { error: "null evaluation" }; });
            return { ok: false, errors: [{ code: "no_evaluation", message: "Evaluation is null", severity: "error" }], warnings: [] };
        }
        var errors = [];
        var warnings = [];

        var seenIds = {};
        var visibleRowCount = 0;
        function checkVisibleTree(nodes) {
            for (var i = 0; i < (nodes || []).length; i += 1) {
                var n = nodes[i];
                visibleRowCount += 1;
                if (!n.id || n.id === "") {
                    errors.push({ code: "visible_node_no_id", message: "Visible node '" + (n.title || "untitled") + "' has no id", severity: "error", nodeId: n.id || "" });
                } else if (seenIds[n.id]) {
                    warnings.push({ code: "duplicate_id", message: "Duplicate debug id '" + n.id + "'", severity: "warning", nodeId: n.id });
                } else {
                    seenIds[n.id] = true;
                }
                // Check decisions match placement
                if (n.decisions && n.decisions.placement) {
                    var decPlacement = n.decisions.placement.value;
                    if (typeof decPlacement === "object" && decPlacement.visible !== undefined) {
                        // visibility decision
                    } else if (typeof decPlacement === "string" && decPlacement !== n.placement) {
                        warnings.push({ code: "placement_mismatch", message: "Node '" + n.id + "' has placement '" + n.placement + "' but decision says '" + decPlacement + "'", severity: "warning", nodeId: n.id });
                    }
                }
                checkVisibleTree(n.children);
            }
        }
        if (evaluation.visibleTree) checkVisibleTree(evaluation.visibleTree);

        // Check visible tree count roughly matches stats
        if (evaluation.stats && evaluation.stats.visibleNodeCount > 0) {
            if (visibleRowCount > evaluation.stats.visibleNodeCount * 3) {
                warnings.push({ code: "visible_tree_mismatch", message: "Visible tree has " + visibleRowCount + " nodes but stats say " + evaluation.stats.visibleNodeCount + " visible", severity: "warning" });
            }
        }

        // Check visible tree vs rows consistency
        if (evaluation.visibleTree && evaluation.rows && evaluation.rows.length > 0) {
            function collectVisibleIds(nodes) {
                var ids = [];
                for (var vi = 0; vi < (nodes || []).length; vi += 1) {
                    ids.push(nodes[vi].id || "");
                    ids = ids.concat(collectVisibleIds(nodes[vi].children));
                }
                return ids;
            }
            var visIds = collectVisibleIds(evaluation.visibleTree);
            function collectRowIds(rows) {
                var ids = [];
                for (var ri = 0; ri < (rows || []).length; ri += 1) {
                    ids.push(rows[ri].nodeId || rows[ri].id || "");
                    ids = ids.concat(collectRowIds(rows[ri].children));
                }
                return ids;
            }
            var rowIds = collectRowIds(evaluation.rows);
            var missingInVis = rowIds.filter(function(rid) { return rid && visIds.indexOf(rid) < 0; });
            if (missingInVis.length > 0) {
                warnings.push({ code: "row_not_in_visible_tree", message: missingInVis.length + " row(s) not found in visible tree: " + missingInVis.slice(0, 5).join(", "), severity: "warning" });
            }
        }

        if (evaluation.selection && evaluation.selection.selectedId) {
            var selId = evaluation.selection.selectedId;
            var found = false;
            function findInTree(nodes) {
                for (var i = 0; i < (nodes || []).length; i += 1) {
                    if (nodes[i].id === selId) { found = true; return; }
                    findInTree(nodes[i].children);
                }
            }
            if (evaluation.visibleTree) findInTree(evaluation.visibleTree);
            if (!found) {
                warnings.push({ code: "selected_id_not_visible", message: "Selected id '" + selId + "' is not in visible tree", severity: "warning", nodeId: selId });
            }
        }

        var queryTokens = (evaluation.query && evaluation.query.tokens || []).map(function(t) { return t.normalized; });
        if (evaluation.evidenceTrace && queryTokens.length > 0) {
            for (var nid in evaluation.evidenceTrace) {
                var et = evaluation.evidenceTrace[nid];
                if (!et) continue;
                var consumed = et.consumedTokens || [];
                for (var ci = 0; ci < consumed.length; ci += 1) {
                    if (queryTokens.indexOf(consumed[ci]) < 0) {
                        warnings.push({ code: "consumed_token_not_in_query", message: "Node '" + nid + "' consumed token '" + consumed[ci] + "' not in query", severity: "warning", nodeId: nid });
                    }
                }
            }
        }

        // Mandatory decisions check: every visible node must have decisions with visibility and placement
        if (evaluation.visibleTree) {
            function checkDecisions(nodes) {
                for (var vi = 0; vi < (nodes || []).length; vi += 1) {
                    var n = nodes[vi];
                    var d = n.decisions;
                    if (!d) {
                        errors.push({ code: "no_decisions", message: "Visible node '" + (n.id || "unknown") + "' has no decisions object", severity: "error", nodeId: n.id || "" });
                    } else {
                        if (!d.visibility) {
                            errors.push({ code: "no_visibility_decision", message: "Visible node '" + (n.id || "unknown") + "' missing decisions.visibility", severity: "error", nodeId: n.id || "" });
                        }
                        if (!d.placement) {
                            errors.push({ code: "no_placement_decision", message: "Visible node '" + (n.id || "unknown") + "' missing decisions.placement", severity: "error", nodeId: n.id || "" });
                        }
                        if (d.visibility && !d.visibility.value) {
                            warnings.push({ code: "visibility_decision_no_value", message: "Node '" + n.id + "' visibility decision has no value (fallback used)", severity: "warning", nodeId: n.id });
                        }
                        if (d.placement && !d.placement.value) {
                            warnings.push({ code: "placement_decision_no_value", message: "Node '" + n.id + "' placement decision has no value (fallback used)", severity: "warning", nodeId: n.id });
                        }
                    }
                    checkDecisions(n.children);
                }
            }
            checkDecisions(evaluation.visibleTree);
        }

        // Action resolution check: executable nodes should have actionIndex entries
        if (evaluation.visibleTree && evaluation.actionIndex) {
            function checkActions(nodes) {
                for (var vi = 0; vi < (nodes || []).length; vi += 1) {
                    var n = nodes[vi];
                    if (n.executable) {
                        var hasEnter = evaluation.actionIndex[n.id] && evaluation.actionIndex[n.id]["enter"];
                        if (!hasEnter) {
                            warnings.push({ code: "executable_no_action", message: "Executable node '" + (n.id || "unknown") + "' has no actionIndex['enter'] entry", severity: "warning", nodeId: n.id || "" });
                        }
                    }
                    checkActions(n.children);
                }
            }
            checkActions(evaluation.visibleTree);
        }

        // Check decisionTrace consistency
        if (evaluation.decisionTrace && evaluation.visibleTree) {
            function collectVisIds(nodes) {
                var ids = {};
                for (var i = 0; i < (nodes || []).length; i += 1) {
                    if (nodes[i].id) ids[nodes[i].id] = true;
                    var childIds = collectVisIds(nodes[i].children);
                    for (var cid in childIds) ids[cid] = true;
                }
                return ids;
            }
            var visNodeIds = collectVisIds(evaluation.visibleTree);
            for (var did in evaluation.decisionTrace) {
                if (!visNodeIds[did] && (!evaluation.candidateIndex || !evaluation.candidateIndex[did])) {
                    warnings.push({ code: "decision_trace_orphan", message: "Decision trace for '" + did + "' has no visible node or candidate", severity: "warning", nodeId: did });
                }
            }
        }

        try {
            var json = JSON.stringify(evaluation);
            JSON.parse(json);
        } catch (e) {
            errors.push({ code: "json_unsafe", message: "Evaluation cannot be JSON-serialized: " + String(e), severity: "error" });
        }

        return {
            ok: errors.length === 0,
            errors: errors,
            warnings: warnings
        };
    }

    function mergeToEvaluation(evaluation) {
        if (!evaluation) return;
        var v = validate(evaluation);
        evaluation.validation = {
            ok: v.ok,
            errors: v.errors,
            warnings: v.warnings
        };
    }
}
