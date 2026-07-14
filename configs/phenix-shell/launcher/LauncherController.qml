import QtQuick
import QtQml
import qs.services
import "logic/"
import "logic/RoutingTree.js" as RoutingTree
import "controllers" as Controllers
import "policies" as P

Item {
    readonly property var tracer: Logger.scope("launcher.controller", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.controller", { category: "launcher" })
    id: root

    property alias query: searchSession.query
    property var backends: []
    property alias results: navigation.results
    property var routingTree: RoutingTree.makeTree()
    property alias selectedIndex: navigation.selectedIndex
    property alias selectedActionIndex: navigation.selectedActionIndex
    property alias loading: searchSession.loading
    property alias generation: searchSession.generation
    property alias _asyncGen: searchSession.asyncGeneration
    property alias queryRevision: searchSession.queryRevision
    property int maxResults: 12
    property real visibilityThreshold: 0.18
    property bool includePath: true
    property bool showHidden: false
    property int maxTreeDepth: 4
    property alias expandedNodeIds: navigation.expandedNodeIds
    property alias collapsedResultIndices: navigation.collapsedResultIndices
    property alias lastQuery: navigation.lastQuery
    property alias lastDirective: navigation.lastDirective
    property alias lastEvaluatedRoot: navigation.lastEvaluatedRoot
    property alias asyncBackendQueries: searchSession.asyncBackendQueries
    property alias resultsQuery: navigation.resultsQuery
    property bool debugEnabled: false
    property string lastAsyncVisualJson: ""
    property alias pendingConfirmId: actions.pendingConfirmId
    property alias pendingConfirmTimeoutMs: actions.pendingConfirmTimeoutMs
    // confirmationSatisfied is a transient flag set by LauncherActionController
    // when ActivationConfirmation.checkActivation returns {confirmed: true}.
    // It is read by ActivationGate/ActionRegistry to authorize risky actions.
    // Reset to false after each activation cycle.
    property bool confirmationSatisfied: false

    // Tree navigation state
    property alias currentTreeView: navigation.currentTreeView
    property alias currentTreeKey: navigation.currentTreeKey
    property alias treeVisualRow: navigation.treeVisualRow
    readonly property bool inTree: navigation.inTree
    property alias resultTreeViews: navigation.resultTreeViews
    property alias resultView: navigation.resultView
    property alias activeNodeKey: navigation.activeNodeKey

    signal queryReplacementRequested(string text)
    signal queryUpdateRequested(string text)
    signal resetRequested()
    signal resultsClearRequested()
    signal resultsRefreshRequested()
    signal collapseResultExpanded(int resultIndex)
    signal expandResultExpanded(int resultIndex)
    signal selectionResetRequested()
    signal asyncLoadingRefreshRequested()
    signal asyncBackendSearchStarted(var backend, string key, string text)
    signal asyncBackendResultsReceived(var backend, string key, string text, int generation, var update)
    signal searchRequested(string text, int generation)
    signal searchStarted(string text, int generation, int revision)
    signal searchCompleted(string text, int generation, int revision, var output)
    signal resultsAvailable(string text, int generation, int revision, var rows, var output)
    signal treeSwitchRefreshRequested(int resultIndex)

    Controllers.LauncherSearchSession {
        id: searchSession
        controller: root
        backends: root.backends
        routingTree: root.routingTree
        maxResults: root.maxResults

        onResultsClearRequested: root.resultsClearRequested()
        onSearchStarted: function(text, requestGeneration, revision) {
            root.searchStarted(text, requestGeneration, revision);
        }
        onSearchCompleted: function(text, requestGeneration, revision, output) {
            root.searchCompleted(text, requestGeneration, revision, output);
        }
        onResultsAvailable: function(text, requestGeneration, revision, rows, output) {
            root.resultsAvailable(text, requestGeneration, revision, rows, output);
        }
    }

    Controllers.LauncherNavigationState {
        id: navigation
        controller: root
    }

    Controllers.LauncherActionController {
        id: actions
        controller: root
    }

    Controllers.LauncherDebugController {
        id: debugController
        controller: root
    }

    P.UsagePolicy {}
    P.RecencyPolicy {}
    P.SemanticPolicy {}
    P.TokenClaimPolicy {}
    P.SwitchActionPolicy {}
    P.SwitchAliasesBoostPolicy {}
    P.FieldMatchPolicy { policyId: "field-match" }
    P.DescendantBoostPolicy { policyId: "descendant-boost" }
    P.VisibleFlagPolicy {}
    P.HasOwnScorePolicy {}
    P.AboveMinScorePolicy { policyId: "above-min-score" }
    P.OwnScoreMinPolicy { policyId: "own-score-min" }
    P.CandidateOrVisiblePolicy {}
    P.HasEvidencePolicy {}
    P.OwnScoreBeatsParentPolicy {}
    P.ScoreDominatesPolicy { policyId: "score-dominates" }
    P.OwnScoreDominatesPolicy { policyId: "own-score-dominates" }
    P.ScoreBeatsParentPolicy {}
    P.ExpandOnTrailingSpace {}
    P.TokenFlowPolicies {}
    P.TakeoverPolicies {}
    P.ExpandRetainPolicies {}
    P.RiskGatePolicy {}

    onQueryUpdateRequested: function(text) { searchSession.updateQuery(text); }
    onResetRequested: function() { searchSession.reset(); lastAsyncVisualJson = ""; }
    onResultsClearRequested: function() { navigation.clearResults(); }
    onResultsRefreshRequested: function() { navigation.refreshResults(); }
    onSelectionResetRequested: function() { navigation.resetSelection(); }
    onAsyncLoadingRefreshRequested: function() { searchSession.refreshLoading(); }
    onAsyncBackendSearchStarted: function(backend, key, text) { searchSession.beginAsyncBackendSearch(backend, key, text); }
    onAsyncBackendResultsReceived: function(backend, key, text, requestGeneration, update) { searchSession.receiveAsyncBackendResults(backend, key, text, requestGeneration, update); }
    onSearchRequested: function(text, requestGeneration) { searchSession.requestSearch(text, requestGeneration); }
    onResultsAvailable: function(text, requestGeneration, revision, rows, output) {
        if (!output || requestGeneration !== root.generation || revision !== root.queryRevision || text !== root.query) {
            tracer.trace("resultsAvailable", function() { return { text: text, stale: true, gen: requestGeneration, revision: revision }; });
            return;
        }

        tracer.info("resultsAvailable", function() { return { text: text, rows: (rows || []).length, gen: requestGeneration }; });
        lastQuery = output.query;
        lastDirective = output.directive;
        lastEvaluatedRoot = output.evaluatedRoot;
        if (output.evaluation) {
            output.evaluation.queryRevision = revision;
            lastEvaluation = output.evaluation;
        }
        setResults(rows, text);
    }

    property alias navigation: navigation
    property alias actions: actions
    property alias debug: debugController
    property alias searchSession: searchSession

    // Compatibility façade for IPC/tests/older visual components. Prefer controller.navigation/actions/debug in new code.
    function clearSearchOutputState() { navigation.clearSearchOutputState(); }
    function queryIsEmptyForSelection() { return navigation.queryIsEmptyForSelection(); }
    function hasActivation(row) { return navigation.hasActivation(row); }
    function isSelectable(row) { return navigation.isSelectable(row); }
    function isRowSelectable(row) { return navigation.isRowSelectable(row); }
    function selectedResult() { return navigation.selectedResult(); }
    function rowKey(row) { return navigation.rowKey(row); }
    function setResults(newResults, sourceQuery) { navigation.setResults(newResults, sourceQuery); }
    function registerResultTreeView(index, treeView) { navigation.registerResultTreeView(index, treeView); }
    function navigationTargets() { return navigation.navigationTargets(); }
    function resolveTreeViewAtIndex(index) { return navigation.resolveTreeViewAtIndex(index); }
    function applyNavigationTarget(target) { navigation.applyNavigationTarget(target); }
    function findTreeVisualRow(treeView, key) { return navigation.findTreeVisualRow(treeView, key); }
    function resetTreeNavigation() { navigation.resetTreeNavigation(); }
    function enterTree(result, treeView) { return navigation.enterTree(result, treeView); }
    function exitTree() { navigation.exitTree(); }
    function isInTree() { return navigation.isInTree(); }
    function moveInTree(delta) { navigation.moveInTree(delta); }
    function treeToggleSelected() { return navigation.treeToggleSelected(); }
    function findTreeRowData(key) { return navigation.findTreeRowData(key); }
    function findInChildren(row, key) { return navigation.findInChildren(row, key); }
    function findParentResultByKey(key) { return navigation.findParentResultByKey(key); }
    function loadLazyChildren(key) { navigation.loadLazyChildren(key); }

    // Debug/IPC façade
    function serializeRow(row) { return debugController.serializeRow(row); }
    function serializeRowsForQuery(rows, queryInfo) { return debugController.serializeRowsForQuery(rows, queryInfo); }

    function buildDirectiveFromRoute(rawQuery, route) { return Engine.buildDirectiveFromRoute(rawQuery, route, backends || []); }
    function findHelpTitle(backendId) { return Engine.findHelpTitle(backends || [], backendId); }

    function debugBenchmark(arg) { return debugController.debugBenchmark(arg); }
    function debugBenchmarkV2(arg) { return debugController.debugBenchmarkV2(arg); }
    function parseBenchmarkConfig(arg) { return debugController.parseBenchmarkConfig(arg); }
    function debugVisualRows(text) { return debugController.debugVisualRows(text); }
    function debugApplyQuery(text) { return debugController.debugApplyQuery(text); }
    function debugVisualOutput(text, output) { return debugController.debugVisualOutput(text, output); }
    function queryPipeline(text) { return debugController.queryPipeline(text); }
    function queryPolicies(text) { return debugController.queryPolicies(text); }
    function collectActivePolicies(ev) { return debugController.collectActivePolicies(ev); }
    function queryCases() { return debugController.queryCases(); }
    function queryRunCases() { return debugController.queryRunCases(); }
    function regressionCaseQueries() { return debugController.regressionCaseQueries(); }
    function summarizeCaseResults(results) { return debugController.summarizeCaseResults(results); }

    // Debug V2 IPC facade
    property var lastEvaluation: null
    function debugOverview(args) { return debugController.debugOverview(args || ""); }
    function debugInspect(args) { return debugController.debugInspect(args || ""); }
    function debugPolicies(args) { return debugController.debugPolicies(args || ""); }
    function debugFind(args) { return debugController.debugFind(args || ""); }
    function debugAction(args) { return debugController.debugAction(args || ""); }
    function debugStats(args) { return debugController.debugStats(args || ""); }
    function debugRaw(args) { return debugController.debugRaw(args || ""); }

    // Search/session façade
    function stateForSearch() {
        tracer.trace("stateForSearch", function() { return {}; });
        return {
            selectedNodeId: selectedResult() ? selectedResult().nodeId : null,
            expandedNodeIds: expandedNodeIds || {}
        };
    }

    function searchOptions() {
        return {
            routingTree: root.routingTree,
            visibilityThreshold: visibilityThreshold,
            includePath: includePath,
            showHidden: showHidden,
            maxTreeDepth: maxTreeDepth
        };
    }

    function updateQuery(text) { tracer.info("updateQuery", function() { return { text: text }; }); queryUpdateRequested(text || ""); }
    function triggerAsyncBackends(text, currentGeneration) { tracer.trace("triggerAsyncBackends", function() { return { text: text, gen: currentGeneration }; }); searchSession.triggerAsyncBackends(text, currentGeneration); }
    function hasPendingAsyncBackends() { return searchSession.hasPendingAsyncBackends(); }
    function reset() { tracer.info("reset", function() { return {}; }); resetRequested(); }
    function backendId(backend) { return backend ? backend.backendId || "" : ""; }

    // Activation/action façade
    function activateSelected(shiftPressed) { return actions.activateSelected(shiftPressed); }
    function requiresConfirm(activation) { return actions.requiresConfirm(activation); }
    function completeSelected() { return actions.completeSelected(); }
    function activateResult(result, action) { return actions.activateResult(result, action); }
    function executeRecipeSlot(target, slotName) { return actions.executeRecipeSlot(target, slotName); }
    function applyIntent(result, intent) { return actions.applyIntent(result, intent); }
    function activateResultAction(result, actionId) { return actions.activateResultAction(result, actionId); }
    function refreshSwitchResult(result, action) { actions.refreshSwitchResult(result, action); }
    function activateTreeRowByKey(key, actionId) { return actions.activateTreeRowByKey(key, actionId); }
    function treeActivateCurrent() { return actions.treeActivateCurrent(); }
    function runRecipe(recipe, target) { return actions.runRecipe(recipe, target); }
    function runRecipeSlot(slotName) { return actions.runRecipeSlot(slotName); }
    function effectiveRecipeForTarget(target, slotName) { return actions.effectiveRecipeForTarget(target, slotName); }
    function effectiveInteractionsForTarget(target) { return actions.effectiveInteractionsForTarget(target); }
    function _legacyApplyIntent(result, intent) { return actions._legacyApplyIntent(result, intent); }
    function _handleActivationWithConfirm() { return actions._handleActivationWithConfirm(); }
}
