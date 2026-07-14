import QtQuick
import QtQml
import qs.services
import "../logic/"

Item {
    readonly property var tracer: Logger.scope("launcher.debug", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.debug", { category: "launcher" })
    id: root

    property var controller: null

    OverviewFormatter { id: _overviewFmt }
    InspectFormatter  { id: _inspectFmt }
    PoliciesFormatter { id: _policiesFmt }
    FindFormatter     { id: _findFmt }
    ActionFormatter   { id: _actionFmt }
    StatsFormatter    { id: _statsFmt }
    RawFormatter      { id: _rawFmt }

    function copyJsonValue(value, depth) {
        depth = depth === undefined ? 0 : depth;
        if (depth > 6 || value === undefined || typeof value === "function")
            return null;
        if (value === null || typeof value === "string" || typeof value === "number" || typeof value === "boolean")
            return value;
        if (Array.isArray(value))
            return value.map(function(item) { return root.copyJsonValue(item, depth + 1); });
        if (typeof value === "object") {
            var out = {};
            for (var key in value) {
                if (key === "raw" || key === "parent" || key === "execute")
                    continue;
                var copied = root.copyJsonValue(value[key], depth + 1);
                if (copied !== null)
                    out[key] = copied;
            }
            return out;
        }
        return null;
    }

    function jsonPreview(value) {
        if (value === undefined)
            return "undefined";
        if (value === null)
            return "null";
        if (typeof value === "string")
            return value.slice(0, 80);
        if (typeof value === "number" || typeof value === "boolean")
            return String(value);
        if (Array.isArray(value))
            return "array(" + value.length + ")";
        if (typeof value === "function")
            return "function";
        if (typeof value === "object")
            return Object.keys(value).slice(0, 8).join(",");
        return typeof value;
    }

    function findInvalidJsonValue(value, path, seen, seenPaths) {
        if (value === undefined)
            return { path: path, reason: "undefined", preview: root.jsonPreview(value) };
        if (typeof value === "function")
            return { path: path, reason: "function", preview: root.jsonPreview(value) };
        if (typeof value === "number" && !isFinite(value))
            return { path: path, reason: "non-finite number", preview: root.jsonPreview(value) };
        if (value === null || typeof value === "string" || typeof value === "number" || typeof value === "boolean")
            return null;
        if (typeof value !== "object")
            return { path: path, reason: typeof value, preview: root.jsonPreview(value) };

        var seenIndex = seen.indexOf(value);
        if (seenIndex >= 0)
            return { path: path, reason: "cycle", preview: "first seen at " + seenPaths[seenIndex] };
        seen.push(value);
        seenPaths.push(path);

        if (Array.isArray(value)) {
            for (var ai = 0; ai < value.length; ai += 1) {
                var arrInvalid = root.findInvalidJsonValue(value[ai], path + "[" + ai + "]", seen, seenPaths);
                if (arrInvalid)
                    return arrInvalid;
            }
        } else {
            for (var key in value) {
                var childValue = value[key];
                if ((key === "raw" || key === "parent" || key === "execute") && childValue && typeof childValue === "object")
                    return { path: path + "." + key, reason: "forbidden reference key", preview: root.jsonPreview(value[key]) };
                if (key === "execute" && typeof childValue === "function")
                    return { path: path + "." + key, reason: "forbidden executable function", preview: root.jsonPreview(value[key]) };
                var invalid = root.findInvalidJsonValue(childValue, path + "." + key, seen, seenPaths);
                if (invalid)
                    return invalid;
            }
        }

        seen.pop();
        seenPaths.pop();
        return null;
    }

    function logJsonValidation(label, value) {
        var invalid = root.findInvalidJsonValue(value, "$", [], []);
        if (invalid) {
            tracer.warn("jsonValidation", function() { return { label: label, path: invalid.path, reason: invalid.reason, preview: invalid.preview }; });
            return false;
        }
        return true;
    }

    function serializeRow(row, depth, options) {
        depth = depth === undefined ? 0 : depth;
        options = options || {};
        if (!row) return null;
        var out = {
            id: row.id || "",
            nodeId: row.nodeId || "",
            title: row.title || "",
            subtitle: row.subtitle || "",
            icon: row.icon || null,
            iconColor: row.iconColor ? String(row.iconColor) : null,
            depth: row.depth || 0,
            matchDepth: row.matchDepth === undefined ? row.depth || 0 : row.matchDepth,
            score: row.score || 0,
            ownScore: row.ownScore || 0,
            inheritedScore: row.inheritedScore || 0,
            descendantScore: row.descendantScore || 0,
            ownVisible: !!row.ownVisible,
            scoreBundle: row.scoreBundle ? ScoreBundle.toDebug(row.scoreBundle) : null,
            placement: row.placement || "",
            presentationContext: row.presentationContext || null,
            source: row.source || row.backendId || "",
            kind: row.kind || "",
            executable: !!row.executable,
            dangerous: !!row.dangerous,
            risk: root.copyJsonValue(row.risk),
            selectable: controller.isSelectable(row),
            breadcrumbs: row.breadcrumbs || [],
            breadcrumbText: row.breadcrumbText || "",
            filterable: !!row.filterable,
            lazy: !!row.lazy,
            alwaysExpanded: row.alwaysExpanded !== false,
            expandable: !!(row.children && row.children.length > 0) || !!row.lazy,
            switchState: row.switchState === undefined ? null : row.switchState,
            control: root.copyJsonValue(row.control),
            presentation: root.copyJsonValue(row.presentation),
            defaultAction: root.copyJsonValue(row.defaultAction),
            enter: root.copyJsonValue(row.enter),
            metadata: root.copyJsonValue(row.metadata),
            semantics: root.copyJsonValue(row.semantics),
            actions: (row.actions || []).map(function(a) {
                return { id: a.id || "", label: a.label || "", icon: a.icon || null, default: !!a.default, payload: root.copyJsonValue(a.payload) };
            }),
            evidence: (row.evidence || []).map(function(e) {
                return {
                    strategy: e.strategy || "",
                    field: e.field || "",
                    fieldText: e.fieldText || "",
                    originNodeId: e.originNodeId || e.nodeId || "",
                    originKind: e.originKind || "self",
                    depth: e.depth === undefined ? 0 : e.depth,
                    tokenIndex: e.tokenIndex === undefined ? null : e.tokenIndex,
                    tokenIndexes: e.tokenIndexes || [],
                    coverageCount: e.coverageCount || 0,
                    exactness: e.exactness || e.strategy || "",
                    actionId: e.actionId || null,
                    actionRole: e.actionRole || null,
                    isExecutable: !!e.isExecutable,
                    score: e.score || 0,
                    weight: e.weight || 0,
                    effective: e.effective || 0,
                    kind: e.kind || "",
                    reason: e.reason || ""
                };
            })
        };
        if (row.children && row.children.length) {
            var maxChildren = options.maxChildren === undefined ? row.children.length : Math.max(0, Number(options.maxChildren));
            var childSource = row.children.slice(0, maxChildren);
            out.children = childSource.map(function(child) { return root.serializeRow(child, depth + 1, options); }).filter(Boolean);
            if (row.children.length > childSource.length) {
                out.childrenTruncated = true;
                out.childCount = row.children.length;
            }
        }
        if (depth > 0) {
            out.evidence = [];
            out.scoreBundle = null;
        }
        if (row.switchActions) {
            out.switchActions = {};
            for (var k in row.switchActions)
                out.switchActions[k] = { id: row.switchActions[k].id, label: row.switchActions[k].label };
        }
        if (depth === 0 && row.recipes) {
            out.recipes = {};
            for (var rk in row.recipes) {
                if (Array.isArray(row.recipes[rk]))
                    out.recipes[rk] = root.copyJsonValue(row.recipes[rk]);
            }
        }
        if (depth === 0 && row.interactions) {
            out.interactions = {};
            for (var ik in row.interactions) {
                var entry = row.interactions[ik];
                if (entry && typeof entry === "object")
                    out.interactions[ik] = { label: entry.label || "", recipe: root.copyJsonValue(entry.recipe || []) };
            }
        }
        return out;
    }

    function serializeRowsForQuery(rows, queryInfo, options) {
        var previousLastQuery = controller.lastQuery;
        controller.lastQuery = queryInfo || null;
        var out = (rows || []).map(function(row) { return root.serializeRow(row, 0, options || {}); }).filter(Boolean);
        controller.lastQuery = previousLastQuery;
        return out;
    }

    function serializeRowOverview(row, index) {
        if (!row) return null;
        var children = row.children || [];
        var actions = row.actions || [];
        return {
            rank: index,
            id: row.id || "",
            nodeId: row.nodeId || "",
            title: row.title || "",
            subtitle: row.subtitle || "",
            source: row.source || row.backendId || "",
            kind: row.kind || "",
            score: row.score || 0,
            ownScore: row.ownScore || 0,
            inheritedScore: row.inheritedScore || 0,
            descendantScore: row.descendantScore || 0,
            ownVisible: !!row.ownVisible,
            placement: row.placement || "",
            executable: !!row.executable,
            filterable: !!row.filterable,
            lazy: !!row.lazy,
            expandable: children.length > 0 || !!row.lazy,
            childCount: children.length,
            childPreview: children.slice(0, 8).map(function(child) { return { title: child.title || "", nodeId: child.nodeId || child.id || "" }; }),
            actionCount: actions.length,
            defaultAction: row.defaultAction ? { id: row.defaultAction.id || "", label: row.defaultAction.label || "" } : null,
            switchState: row.switchState === undefined ? null : row.switchState,
            control: row.control ? { kind: row.control.kind || "", value: row.control.value === undefined ? null : row.control.value } : null,
            breadcrumbs: row.breadcrumbs || [],
            breadcrumbText: row.breadcrumbText || ""
        };
    }

    function serializeRowsOverview(rows) {
        return (rows || []).map(function(row, index) { return root.serializeRowOverview(row, index); }).filter(Boolean);
    }

    function resolveQueryArg(text) {
        if (!text) return text || "";
        var trimmed = text.trim();
        if (trimmed.length > 0 && (trimmed[0] === "{" || trimmed[0] === "[")) {
            try {
                var parsed = JSON.parse(trimmed);
                if (typeof parsed === "object" && parsed.query !== undefined)
                    return String(parsed.query);
            } catch (e) {}
        }
        return text;
    }

    function _debugBenchmark(arg) {
        tracer.info("debugBenchmark", function() { return { argLen: (arg || "").length }; });
        var config = parseBenchmarkConfig(arg);
        var queries = config.queries.slice(0, 32);
        var iterations = Math.max(1, Math.min(config.iterations, 20));
        var warmups = Math.max(0, Math.min(config.warmups, 5));
        var samples = [];
        var totalMs = 0;
        var maxMs = 0;

        for (var wi = 0; wi < warmups; wi += 1) {
            for (var wq = 0; wq < queries.length; wq += 1)
                Engine.search(controller.backends || [], queries[wq], controller.stateForSearch(), Object.assign(controller.searchOptions(), { trace: true }));
        }

        for (var i = 0; i < iterations; i += 1) {
            for (var qi = 0; qi < queries.length; qi += 1) {
                var start = Date.now();
                var output = Engine.search(controller.backends || [], queries[qi], controller.stateForSearch(), Object.assign(controller.searchOptions(), { trace: true }));
                var elapsed = Date.now() - start;
                totalMs += elapsed;
                maxMs = Math.max(maxMs, elapsed);
                samples.push({
                    query: queries[qi],
                    wallMs: elapsed,
                    timings: output.timings || {},
                    rows: output.rows.length,
                    top: output.rows.length > 0 ? output.rows[0].title : ""
                });
            }
        }

        var count = Math.max(1, iterations * queries.length);
        var summary = {
            iterations: iterations,
            warmups: warmups,
            queryCount: queries.length,
            avgMs: totalMs / count,
            maxMs: maxMs,
            samples: samples
        };
        return JSON.stringify(summary, null, 2);
    }

    readonly property var debugBenchmark: prof.fn("debugBenchmark", _debugBenchmark)

    function parseBenchmarkConfig(arg) {
        var defaults = {
            iterations: 3,
            warmups: 1,
            queries: ["z", "ze", "zen", "zen ", "zen priv", "zen win", ":wifi", ":wifi ", ":wifi on", ":wifi off", ":db wifi", ":zen", "@app zen", "wifi", "db wifi"]
        };
        if (!arg)
            return defaults;
        try {
            var parsed = JSON.parse(arg);
            if (Array.isArray(parsed))
                defaults.queries = parsed.map(function(x) { return String(x); });
            else if (parsed && typeof parsed === "object") {
                if (Array.isArray(parsed.queries))
                    defaults.queries = parsed.queries.map(function(x) { return String(x); });
                if (parsed.iterations !== undefined)
                    defaults.iterations = Number(parsed.iterations);
                if (parsed.warmups !== undefined)
                    defaults.warmups = Number(parsed.warmups);
            }
        } catch (error) {
            defaults.queries = [String(arg)];
        }
        return defaults;
    }

    function debugVisualRows(text) {
        text = root.resolveQueryArg(text);
        var output = Engine.search(controller.backends || [], text || "", controller.stateForSearch(), controller.searchOptions());
        return root.debugVisualOutput(text, output);
    }

    function debugApplyQuery(text) {
        text = root.resolveQueryArg(text);
        tracer.info("debugApplyQuery", function() { return { query: text }; });
        controller.query = text || "";
        controller.generation += 1;
        if (!controller.query || controller.query.trim().length === 0) {
            controller.resultsClearRequested();
            return { query: controller.query, rows: [], timings: {} };
        }
        var output = Engine.search(controller.backends || [], controller.query, controller.stateForSearch(), controller.searchOptions());
        controller.lastQuery = output.query;
        controller.lastDirective = output.directive;
        controller.lastEvaluatedRoot = output.evaluatedRoot;
        controller.setResults((output.rows || []).slice(0, controller.maxResults), controller.query);
        return root.debugVisualOutput(controller.query, output);
    }

    function debugVisualOutput(text, output) {
        var rows = output && output.rows ? output.rows.slice(0, controller.maxResults) : [];
        return {
            query: output && output.query ? output.query.raw : text,
            timings: output ? output.timings || {} : {},
            rows: rows.map(function(row, index) {
                return {
                    key: controller.rowKey(row),
                    rank: index,
                    zValue: 10000 - index,
                    title: row ? row.title || "" : "",
                    source: row ? row.source || row.backendId || "" : "",
                    placement: row ? row.placement || "" : "",
                    children: row && row.children ? row.children.length : 0
                };
            })
        };
    }

    function parsePipelineConfig(arg) {
        var config = { query: root.resolveQueryArg(arg), focusNodeId: "", showHidden: controller.showHidden, details: [], overview: true, maxChildren: 32 };
        if (!arg)
            return config;
        var trimmed = String(arg).trim();
        if (trimmed.length === 0 || (trimmed[0] !== "{" && trimmed[0] !== "["))
            return config;
        try {
            var parsed = JSON.parse(trimmed);
            if (!parsed || typeof parsed !== "object" || Array.isArray(parsed))
                return config;
            if (parsed.query !== undefined)
                config.query = String(parsed.query);
            config.focusNodeId = String(parsed.focusNodeId || parsed.nodeId || parsed.id || "");
            config.details = root.normalizePipelineDetails(parsed.details !== undefined ? parsed.details : (parsed.detail !== undefined ? parsed.detail : (parsed.sections !== undefined ? parsed.sections : parsed.include)));
            var mode = String(parsed.mode || parsed.view || "").toLowerCase();
            if (mode === "full" || mode === "debug")
                config.details = ["rows", "phases", "backends", "diagnostics"];
            else if (mode === "overview" || mode === "compact")
                config.details = [];
            config.overview = config.details.length === 0;
            if (parsed.showHidden !== undefined)
                config.showHidden = !!parsed.showHidden;
            else if (config.focusNodeId)
                config.showHidden = true;
            if (parsed.maxChildren !== undefined)
                config.maxChildren = Math.max(0, Math.min(256, Number(parsed.maxChildren)));
            else if (config.focusNodeId && root.pipelineWants(config, "rows"))
                config.maxChildren = 96;
        } catch (error) {}
        return config;
    }

    function normalizePipelineDetails(value) {
        if (value === undefined || value === null || value === false)
            return [];
        if (value === true || String(value).toLowerCase() === "all" || String(value).toLowerCase() === "full")
            return ["rows", "phases", "backends", "diagnostics"];
        var items = Array.isArray(value) ? value : String(value).split(/[,\s]+/);
        var out = [];
        for (var i = 0; i < items.length; i += 1) {
            var item = String(items[i] || "").toLowerCase().trim();
            if (!item) continue;
            if (item === "row") item = "rows";
            if (item === "phase") item = "phases";
            if (item === "backend") item = "backends";
            if (item === "diagnostic") item = "diagnostics";
            if (["rows", "phases", "backends", "diagnostics"].indexOf(item) >= 0 && out.indexOf(item) < 0)
                out.push(item);
        }
        return out;
    }

    function pipelineWants(config, detail) {
        return (config.details || []).indexOf(detail) >= 0;
    }

    function nodeIdMatchesFocus(nodeId, focusNodeId) {
        if (!focusNodeId)
            return true;
        nodeId = nodeId || "";
        return nodeId === focusNodeId || nodeId.indexOf(focusNodeId + ":") === 0;
    }

    function filterRowForFocus(row, focusNodeId) {
        if (!row)
            return null;
        if (root.nodeIdMatchesFocus(row.nodeId || row.id || "", focusNodeId))
            return row;
        var children = (row.children || []).map(function(child) { return root.filterRowForFocus(child, focusNodeId); }).filter(Boolean);
        if (children.length === 0)
            return null;
        return Object.assign({}, row, { children: children });
    }

    function filterRowsForFocus(rows, focusNodeId) {
        if (!focusNodeId)
            return rows || [];
        return (rows || []).map(function(row) { return root.filterRowForFocus(row, focusNodeId); }).filter(Boolean);
    }

    function filterPhasesForFocus(phases, focusNodeId) {
        if (!focusNodeId)
            return phases || [];
        var focusBackend = focusNodeId.split(":")[0] || "";
        return (phases || []).map(function(phase) {
            var out = Object.assign({}, phase);
            if (Array.isArray(out.roots) && focusBackend)
                out.roots = out.roots.filter(function(item) { return item.backendId === focusBackend; });
            if (Array.isArray(out.childScoreBundles) && focusBackend)
                out.childScoreBundles = out.childScoreBundles.filter(function(item) { return item.backendId === focusBackend; });
            if (Array.isArray(out.shaped))
                out.shaped = out.shaped.filter(function(item) { return root.nodeIdMatchesFocus(item.nodeId || "", focusNodeId); });
            return out;
        });
    }

    function summarizePhase(phase) {
        if (!phase) return null;
        var out = { phase: phase.phase, name: phase.name || "" };
        if (phase.searchRaw !== undefined) out.searchRaw = phase.searchRaw;
        if (phase.directive) out.directive = phase.directive;
        if (phase.tokens) out.tokens = phase.tokens;
        if (phase.activeBackendIds) out.activeBackendIds = phase.activeBackendIds;
        if (phase.rootNodeMs !== undefined) out.rootNodeMs = phase.rootNodeMs;
        if (phase.perBackendMs) out.perBackendMs = phase.perBackendMs;
        if (phase.roots) out.rootCount = phase.roots.length;
        if (phase.candidateMs !== undefined) out.candidateMs = phase.candidateMs;
        if (phase.candidateCount !== undefined) out.candidateCount = phase.candidateCount;
        if (phase.evaluateMs !== undefined) out.evaluateMs = phase.evaluateMs;
        if (phase.totalNodes !== undefined) out.totalNodes = phase.totalNodes;
        if (phase.visibleNodes !== undefined) out.visibleNodes = phase.visibleNodes;
        if (phase.childScoreBundles) out.childScoreBundleCount = phase.childScoreBundles.length;
        if (phase.pathMs !== undefined) out.pathMs = phase.pathMs;
        if (phase.shapeMs !== undefined) out.shapeMs = phase.shapeMs;
        if (phase.shapedCount !== undefined) out.shapedCount = phase.shapedCount;
        if (phase.placements) out.placements = phase.placements;
        if (phase.rows !== undefined) out.rows = phase.rows;
        if (phase.totalMs !== undefined) out.totalMs = phase.totalMs;
        return out;
    }

    function summarizePhases(phases) {
        return (phases || []).map(function(phase) { return root.summarizePhase(phase); }).filter(Boolean);
    }

    function _queryPipeline(text) {
        var stage = "resolve";
        try {
            var pipelineConfig = root.parsePipelineConfig(text);
            text = pipelineConfig.query;
            stage = "search";
            tracer.info("queryPipeline", function() { return { query: text, showHidden: pipelineConfig.showHidden, details: pipelineConfig.details }; });
            var output = Engine.search(controller.backends || [], text || "", controller.stateForSearch(),
                Object.assign(controller.searchOptions(), { showHidden: pipelineConfig.showHidden, trace: true }));
            var diag = PolicyDiagnostics.empty();
            var allRows = output.rows || [];
            var rows = pipelineConfig.focusNodeId
                ? root.filterRowsForFocus(allRows, pipelineConfig.focusNodeId).slice(0, controller.maxResults)
                : allRows.slice(0, controller.maxResults);
            var detailedRows = root.pipelineWants(pipelineConfig, "rows");
            stage = detailedRows ? "serialize-rows" : "serialize-row-overview";
            var serializedRows = detailedRows
                ? root.serializeRowsForQuery(rows, output.query, { maxChildren: pipelineConfig.maxChildren })
                : root.serializeRowsOverview(rows);

            stage = "serialize-backends";
            var backendEntries = (controller.backends || []).filter(function(b) { return !!b; }).map(function(b) {
                var routes = [];
                if (typeof b.routes !== "undefined")
                    routes = b.routes || [];
                var helpPrefixes = [];
                if (typeof b.helpPrefixes !== "undefined")
                    helpPrefixes = b.helpPrefixes || [];
                return {
                    id: b.backendId || "",
                    name: b.name || "",
                    description: b.helpDescription || "",
                    enabled: !!b.enabled,
                    priority: b.priority || 0,
                    routes: routes,
                    helpPrefixes: helpPrefixes,
                    hasAsyncResults: typeof b.resultsAsync === "function",
                    hasRootNode: typeof b.rootNode === "function",
                    hasStreamUpdates: typeof b.applyStreamUpdate === "function"
                };
            });

            var detailedPhases = root.pipelineWants(pipelineConfig, "phases");
            var detailedBackends = root.pipelineWants(pipelineConfig, "backends");
            var detailedDiagnostics = root.pipelineWants(pipelineConfig, "diagnostics");
            var payload = {
                version: 3, type: "pipeline",
                query: output.query ? output.query.raw : text,
                directive: output.directive ? { active: output.directive.active, prefix: output.directive.prefix || "", label: output.directive.label || "", backendIds: output.directive.backendIds || [] } : { active: false },
                timings: output.timings || {},
                phases: detailedPhases
                    ? root.filterPhasesForFocus(output.phases || [], pipelineConfig.focusNodeId)
                    : root.summarizePhases(root.filterPhasesForFocus(output.phases || [], pipelineConfig.focusNodeId)),
                rows: serializedRows,
                totalResults: rows.length,
                debug: {
                    focusNodeId: pipelineConfig.focusNodeId || null,
                    showHidden: !!pipelineConfig.showHidden,
                    unfilteredResults: allRows.length,
                    detailMode: pipelineConfig.overview ? "overview" : "custom",
                    details: pipelineConfig.details,
                    maxChildren: pipelineConfig.maxChildren,
                    availableDetails: ["rows", "phases", "backends", "diagnostics"]
                },
                backends: {
                    total: backendEntries.length,
                    entries: detailedBackends ? backendEntries : [],
                    enabledIds: backendEntries.filter(function(entry) { return entry.enabled; }).map(function(entry) { return entry.id; }),
                    routingTree: { endpointCount: (controller.routingTree || {}).endpoints ? controller.routingTree.endpoints.length : 0 }
                },
                state: {
                    selectedIndex: controller.selectedIndex,
                    resultCount: controller.results.length,
                    loading: controller.loading
                },
                diagnostics: detailedDiagnostics ? PolicyDiagnostics.toDebug(diag) : { omitted: true }
            };
            root.logJsonValidation("query=" + (text || "") + " rows=" + serializedRows.length, payload);
            stage = "stringify";
            var encoded = JSON.stringify(payload);
            if (encoded.length > 100000)
                tracer.warn("pipelineOversize", function() { return { query: text, bytes: encoded.length, focus: pipelineConfig.focusNodeId || "" }; });
            return encoded;
        } catch (error) {
            tracer.error("queryPipeline", function() { return { stage: stage, query: text, error: String(error) }; });
            return JSON.stringify({ version: 3, type: "pipeline", query: text || "", error: String(error), stage: stage });
        }
    }

    readonly property var queryPipeline: prof.fn("queryPipeline", _queryPipeline)

    function queryPolicies(text) {
        text = root.resolveQueryArg(text);
        var output = Engine.search(controller.backends || [], text || "", controller.stateForSearch(),
            Object.assign(controller.searchOptions(), { showHidden: true }));
        var activeBackendIds = (controller.backends || []).filter(function(b) { return b && b.enabled; }).map(function(b) { return b.backendId || ""; });
        var policyInfo = root.collectActivePolicies(output.evaluatedRoot);
        return JSON.stringify({
            version: 2, type: "policies",
            query: text || "",
            activeBackends: activeBackendIds,
            policiesByKind: policyInfo.policiesByKind,
            diagnostics: policyInfo.diagnostics
        });
    }

    function collectActivePolicies(ev) {
        if (!ev) return { policiesByKind: {}, diagnostics: { warnings: [], errors: [], unresolved: [], legacyCount: 0, tupleCount: 0, objectCount: 0 } };
        var kinds = {};
        var legacyCount = 0, tupleCount = 0, objectCount = 0;
        function visit(evaluated) {
            var rawNode = evaluated.node || evaluated;
            var profile = (rawNode.evaluationProfile || {}).profile || {};
            for (var key in profile) {
                if (!kinds[key]) kinds[key] = {};
                var specs = profile[key];
                if (Array.isArray(specs)) {
                    for (var si = 0; si < specs.length; si += 1) {
                        var spec = PolicySpec.normalize(specs[si]);
                        var specKey = spec.name;
                        if (!kinds[key][specKey]) {
                            kinds[key][specKey] = { name: spec.name, kind: spec.kind, args: spec.args, priority: spec.priority, count: 0 };
                        }
                        kinds[key][specKey].count += 1;
                        var rawSpec = specs[si];
                        if (typeof rawSpec === "string") legacyCount += 1;
                        else if (Array.isArray(rawSpec)) tupleCount += 1;
                        else objectCount += 1;
                    }
                }
            }
            var children = evaluated.children || rawNode.children || [];
            for (var i = 0; i < children.length; i += 1)
                visit(children[i]);
        }
        visit(ev);
        var out = {};
        for (var kind in kinds) {
            out[kind] = [];
            for (var specKey in kinds[kind])
                out[kind].push(kinds[kind][specKey]);
        }
        return {
            policiesByKind: out,
            diagnostics: {
                warnings: [], errors: [], unresolved: [],
                legacyCount: legacyCount, tupleCount: tupleCount, objectCount: objectCount
            }
        };
    }

    function queryCases() {
        return JSON.stringify({
            version: 1, type: "cases",
            cases: root.regressionCaseQueries()
        });
    }

    function queryRunCases() {
        var cases = root.regressionCaseQueries();
        var results = [];
        for (var i = 0; i < cases.length; i += 1) {
            var q = cases[i];
            var output = Engine.search(controller.backends || [], q, controller.stateForSearch(),
                Object.assign(controller.searchOptions(), { trace: true }));
            var rows = output.rows || [];
            var visibleRows = rows.filter(function(r) { return r.ownVisible; });
            var top = visibleRows.length > 0 ? visibleRows[0] : null;
            var topBreadcrumb = "";
            if (top && top.breadcrumbs) {
                if (Array.isArray(top.breadcrumbs))
                    topBreadcrumb = top.breadcrumbs.join(" > ");
                else if (top.breadcrumbText)
                    topBreadcrumb = top.breadcrumbText;
            }
            results.push({
                query: q,
                totalRows: rows.length,
                visibleRows: visibleRows.length,
                topTitle: top ? top.title : null,
                topScore: top ? top.score : 0,
                topOwnScore: top ? top.ownScore : 0,
                topPlacement: top ? top.placement : null,
                topSource: top ? (top.source || top.backendId || "") : null,
                topExecutable: top ? !!top.executable : false,
                topBreadcrumbText: topBreadcrumb,
                timings: output.timings || {}
            });
        }
        return JSON.stringify({
            version: 1, type: "runCases",
            total: cases.length,
            results: results,
            summary: root.summarizeCaseResults(results)
        });
    }

    function regressionCaseQueries() {
        return [
            "?", "? ", "?au",
            "v", "new", "zen", "zen ", "zen priv", "zen win", "zen browser", "zen new",
            "wifi", "wifi ", "wifi on", "wifi off", "wifi toggle", "toggle wifi",
            "wo", "wt",
            ":", ":wifi", ":wifi ", ":wifi on", ":db wifi",
            "@apps", "@apps zen", "@web nix",
            "web nix", "web !gh nix",
            "db wifi", "dashboard wifi",
            "au", "aud", "audi", "audio",
            "en", "screen", "session",
            "phenix", "ai", "vpn", "vpn ", "vpn ger", "vpn germany", "vpn of", "vpn no", "vpn nor", "vpn norway",
            "ger", "alg", "bel", "swe", "germany", "algeria", "belgium", "sweden",
            "net", "network", "networking", "bluetooth",
            "notes", "/tmp"
        ];
    }

    function summarizeCaseResults(results) {
        var totalMs = 0;
        var count = Math.max(1, results.length);
        for (var i = 0; i < results.length; i += 1)
            totalMs += results[i].timings.totalMs || 0;
        return {
            avgMs: totalMs / count,
            totalCases: results.length,
            maxRows: results.reduce(function(m, r) { return Math.max(m, r.totalRows); }, 0)
        };
    }

    // --- Debug V2 IPC methods (canonical Evaluation-based) ---

    function parseDebugArgs(argsJson) {
        var args = {};
        if (argsJson) {
            var trimmed = String(argsJson).trim();
            if (trimmed.length > 0 && (trimmed[0] === "{" || trimmed[0] === "[")) {
                try {
                    args = JSON.parse(trimmed);
                } catch (e) {}
            } else {
                args.query = trimmed;
            }
        }
        return args;
    }

    // ── Shared JSON-safe IPC return boundary ────────────────────────
    // Every debug endpoint MUST use this helper — never raw JSON.stringify(envelope).

    function returnDebugEnvelope(mode, evaluation, result, source) {
        var queryInfo = evaluation ? evaluation.query : null
        var envelope = FormatUtils.make(mode, queryInfo, result, source || "query")
        var safe = FormatUtils.toJsonSafe(envelope)

        if (!FormatUtils.validateJsonSafe("debug." + mode, safe)) {
            var err = FormatUtils.make(
                mode,
                queryInfo,
                FormatUtils.errorResult(
                    "json_unsafe",
                    "Debug response contained non-JSON-safe data after normalization."
                ),
                source || "query"
            )
            return JSON.stringify(FormatUtils.toJsonSafe(err))
        }

        return JSON.stringify(safe)
    }

    function _resolveEvaluation(argsJson) {
        tracer.trace("resolveEvaluation", function() { return { argsLen: (argsJson || "").length }; });
        var args = root.parseDebugArgs(argsJson);

        // IPC boundary hardening: validate input before touching pipeline
        var query = String(args.query || "");
        if (query.length > 200) {
            return { args: args, error: { code: "query_too_long", message: "Query exceeds 200 character limit" } };
        }
        var source = String(args.source || "query");
        if (["query", "current"].indexOf(source) < 0) {
            return { args: args, error: { code: "unknown_source", message: "Unknown source '" + source + "'. Supported: query, current" } };
        }
        var nodeId = args.nodeId ? String(args.nodeId) : "";
        if (nodeId && nodeId.length > 200) {
            return { args: args, error: { code: "node_id_too_long", message: "nodeId exceeds 200 character limit" } };
        }
        if (nodeId && !/^[a-zA-Z0-9:_-]+$/.test(nodeId)) {
            return { args: args, error: { code: "invalid_node_id", message: "nodeId contains invalid characters" } };
        }

        // Run query through normal pipeline — with the SAME searchOptions as the UI (no showHidden)
        if (source === "query" && query) {
            var opts = Object.assign({}, controller.searchOptions(), { trace: false });
            var output = Engine.search(controller.backends || [], query, controller.stateForSearch(), opts);
            if (!output || !output.evaluation) {
                return { args: args, error: { code: "no_evaluation", message: "Pipeline did not produce evaluation" } };
            }
            return { args: args, evaluation: output.evaluation, queryInfo: output.query || null, source: "query" };
        }

        // Use current launcher state
        if (source === "current" || (!source && query === "")) {
            var currentQuery = controller.lastQuery;
            var currentEval = controller.lastEvaluation;
            if (currentEval) {
                return { args: args, evaluation: currentEval, queryInfo: currentQuery || null, source: "current" };
            }
            // Fall back: run evaluation for current query
            var currentText = String(controller.query || "");
            if (currentText) {
                var curOpts = Object.assign({}, controller.searchOptions(), { trace: false });
                var curOutput = Engine.search(controller.backends || [], currentText, controller.stateForSearch(), curOpts);
                if (curOutput && curOutput.evaluation) {
                    controller.lastEvaluation = curOutput.evaluation;
                    return { args: args, evaluation: curOutput.evaluation, queryInfo: curOutput.query || null, source: "query" };
                }
            }
            return { args: args, error: { code: "no_current", message: "No current evaluation available and no query provided" } };
        }

        // Fallback safety (should not reach here due to validation above)
        return { args: args, error: { code: "unknown_source", message: "Unknown source '" + source + "'. Supported: query, current" } };
    }

    readonly property var resolveEvaluation: prof.fn("resolveEvaluation", _resolveEvaluation)

    function debugOverview(argsJson) {
        tracer.trace("debugOverview", function() { return {}; });
        var resolved = root.resolveEvaluation(argsJson);
        if (resolved.error) return root.returnDebugEnvelope("overview", null, resolved.error, "error");
        var args = resolved.args || {};
        var result = _overviewFmt.serialize(resolved.evaluation, { maxDepth: args.maxDepth, maxChildren: args.maxChildren });
        return root.returnDebugEnvelope("overview", resolved.evaluation, result, resolved.source);
    }

    function debugInspect(argsJson) {
        tracer.trace("debugInspect", function() { return { argsLen: (argsJson || "").length }; });
        var resolved = root.resolveEvaluation(argsJson);
        if (resolved.error) return root.returnDebugEnvelope("inspect", null, resolved.error, "error");
        var args = resolved.args || {};
        if (!args.nodeId) return root.returnDebugEnvelope("inspect", null, FormatUtils.errorResult("no_node_id", "nodeId is required"), "error");
        var result = _inspectFmt.serialize(resolved.evaluation, {
            nodeId: args.nodeId,
            include: args.include || { fields: true, matching: true, scoring: true, decisions: true, childrenSummary: true }
        });
        return root.returnDebugEnvelope("inspect", resolved.evaluation, result, resolved.source);
    }

    function debugPolicies(argsJson) {
        tracer.trace("debugPolicies", function() { return {}; });
        var resolved = root.resolveEvaluation(argsJson);
        if (resolved.error) return root.returnDebugEnvelope("policies", null, resolved.error, "error");
        var args = resolved.args || {};

        // policy-chain-invariants check
        if (args.check === "policy-chain-invariants") {
            var comp = Qt.createComponent("../tests/TestPolicyChain.qml");
            if (comp.status === Component.Error) {
                return root.returnDebugEnvelope("policies", null, { name: "PolicyChain", error: comp.errorString() }, "test-error");
            }
            var testObj = comp.createObject(root);
            var testResult = testObj.runAll();
            testObj.destroy();
            comp.destroy();
            // Compute pass/fail summary
            var failures = testResult.results.filter(function(r) { return !r.ok; });
            testResult.passed = failures.length === 0;
            testResult.failCount = failures.length;
            testResult.totalCount = testResult.results.length;
            return root.returnDebugEnvelope("policies", null, testResult, "test");
        }

        var result = _policiesFmt.serialize(resolved.evaluation, {
            nodeId: args.nodeId || "",
            kind: args.kind || "",
            maxNodes: args.maxNodes
        });
        return root.returnDebugEnvelope("policies", resolved.evaluation, result, resolved.source);
    }

    function debugFind(argsJson) {
        tracer.trace("debugFind", function() { return {}; });
        var resolved = root.resolveEvaluation(argsJson);
        if (resolved.error) return root.returnDebugEnvelope("find", null, resolved.error, "error");
        var args = resolved.args || {};
        if (!args.search) return root.returnDebugEnvelope("find", null, FormatUtils.errorResult("no_search", "search string is required"), "error");
        var result = _findFmt.serialize(resolved.evaluation, {
            search: args.search,
            backend: args.backend || "",
            includeHidden: args.includeHidden !== false,
            maxResults: args.maxResults
        });
        return root.returnDebugEnvelope("find", resolved.evaluation, result, resolved.source);
    }

    function debugAction(argsJson) {
        tracer.trace("debugAction", function() { return {}; });
        var resolved = root.resolveEvaluation(argsJson);
        if (resolved.error) return root.returnDebugEnvelope("action", null, resolved.error, "error");
        var args = resolved.args || {};
        if (!args.nodeId) return root.returnDebugEnvelope("action", null, FormatUtils.errorResult("no_node_id", "nodeId is required"), "error");
        var result = _actionFmt.serialize(resolved.evaluation, {
            nodeId: args.nodeId,
            input: args.input || "enter"
        });
        return root.returnDebugEnvelope("action", resolved.evaluation, result, resolved.source);
    }

    function debugStats(argsJson) {
        tracer.trace("debugStats", function() { return {}; });
        var resolved = root.resolveEvaluation(argsJson);
        if (resolved.error) return root.returnDebugEnvelope("stats", null, resolved.error, "error");
        var args = resolved.args || {};
        var result = _statsFmt.serialize(resolved.evaluation, {
            includeStages: args.includeStages !== false,
            includeBackends: args.includeBackends !== false,
            includeValidation: args.includeValidation !== false
        });
        return root.returnDebugEnvelope("stats", resolved.evaluation, result, resolved.source);
    }

    function debugRaw(argsJson) {
        tracer.trace("debugRaw", function() { return {}; });
        var resolved = root.resolveEvaluation(argsJson);
        if (resolved.error) return root.returnDebugEnvelope("raw", null, resolved.error, "error");
        var args = resolved.args || {};
        var result = _rawFmt.serialize(resolved.evaluation, {
            maxNodes: args.maxNodes || 50,
            maxDepth: args.maxDepth || 5,
            includeHidden: args.includeHidden !== false,
            includeRawNodes: args.includeRawNodes,
            includePipelineStages: args.includePipelineStages,
            backend: args.backend
        });
        return root.returnDebugEnvelope("raw", resolved.evaluation, result, resolved.source);
    }

    // ── Benchmark V2: per-phase, per-policy, per-query statistical benchmark ──

    function parseBenchmarkV2Config(arg) {
        var defaults = {
            count: 5,
            warmups: 1,
            queries: [
                "?", "= 1+2",
                ":wifi", ":wifi on", ":audio", ":shutdown", "@app", "@apps", "@apps zen",
                "/tmp",
                "a", "n", "w", "z",
                "ai", "audio", "bluetooth", "documents", "downloads",
                "files", "net", "network", "networking", "new window", "phenix", "phenix ai",
                "pictures", "private", "rebuild", "session", "shutdown", "switch",
                "vpn", "vpn ", "vpn g", "vpn ger", "vpn germany", "vpn algeria", "vpn fastest",
                "wifi", "wifi ", "wifi on",
                "zen", "zen ", "zen browser", "zen priv", "zen window"
            ]
        };
        if (!arg) return defaults;
        try {
            var parsed = JSON.parse(arg);
            if (Array.isArray(parsed))
                defaults.queries = parsed.map(function(x) { return String(x); });
            else if (parsed && typeof parsed === "object") {
                if (Array.isArray(parsed.queries))
                    defaults.queries = parsed.queries.map(function(x) { return String(x); });
                if (parsed.count !== undefined) defaults.count = Math.max(1, Math.min(Number(parsed.count), 50));
                if (parsed.warmups !== undefined) defaults.warmups = Math.max(0, Math.min(Number(parsed.warmups), 10));
            }
        } catch (error) {
            defaults.queries = [String(arg)];
        }
        return defaults;
    }

    function benchmarkStats(values) {
        if (!values || values.length === 0) return null;
        var n = values.length;
        var sorted = values.slice().sort(function(a, b) { return a - b; });
        var sum = 0;
        for (var i = 0; i < n; i += 1) sum += sorted[i];
        var mean = sum / n;
        var variance = 0;
        for (var j = 0; j < n; j += 1) variance += (sorted[j] - mean) * (sorted[j] - mean);
        variance /= n;
        function pct(p) {
            var idx = Math.floor(p * (n - 1));
            return sorted[idx];
        }
        return {
            min: sorted[0],
            max: sorted[n - 1],
            mean: mean,
            sigma: Math.sqrt(variance),
            p50: pct(0.50),
            p95: pct(0.95),
            p99: pct(0.99),
            samples: n
        };
    }

    function computeQueryStats(samples) {
        var wallVals = [];
        var phaseBuckets = {};
        var policyBuckets = {};
        for (var si = 0; si < samples.length; si += 1) {
            var s = samples[si];
            wallVals.push(s.wallMs);
            if (s.phases) {
                for (var pk in s.phases) {
                    if (!s.phases.hasOwnProperty(pk)) continue;
                    if (!phaseBuckets[pk]) phaseBuckets[pk] = [];
                    phaseBuckets[pk].push(s.phases[pk]);
                }
            }
            if (s.policies) {
                for (var cat in s.policies) {
                    if (!s.policies.hasOwnProperty(cat)) continue;
                    if (!policyBuckets[cat]) policyBuckets[cat] = {};
                    for (var pn in s.policies[cat]) {
                        if (!s.policies[cat].hasOwnProperty(pn)) continue;
                        if (!policyBuckets[cat][pn]) policyBuckets[cat][pn] = [];
                        policyBuckets[cat][pn].push(s.policies[cat][pn]);
                    }
                }
            }
        }
        var result = {
            totalWallMs: root.benchmarkStats(wallVals),
            phases: {},
            policies: {}
        };
        for (var pk2 in phaseBuckets) {
            if (phaseBuckets.hasOwnProperty(pk2))
                result.phases[pk2] = root.benchmarkStats(phaseBuckets[pk2]);
        }
        for (var cat2 in policyBuckets) {
            if (policyBuckets.hasOwnProperty(cat2)) {
                result.policies[cat2] = {};
                for (var pn2 in policyBuckets[cat2]) {
                    if (policyBuckets[cat2].hasOwnProperty(pn2))
                        result.policies[cat2][pn2] = root.benchmarkStats(policyBuckets[cat2][pn2]);
                }
            }
        }
        return result;
    }

    function debugBenchmarkV2(arg) {
        var config = root.parseBenchmarkV2Config(arg);
        var queries = config.queries.slice(0, 32);
        var count = config.count;
        var warmups = config.warmups;
        var allSamples = {};

        function benchSearch(queryText) {
            return Engine.search(controller.backends || [], queryText, controller.stateForSearch(),
                Object.assign({}, controller.searchOptions(), { trace: true, _policyTimings: { evidence: {}, boost: {} } }));
        }

        // Warmup
        for (var wi = 0; wi < warmups; wi += 1) {
            for (var wq = 0; wq < queries.length; wq += 1)
                benchSearch(queries[wq]);
        }

        // Timed runs
        for (var qi = 0; qi < queries.length; qi += 1) {
            var q = queries[qi];
            var samples = [];
            for (var ci = 0; ci < count; ci += 1) {
                var start = Date.now();
                var output = benchSearch(q);
                var wallMs = Date.now() - start;
                var timings = output.timings || {};

                var totalMs = timings.totalMs || 0;
                var phaseSum = (timings.rootNodeMs || 0) + (timings.candidateMs || 0) + (timings.evaluateMs || 0) + (timings.shapeMs || 0);
                var phases = {
                    "directive-tokenize": Math.max(0, totalMs - phaseSum),
                    "root-nodes": timings.rootNodeMs || 0,
                    "candidates": timings.candidateMs || 0,
                    "evaluation": timings.evaluateMs || 0,
                    "shaping": timings.shapeMs || 0
                };

                var policies = {};
                var pt = timings.policyTimings;
                if (pt) {
                    if (pt.evidence) {
                        policies.evidence = {};
                        for (var ek in pt.evidence)
                            if (pt.evidence.hasOwnProperty(ek))
                                policies.evidence[ek] = pt.evidence[ek];
                    }
                    if (pt.boost) {
                        policies.boost = {};
                        for (var bk in pt.boost)
                            if (pt.boost.hasOwnProperty(bk))
                                policies.boost[bk] = pt.boost[bk];
                    }
                }

                samples.push({
                    wallMs: wallMs,
                    totalMs: totalMs,
                    phases: phases,
                    policies: policies,
                    rows: output.rows ? output.rows.length : 0
                });
            }
            allSamples[q] = samples;
        }

        var byQuery = {};
        for (var qi2 = 0; qi2 < queries.length; qi2 += 1) {
            var q2 = queries[qi2];
            var samps = allSamples[q2] || [];
            if (samps.length === 0) continue;
            byQuery[q2] = {
                samples: samps,
                stats: root.computeQueryStats(samps)
            };
        }

        var allSamplesFlat = [];
        for (var qk in allSamples) {
            if (allSamples.hasOwnProperty(qk))
                allSamplesFlat = allSamplesFlat.concat(allSamples[qk]);
        }
        var overall = root.computeQueryStats(allSamplesFlat);

        var result = {
            version: 2,
            type: "benchmarkV2",
            config: { count: count, warmups: warmups, queryCount: queries.length, queries: queries },
            overall: overall,
            byQuery: byQuery
        };

        return JSON.stringify(result, null, 2);
    }
}
