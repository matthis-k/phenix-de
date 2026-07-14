import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.animations as Animations
import qs.services
import "backends" as Backends
import "delegates" as Delegates
import "visual" as Visual
import "logic/DebugLogger.js" as DebugLogger
import "logic/KeybindPresets.js" as KeybindPresets

PanelWindow {
    id: root

    readonly property var tracer: Logger.scope("launcher", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher", { category: "launcher" })

    property alias query: controller.query
    property var shellScreenState: null
    property string backendSet: "all"
    property var backendSets: ({
        "all": [backendsBackend, desktopActionsBackend, calculatorBackend, desktopBackend, filesBackend, webBackend, workerTestBackend],
        "desktop": [desktopBackend],
        "dmenu": [desktopBackend, calculatorBackend, filesBackend]
    })
    readonly property var allBackends: [backendsBackend, desktopActionsBackend, calculatorBackend, desktopBackend, filesBackend, webBackend, workerTestBackend]
    property var backends: root.backendSets[root.backendSet] || root.backendSets.all
    property Component resultDelegate: defaultResultDelegate
    property bool showSubtitles: true
    property bool showActionHint: true
    property bool showEvidence: false
    property int maxResultsPerBackend: 5
    property int visibleResultRows: 12
    property int rowHeight: 56
    property int iconSize: 32
    property bool launcherRevealed: false
    property bool closing: false
    property var lastExecutedAction: null

    function open(arg) {
        tracer.info("open", function() { return { arg: arg, wasVisible: root.visible }; });
        if (arg === undefined) {
            root.backends = root.backendSets[root.backendSet] || root.backendSets.all;
        } else if (typeof arg === "string") {
            root.backends = root.backendSets[arg] || root.backendSets.all;
        } else if (Array.isArray(arg)) {
            var first = arg[0];
            if (typeof first === "string")
                root.backends = root.allBackends.filter(function(backend) { return backend && arg.indexOf(backend.backendId) >= 0; });
            else
                root.backends = arg;
        }
        closeTimer.stop();
        closing = false;
        launcherRevealed = false;
        coordinatorAdapter.resetTransientState();
        visible = true;
        if (Config.behaviour.animation.enabled)
            Qt.callLater(function() {
                if (root.visible && !root.closing)
                    root.launcherRevealed = true;
            });
        else
            launcherRevealed = true;
        focusGrab.active = true;
        input.forceActiveFocus();
    }

    function close() {
        tracer.info("close", function() { return { visible: root.visible, closing: root.closing }; });
        if (!root.visible && !closing)
            return;
        if (closing)
            return;

        closing = true;
        focusGrab.active = false;
        launcherRevealed = false;
        if (Config.behaviour.animation.enabled)
            closeTimer.restart();
        else
            finishClose();
    }

    function finishClose() {
        tracer.info("finishClose", function() { return {}; });
        closeTimer.stop();
        visible = false;
        closing = false;
        controller.reset();
        input.text = "";
    }

    function queryPipeline(text) {
        return controller.queryPipeline(text || "");
    }

    function queryPolicies(text) {
        return controller.queryPolicies(text || "");
    }

    function debugBenchmark(arg) {
        return controller.debugBenchmark(arg || "");
    }

    function debugBenchmarkV2(arg) {
        return controller.debugBenchmarkV2(arg || "");
    }

    function queryCases() {
        return controller.queryCases();
    }

    function queryRunCases() {
        return controller.queryRunCases();
    }

    function queryVisual(text) {
        return JSON.stringify({
            version: 1,
            type: "visual",
            preview: controller.debugVisualRows(text || ""),
            current: coordinatorAdapter.debugState(root.visualMetrics())
        });
    }

    function debugOverview(args) {
        return controller.debugOverview(args || "");
    }
    function debugInspect(args) {
        return controller.debugInspect(args || "");
    }
    function debugPolicies(args) {
        return controller.debugPolicies(args || "");
    }
    function debugFind(args) {
        return controller.debugFind(args || "");
    }
    function debugAction(args) {
        return controller.debugAction(args || "");
    }
    function debugStats(args) {
        return controller.debugStats(args || "");
    }
    function debugRaw(args) {
        return controller.debugRaw(args || "");
    }

    function queryVisualState() {
        return JSON.stringify({
            version: 1,
            type: "visualState",
            current: coordinatorAdapter.debugState(root.visualMetrics())
        });
    }

    function queryVisualApply(text) {
        const preview = controller.debugApplyQuery(text || "");
        return JSON.stringify({
            version: 1,
            type: "visualApply",
            preview: preview,
            current: coordinatorAdapter.debugState(root.visualMetrics())
        });
    }

    // ── helpers ──────────────────────────────────────────

    function interactionEnvelope(action, ok, before, result, error, includeVisual) {
        return JSON.stringify({
            version: 1,
            type: "launcherInteraction",
            ok: !!ok,
            action: action || "",
            before: before || null,
            after: root.interactionState(!!includeVisual),
            result: result === undefined ? null : result,
            error: error || null
        });
    }

    function interactionError(action, before, code, message, includeVisual) {
        return root.interactionEnvelope(action, false, before, null, { code: code, message: message }, includeVisual);
    }

    function parseInteractionArg(arg) {
        if (arg === undefined || arg === null || arg === "")
            return {};
        if (typeof arg === "object")
            return arg;
        const text = String(arg).trim();
        if (text.length === 0)
            return {};
        try {
            return JSON.parse(text);
        } catch (e) {
            return { _parseError: String(e), raw: String(arg) };
        }
    }

    // ── query/input helpers ─────────────────────────────

    function setLauncherQuery(text) {
        tracer.debug("setLauncherQuery", function() { return { textLen: String(text || "").length }; });
        const next = String(text || "");
        input.text = next;
        if (next.trim().length === 0)
            controller.reset();
        else
            controller.updateQuery(next);
        if (root.visible) {
            input.forceActiveFocus();
            input.cursorPosition = input.text.length;
        }
        return {
            query: controller.query || "",
            inputText: input.text || "",
            queryRevision: controller.queryRevision,
            generation: controller.generation
        };
    }

    function appendLauncherText(text) {
        return root.setLauncherQuery((input.text || "") + String(text || ""));
    }

    function backspaceLauncherText(count) {
        const n = Math.max(1, Number(count || 1));
        const current = input.text || "";
        return root.setLauncherQuery(current.slice(0, Math.max(0, current.length - n)));
    }

    function clearLauncherQuery() {
        input.text = "";
        controller.reset();
        if (root.visible)
            input.forceActiveFocus();
        return { query: controller.query || "", inputText: input.text || "" };
    }

    // ── core semantic methods (shared by keyboard and IPC) ──

    function normalizeInteractionKey(key) {
        const k = String(key || "").toLowerCase();
        if (k === "space" || k === "spc")
            return "space";
        if (["h", "j", "k", "l", "m"].indexOf(k) >= 0)
            return k;
        if (k.length === 1)
            return k;
        return "";
    }

    function activateSelectedCore(shiftPressed) {
        return controller.actions.activateSelectedFromInteraction(!!shiftPressed);
    }

    function altInteractCore(keyName, qtKey) {
        const normalized = root.normalizeInteractionKey(keyName);
        if (!normalized)
            return { close: false, success: false, reason: "empty_key" };

        const target = controller.actions.selectedActionTarget();

        if (qtKey !== undefined && qtKey !== null) {
            const preset = KeybindPresets.altActionForKey(target, qtKey);

            if (preset === "switch-on" || preset === "slider-inc") {
                const result = controller.actions.adjustSelectedValue(1);
                return result === undefined
                    ? { close: false, success: true, mode: preset }
                    : Object.assign({ mode: preset }, result);
            }

            if (preset === "switch-off" || preset === "slider-dec") {
                const result = controller.actions.adjustSelectedValue(-1);
                return result === undefined
                    ? { close: false, success: true, mode: preset }
                    : Object.assign({ mode: preset }, result);
            }

            if (preset === "switch-toggle") {
                const result = controller.actions.toggleSelectedMute();
                return result === undefined
                    ? { close: false, success: true, mode: preset }
                    : Object.assign({ mode: preset }, result);
            }
        }

        const recipeResult = controller.actions.runInteractionForKey(normalized);
        return recipeResult === undefined
            ? { close: false, success: false, mode: "recipe" }
            : Object.assign({ mode: "recipe" }, recipeResult);
    }

    // ── semantic wrapper facades ────────────────────────

    function expandSelectedSemantic() {
        let result = null;
        if (controller.navigation.isInTree())
            result = controller.navigation.treeExpandSelected();
        else
            result = controller.navigation.toggleExpandResultTree();
        return {
            result: result === undefined ? null : result,
            selectedIndex: controller.selectedIndex,
            activeNodeKey: controller.activeNodeKey || "",
            inTree: controller.navigation.isInTree(),
            currentTreeKey: controller.currentTreeKey || ""
        };
    }

    function collapseSelectedSemantic() {
        let result = null;
        if (controller.navigation.isInTree())
            result = controller.navigation.treeCollapseSelected();
        else
            result = controller.navigation.toggleCollapseResultTree();
        return {
            result: result === undefined ? null : result,
            selectedIndex: controller.selectedIndex,
            activeNodeKey: controller.activeNodeKey || "",
            inTree: controller.navigation.isInTree(),
            currentTreeKey: controller.currentTreeKey || ""
        };
    }

    function toggleSelectedExpansionSemantic() {
        if (controller.navigation.isInTree()) {
            const current = controller.findTreeRowData(controller.currentTreeKey);
            if (current && current.children && current.children.length > 0)
                return root.expandSelectedSemantic();
            return root.collapseSelectedSemantic();
        }
        const row = controller.selectedResult();
        if (!row)
            return { changed: false, reason: "no_selected_row" };
        if (row.children && row.children.length > 0)
            return root.expandSelectedSemantic();
        return { changed: false, reason: "selected_row_not_expandable" };
    }

    function activateSelectedSemantic(shiftPressed) {
        const target = controller.actions.selectedActionTarget();
        if (root.shouldDryRunAction(target)) {
            root.lastExecutedAction = target ? {
                key: target.nodeId || target.id || "",
                title: target.title || "",
                timestamp: Date.now(),
                testMode: true,
                dryRun: true
            } : null;
            return {
                mode: "activate",
                closeRequested: false,
                close: false,
                result: { ok: true, dryRun: true, close: false, closeRequested: false, actionId: target ? (target.id || target.nodeId || "") : "", reason: "NEWSHELL_TEST_MODE" }
            };
        }
        const result = root.activateSelectedCore(!!shiftPressed);
        root.lastExecutedAction = target ? {
            key: target.nodeId || target.id || "",
            title: target.title || "",
            timestamp: Date.now(),
            testMode: Quickshell.env("NEWSHELL_TEST_MODE") === "1"
        } : null;
        root.applyActivationClose(result);
        return {
            mode: shiftPressed ? "shift-activate" : "activate",
            closeRequested: result ? !!result.closeRequested : false,
            close: result ? result.close !== false : false,
            result: result === undefined ? null : result
        };
    }

    function altInteractSemantic(key, qtKey) {
        const normalized = root.normalizeInteractionKey(key);
        if (!normalized)
            return { changed: false, reason: "empty_key" };

        const target = controller.actions.selectedActionTarget();
        const result = root.altInteractCore(normalized, qtKey);

        return {
            key: normalized,
            qtKey: qtKey === undefined ? null : qtKey,
            targetId: target ? target.id || target.nodeId || "" : "",
            targetKind: target ? target.kind || "" : "",
            result: result === undefined ? null : result
        };
    }

    function setVisualDebugSemantic(enabled) {
        const value = String(enabled === undefined ? "" : enabled).toLowerCase();
        transitionCoordinator.debugEnabled =
            enabled === true ||
            value === "1" || value === "true" || value === "on" || value === "yes";
        return { debugEnabled: transitionCoordinator.debugEnabled };
    }

    // ── visual debug (refactored to use semantic helper) ──

    function queryVisualDebug(arg) {
        root.setVisualDebugSemantic(arg);
        return root.queryVisualState();
    }

    function applyActivationClose(result) {
        if (result && result.close !== false && result.closeRequested)
            root.close();
    }

    // ── interaction state ────────────────────────────────

    function shouldDryRunAction(actionOrRecipe) {
        if (Quickshell.env("NEWSHELL_TEST_MODE") !== "1")
            return false;
        return actionOrRecipe && (
            actionOrRecipe.risk === "destructive" ||
            actionOrRecipe.requiresConfirmation ||
            actionOrRecipe.service === "session" ||
            actionOrRecipe.op === "shutdown" ||
            actionOrRecipe.op === "reboot" ||
            actionOrRecipe.op === "logout"
        );
    }

    function interactionState(includeVisual) {
        const state = {
            version: 1,
            type: "launcherInteractionState",
            visible: root.visible,
            closing: root.closing,
            revealed: root.launcherRevealed,
            query: controller.query || "",
            inputText: input.text || "",
            generation: controller.generation,
            queryRevision: controller.queryRevision,
            loading: controller.loading,
            modelBusy: controller.loading || (
                (controller.query || "") !== "" &&
                (controller.resultsQuery || "") !== (controller.query || "")
            ),
            lastExecutedAction: root.lastExecutedAction,
            resultsCount: controller.results ? controller.results.length : 0,
            selectedIndex: controller.selectedIndex,
            selectedKey: controller.activeNodeKey || null,
            expandedKeys: controller.navigation ? Object.keys(controller.navigation.expandedNodeIds || {}) : [],
            selectedActionIndex: controller.selectedActionIndex,
            activeNodeKey: controller.activeNodeKey || "",
            inTree: controller.navigation.isInTree(),
            currentTreeKey: controller.currentTreeKey || "",
            treeVisualRow: controller.treeVisualRow,
            testMode: Quickshell.env("NEWSHELL_TEST_MODE") === "1",
            testInstanceId: Quickshell.env("NEWSHELL_TEST_INSTANCE_ID") || "",
            ipcNamespace: Quickshell.env("NEWSHELL_IPC_NAMESPACE") || ""
        };
        if (!!includeVisual) {
            state.rows = root.logicalRows();
            state.visual = root.visualMetrics();
        }
        return state;
    }

    function logicalRows() {
        const results = controller.results || [];
        const navigation = controller.navigation;
        const selectedKey = controller.activeNodeKey || "";
        const collIndices = navigation ? (navigation.collapsedResultIndices || {}) : {};
        const inTree = navigation ? navigation.isInTree() : false;

        // Build lookup from nav targets, preserving display order
        var navTargets = navigation ? (navigation.navigationTargets() || []) : [];
        var navByParentIdx = {};
        var navByKey = {};
        for (var ti = 0; ti < navTargets.length; ti += 1) {
            var t = navTargets[ti];
            var r = t.row || {};
            var key = t.key || r.key || r.id || r.nodeId || "";
            if (!key) continue;
            navByKey[key] = t;
            var pIdx = t.parentIndex !== undefined ? t.parentIndex : ti;
            if (!navByParentIdx[pIdx]) navByParentIdx[pIdx] = [];
            navByParentIdx[pIdx].push(t);
        }

        function rowForNavTarget(t) {
            var row = t.row || {};
            var key = t.key || row.key || row.id || row.nodeId || "";
            var depth = t.depth || t.treeDepth || 0;
            var hasChildren = !!(row.children && row.children.length > 0);
            var isExpanded = inTree
                ? (navigation.expandedNodeIds && navigation.expandedNodeIds[key] === true)
                : (hasChildren && row.alwaysExpanded !== false);
            return {
                key: key,
                title: row.title || row.label || "",
                subtitle: row.subtitle || row.genericName || null,
                backend: row.source || row.backendId || null,
                depth: depth,
                path: row.breadcrumbs || [],
                placement: row.placement || null,
                executable: navigation ? navigation.hasActivation(row) : !!row.executable,
                selectable: true,
                selected: key === selectedKey,
                highlighted: key === selectedKey,
                expanded: isExpanded,
                visible: row.ownVisible !== false,
                breadcrumbText: row.breadcrumbText || null,
                defaultAction: row.defaultAction ? (typeof row.defaultAction === "string" ? row.defaultAction : (row.defaultAction.id || null)) : null
            };
        }

        function rowForResult(r, ri) {
            var rk = r.key || r.id || r.nodeId || "";
            var isSel = rk === selectedKey || (!selectedKey && ri === controller.selectedIndex);
            return {
                key: rk,
                title: r.title || r.label || "",
                subtitle: r.subtitle || r.genericName || null,
                backend: r.source || r.backendId || null,
                depth: r.depth !== undefined ? r.depth : 0,
                path: r.breadcrumbs || [],
                placement: r.placement || null,
                executable: navigation ? navigation.hasActivation(r) : false,
                selectable: false,
                selected: isSel || false,
                highlighted: isSel || false,
                expanded: false,
                visible: r.ownVisible !== false,
                breadcrumbText: r.breadcrumbText || null,
                defaultAction: r.defaultAction ? (typeof r.defaultAction === "string" ? r.defaultAction : (r.defaultAction.id || null)) : null
            };
        }

        // Emit rows in display order: for each top-level result, emit its nav target
        // (if selectable), then its non-selectable entry (if not selectable), then
        // any tree children whose parentIndex matches.
        var rows = [];
        var seenKeys = {};
        for (var ri = 0; ri < results.length; ri += 1) {
            var r = results[ri];
            var rk = r.key || r.id || r.nodeId || "";
            if (!rk) continue;

            var navEntry = navByKey[rk];
            if (navEntry) {
                // Selectable: emit nav target
                var emitted = rowForNavTarget(navEntry);
                rows.push(emitted);
                seenKeys[rk] = true;
            } else {
                // Non-selectable: emit result entry at correct position
                rows.push(rowForResult(r, ri));
                seenKeys[rk] = true;
            }

            // Emit tree children (depth > 0) right after their parent
            var children = navByParentIdx[ri] || [];
            for (var ci = 0; ci < children.length; ci += 1) {
                var child = children[ci];
                var ckey = child.key || "";
                if (!ckey || seenKeys[ckey]) continue;
                var cdepth = child.depth || child.treeDepth || 0;
                if (cdepth === 0) continue; // skip root-level, already emitted
                seenKeys[ckey] = true;
                rows.push(rowForNavTarget(child));
            }
        }

        return rows;
    }

    function interactionStateJson(includeVisual) {
        return JSON.stringify(root.interactionState(!!includeVisual));
    }

    // ── perform interaction (core dispatcher) ────────────

    function performInteraction(action, payload, before, includeVisual) {
        tracer.debug("performInteraction", function() { return { action: action, hasPayload: !!payload }; });
        try {
            let result = null;

            switch (action) {
            case "state":
                return root.interactionEnvelope(action, true, before, root.interactionState(!!includeVisual), null, includeVisual);

            case "open":
                root.open(payload.openArg);
                result = { visible: root.visible };
                break;

            case "close":
                root.close();
                result = { visible: root.visible, closing: root.closing };
                break;

            case "toggle":
                if (root.visible)
                    root.close();
                else
                    root.open(payload.openArg);
                result = { visible: root.visible, closing: root.closing };
                break;

            case "setQuery":
                result = root.setLauncherQuery(payload.query);
                break;

            case "typeText":
                result = root.appendLauncherText(payload.text);
                break;

            case "backspace":
                result = root.backspaceLauncherText(payload.count);
                break;

            case "clearQuery":
                result = root.clearLauncherQuery();
                break;

            case "reset":
                input.text = "";
                controller.reset();
                result = { query: controller.query || "", inputText: input.text || "" };
                break;

            case "moveSelection":
                controller.navigation.moveSelection(Number(payload.delta || 0));
                result = { selectedIndex: controller.selectedIndex, activeNodeKey: controller.activeNodeKey || "" };
                break;

            case "expandSelected":
                result = root.expandSelectedSemantic();
                break;

            case "collapseSelected":
                result = root.collapseSelectedSemantic();
                break;

            case "toggleSelectedExpansion":
                result = root.toggleSelectedExpansionSemantic();
                break;

            case "completeSelected":
                result = controller.actions.runRecipeSlot("complete");
                break;

            case "activateSelected":
                result = root.activateSelectedSemantic(!!payload.shift);
                break;

            case "altInteract":
                result = root.altInteractSemantic(
                    String(payload.key || ""),
                    payload.qtKey === undefined ? undefined : Number(payload.qtKey)
                );
                break;

            case "visualDebug":
                result = root.setVisualDebugSemantic(payload.enabled);
                break;

            default:
                return root.interactionError(action, before, "unknown_action",
                    "Unknown launcher interaction action: " + action);
            }

            return root.interactionEnvelope(action, true, before, result, null, includeVisual);
        } catch (e) {
            return root.interactionError(action, before, "exception", String(e), includeVisual);
        }
    }

    // ── IPC entry points ─────────────────────────────────

    function interact(action, arg) {
        const payload = root.parseInteractionArg(arg);
        payload.action = String(action || payload.action || "");
        const includeVisual = !!payload.visual;
        const before = root.interactionState(includeVisual);
        if (payload._parseError)
            return root.interactionError(payload.action || "parse", before, "invalid_json", payload._parseError, includeVisual);
        return root.performInteraction(payload.action, payload, before, includeVisual);
    }

    function interactJson(payloadStr) {
        const payload = root.parseInteractionArg(payloadStr);
        const includeVisual = !!payload.visual;
        const before = root.interactionState(includeVisual);
        if (payload._parseError)
            return root.interactionError("parse", before, "invalid_json", payload._parseError, includeVisual);
        const action = String(payload.action || "");
        return root.performInteraction(action, payload, before, includeVisual);
    }

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    visible: false
    focusable: true
    color: "transparent"

    Timer {
        id: closeTimer

        interval: Config.motion.medium
        repeat: false
        onTriggered: root.finishClose()
    }

    Component.onCompleted: {
        if (WlrLayershell)
            WlrLayershell.layer = WlrLayer.Overlay;
        controller.resultView = resultViewAdapter;
    }

    QtObject {
        id: resultViewAdapter

        function itemAt(index) {
            return resultsList.itemAtIndex(index);
        }
    }

    Visual.LauncherCoordinatorAdapter {
        id: coordinatorAdapter
        controller: controller
        coordinator: transitionCoordinator
    }

    Animations.TransitionListCoordinator {
        id: transitionCoordinator
    }

    function visualContextKey() {
        return (root.backends || []).map(function(backend) {
            return backend ? backend.backendId || "" : "";
        }).join("|");
    }

    function applyVisualSnapshot() {
        coordinatorAdapter.applySnapshot({
            inputText: controller.query,
            contextKey: root.visualContextKey(),
            reason: "query"
        });
    }

    function visualMetrics() {
        const items = [];
        if (resultsList) {
            for (let i = 0; i < transitionCoordinator.model.count; i += 1) {
                const row = transitionCoordinator.model.get(i);
                const delegate = resultsList.itemAtIndex(row.rank);
                items.push({
                    modelIndex: i,
                    key: row.key,
                    rank: row.rank,
                    targetRank: row.targetRank,
                    phase: row.phase,
                    x: delegate ? delegate.x : 0,
                    y: delegate ? delegate.y : row.targetY,
                    targetY: row.targetY,
                    width: delegate ? delegate.width : 0,
                    height: delegate ? delegate.height : row.visualHeight,
                    targetHeight: row.targetHeight,
                    measuredHeight: row.measuredHeight,
                    opacity: delegate ? delegate.opacity : row.targetOpacity,
                    scale: delegate ? delegate.scale : row.targetScale,
                    reveal: delegate ? (row.targetHeight > 0 ? delegate.height / row.targetHeight : 0) : 0
                });
            }
        }

        const cardGeom = card ? { x: card.x, y: card.y, width: card.width, height: card.height } : {};
        const inputGeom = input ? { x: input.x, y: input.y, width: input.width, height: input.height } : {};
        const frameGeom = resultsFrame ? { x: resultsFrame.x, y: resultsFrame.y, width: resultsFrame.width, height: resultsFrame.height, targetHeight: resultsFrame.targetHeight } : {};
        const listGeom = resultsList ? { x: resultsList.x, y: resultsList.y, width: resultsList.width, height: resultsList.height, contentHeight: resultsList.contentHeight, contentY: resultsList.contentY } : {};

        return {
            query: controller.query || "",
            resultsCount: controller.results.length,
            selectedIndex: controller.selectedIndex,
            card: cardGeom,
            input: inputGeom,
            resultsFrame: frameGeom,
            resultsList: listGeom,
            items: items
        };
    }

    HyprlandFocusGrab {
        id: focusGrab
        windows: [root]
        onCleared: {
            if (root.visible)
                root.close();
        }
    }

    Backends.DesktopAppsBackend {
        id: desktopBackend
        backendId: "desktop"
        maxResults: root.maxResultsPerBackend
        controller: controller
    }

    Backends.BackendsBackend {
        id: backendsBackend
        backendId: "backends"
        describedBackends: root.allBackends
        controller: controller
    }

    Backends.DesktopActionsBackend {
        id: desktopActionsBackend
        shellScreenState: root.shellScreenState
        controller: controller
    }

    Backends.CalculatorBackend {
        id: calculatorBackend
        backendId: "calculator"
        controller: controller
    }

    Backends.WebSearchBackend {
        id: webBackend
        backendId: "web"
        controller: controller
    }

    Backends.FilesBackend {
        id: filesBackend
        backendId: "files"
        controller: controller
    }

    Backends.WorkerTestBackend {
        id: workerTestBackend
        backendId: "worker-test"
        controller: controller
    }

    LauncherController {
        id: controller
        backends: root.backends
        maxResults: root.visibleResultRows

        onQueryReplacementRequested: function(text) {
            input.text = text;
            updateQuery(text);
            input.forceActiveFocus();
            input.cursorPosition = input.text.length;
        }

    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    Rectangle {
        id: card
        property real revealOffset: root.launcherRevealed ? 0 : -Config.spacing.sm

        width: Math.min(640, Math.max(360, root.width * 0.42))
        height: content.implicitHeight + Config.spacing.sm * 2
        opacity: root.launcherRevealed ? 1 : 0
        anchors.top: parent.top
        anchors.topMargin: Math.max(Config.spacing.xxl, root.height * 0.16) + revealOffset
        anchors.horizontalCenter: parent.horizontalCenter
        color: Config.styling.bg1
        border.color: Config.styling.bg4
        border.width: 1
        radius: Config.styling.radius
        clip: true

        Animations.PanelBehavior on opacity {
        }

        Animations.PanelBehavior on revealOffset {
        }

        ColumnLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Config.spacing.sm
            height: implicitHeight
            spacing: resultsFrame.visible ? Config.spacing.sm : 0

            Animations.LayoutBehavior on spacing {
            }

            TextField {
                id: input
                placeholderText: qsTr("Search apps, ? for sources")
                text: controller.query
                color: Config.styling.text0
                placeholderTextColor: Config.styling.placeholderText
                selectedTextColor: Config.styling.selectionText
                selectionColor: Config.styling.selectionBackgroundActive
                font.pixelSize: 18
                focus: root.visible
                Layout.fillWidth: true
                Layout.preferredHeight: 32

                background: Rectangle {
                    color: Config.styling.bg2
                    border.color: input.activeFocus ? Config.styling.primaryAccent : Config.styling.bg4
                    border.width: 1
                    radius: Config.styling.radius
                }

                onTextEdited: controller.updateQuery(text)

                Keys.onPressed: function(event) {
                    if (!handleLauncherKey(event))
                        return;
                    event.accepted = true;
                }

                function handleLauncherKey(event) {
                    DebugLogger.log("key", "pressed", {
                        key: event.key,
                        text: event.text,
                        modifiers: event.modifiers,
                        activeNodeKey: controller.activeNodeKey,
                        currentTreeKey: controller.currentTreeKey,
                        selectedIndex: controller.selectedIndex,
                        queryLength: text.length
                    });

                    if (event.key === Qt.Key_Escape)
                        return handleEscapeKey(event);

                    if (event.modifiers & Qt.AltModifier)
                        return handleAltInteractionKey(event);

                    if (event.modifiers & Qt.ControlModifier)
                        return handleCtrlKey(event);

                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                        return handleActivationKey(event);

                    if (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))
                        return handleTabKey(event);

                    return false;
                }

                function handleEscapeKey(event) {
                    if (text.length > 0) {
                        text = "";
                        controller.reset();
                    } else {
                        root.close();
                    }
                    return true;
                }

                function handleActivationKey(event) {
                    var shift = !!(event.modifiers & Qt.ShiftModifier);
                    var target = controller.actions.selectedActionTarget();
                    DebugLogger.log("activate", "enter", {
                        targetId: target ? target.id || target.nodeId || "" : "none",
                        targetKind: target ? target.kind || "" : "",
                        inTree: controller.navigation.isInTree(),
                        shift: shift
                    });

                    var result = root.activateSelectedCore(shift);
                    DebugLogger.log("activate", "result", result);
                    root.applyActivationClose(result);
                    return true;
                }

                function handleTabKey(event) {
                    var result = controller.actions.runRecipeSlot("complete");
                    return true;
                }

                function handleCtrlKey(event) {
                    switch (event.key) {
                    case Qt.Key_Down:
                    case Qt.Key_N:
                    case Qt.Key_J:
                        controller.navigation.moveSelection(1);
                        return true;
                    case Qt.Key_Up:
                    case Qt.Key_P:
                    case Qt.Key_K:
                        controller.navigation.moveSelection(-1);
                        return true;
                    case Qt.Key_H:
                        if (controller.navigation.isInTree())
                            controller.navigation.treeCollapseSelected();
                        else
                            controller.navigation.toggleCollapseResultTree();
                        return true;
                    case Qt.Key_L:
                        if (controller.navigation.isInTree())
                            controller.navigation.treeExpandSelected();
                        else
                            controller.navigation.toggleExpandResultTree();
                        return true;
                    }
                    return false;
                }

                function handleAltInteractionKey(event) {
                    var keyName = keyNameFromEvent(event);
                    if (!keyName)
                        return false;

                    // Consume the event immediately to prevent the character
                    // from being inserted into the search field.
                    event.accepted = true;

                    var target = controller.actions.selectedActionTarget();
                    var targetId = target ? target.id || target.nodeId || "" : "none";
                    var targetKind = target ? target.kind || "" : "";
                    DebugLogger.log("alt-interaction", "dispatch", {
                        keyName: keyName,
                        qtKey: event.key,
                        targetId: targetId,
                        targetKind: targetKind,
                        availableKeys: target ? Object.keys(RecipeResolver.effectiveInteractions(target)) : []
                    });

                    var result = root.altInteractCore(keyName, event.key);
                    DebugLogger.log("alt-interaction", "result", result);
                    return true;
                }

                function keyNameFromEvent(event) {
                    var map = {};
                    map[String(Qt.Key_H)] = "h";
                    map[String(Qt.Key_L)] = "l";
                    map[String(Qt.Key_M)] = "m";
                    map[String(Qt.Key_J)] = "j";
                    map[String(Qt.Key_K)] = "k";

                    var lower = String.fromCharCode(event.key).toLowerCase();
                    if (lower.length === 1)
                        return lower;

                    return map[String(event.key)] || lower;
                }
            }

            Item {
                id: resultsFrame
                readonly property real targetHeight: {
                    const contentHeight = transitionCoordinator.contentHeight || resultsList.contentHeight || 0;
                    const bootstrapHeight = transitionCoordinator.hasActiveItems ? root.rowHeight : 0;
                    return Math.min(Math.max(contentHeight, bootstrapHeight), root.rowHeight * root.visibleResultRows);
                }

                visible: targetHeight > 0 || resultsList.contentHeight > 0
                clip: true
                Layout.fillWidth: true
                Layout.preferredHeight: targetHeight
                Layout.maximumHeight: root.rowHeight * root.visibleResultRows

                function ensureActiveVisible() {
                    if (controller.selectedIndex < 0)
                        return;

                    var current = resultsList.itemAtIndex(controller.selectedIndex);
                    if (!current)
                        return;

                    var y = current.y;
                    var height = current.height;

                    if (controller.navigation.isInTree()) {
                        var treeRowH = 44;
                        if (current.item && current.item.treeRowHeight)
                            treeRowH = current.item.treeRowHeight;
                        y += root.rowHeight + Math.max(0, controller.treeVisualRow) * treeRowH;
                        height = treeRowH;
                    }

                    if (y < resultsList.contentY)
                        resultsList.contentY = y;
                    else if (y + height > resultsList.contentY + resultsList.height)
                        resultsList.contentY = Math.max(0, y + height - resultsList.height);
                }

                Connections {
                    target: controller
                    function onActiveNodeKeyChanged() { Qt.callLater(resultsFrame.ensureActiveVisible); }
                    function onTreeVisualRowChanged() { Qt.callLater(resultsFrame.ensureActiveVisible); }
                    function onResultsChanged() {
                        root.applyVisualSnapshot();
                        Qt.callLater(resultsFrame.ensureActiveVisible);
                    }
                }

                Visual.PositionedResultList {
                    id: resultsList
                    anchors.fill: parent
                    coordinator: transitionCoordinator
                    resultDelegate: root.resultDelegate
                    controller: controller
                    iconSize: root.iconSize
                    visibleResultRows: root.visibleResultRows
                    showSubtitles: root.showSubtitles
                    showActionHint: root.showActionHint
                    showEvidence: root.showEvidence
                    rowSpacing: Config.spacing.xxs
                    estimatedRowHeight: root.rowHeight

                    onCloseRequested: root.close()
                }
            }
        }
    }

    Component {
        id: defaultResultDelegate
        Delegates.DefaultResultDelegate {}
    }
}
