pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.services
import "../utils"
import "../modules/bar" as Bar
import "../modules/quickmenu" as Quickmenu
import "../modules/hyprlandPreview" as HyprlandPreview
import "../modules/background" as Background
import "../launcher" as Launcher

Singleton {
    id: root

    readonly property var tracer: Logger.scope("service.shellState", { category: "service" })
    readonly property var prof: Profiler.scope("service.shellState", { category: "service" })

    readonly property alias instances: screenStates.instances

    Component.onCompleted: {
        tracer.info("completed", function() { return { screenCount: screenStates?.instances?.length || 0 }; });
        ShellActions.launcherOpenRequested.connect(function(arg) {
            forActiveScreens(screen => {
                const ss = getScreenByName(screen.name);
                if (ss) ss.launcher.open(arg);
            });
        });
        ShellActions.launcherCloseRequested.connect(function() {
            forActiveScreens(screen => {
                const ss = getScreenByName(screen.name);
                if (ss) ss.launcher.close();
            });
        });
        ShellActions.dashboardOpenRequested.connect(function(tab) {
            forActiveScreens(screen => {
                const ss = getScreenByName(screen.name);
                if (ss) ss.openDashboard(tab);
            });
        });
        ShellActions.dashboardToggleRequested.connect(function(tab) {
            forActiveScreens(screen => {
                const ss = getScreenByName(screen.name);
                if (ss) ss.toggleDashboard(tab);
            });
        });
        ShellActions.hyprlandPreviewRequested.connect(function(screen, toplevel, x) {
            const ss = getScreenByName(screen.name);
            if (ss) ss.hyprlandPreview.showPreviewAtGlobal(toplevel, x);
        });
        ShellActions.hyprlandPreviewHoverDelta.connect(function(screen, delta) {
            const ss = getScreenByName(screen.name);
            if (ss) ss.hyprlandPreview.externalHovers += delta;
        });
    }

    component ScreenState: QtObject {
        id: screenState

        required property ShellScreen modelData
        readonly property ShellScreen screen: screenState.modelData

        property int dashboardWidth: 392
        // Keep this order in sync with quickmenu/Window.qml SwipeView pages and bar dashboard icons.
        readonly property var dashboardTabs: ["overview", "audio", "notifications", "bluetooth", "wifi", "energy", "stats"]
        property string activeTab: ""
        property string dashboardPhase: "closed"
        readonly property bool dashboardOpen: dashboardPhase !== "closed"
        readonly property bool barExpandedForDashboard: dashboardOpen
        readonly property int dashboardTransitionMs: Config.motion.medium

        function normalizeTab(tabName) {
            const normalized = tabName || "overview";
            return dashboardTabs.indexOf(normalized) >= 0 ? normalized : "overview";
        }

        function tabIndex(tabName) {
            const normalizedTab = normalizeTab(tabName);
            const index = dashboardTabs.indexOf(normalizedTab);
            return index >= 0 ? index : 0;
        }

        function isIndicatorActive(tabName) {
            const normalizedTab = normalizeTab(tabName);
            return activeTab === normalizedTab;
        }

        function finishTransition() {
            switch (dashboardPhase) {
            case "opening":
            case "switching":
                dashboardPhase = "open";
                break;
            case "closing":
                activeTab = "";
                dashboardPhase = "closed";
                break;
            default:
                break;
            }
        }

        function queueTransition() {
            if (dashboardTransitionMs <= 0) {
                finishTransition();
                return;
            }

            transitionTimer.restart();
        }

        function openDashboard(tabName) {
            const normalizedTab = normalizeTab(tabName);
            const sameTarget = dashboardOpen && activeTab === normalizedTab;

            if (sameTarget)
                return;

            activeTab = normalizedTab;
            dashboardPhase = dashboardOpen ? "switching" : "opening";
            queueTransition();
        }

        function stepDashboardTab(offset) {
            if (!dashboardOpen)
                return false;

            const nextTab = dashboardTabs[tabIndex(activeTab) + offset];
            if (!nextTab)
                return false;

            openDashboard(nextTab);
            return true;
        }

        function closeDashboard() {
            if (!dashboardOpen)
                return;

            dashboardPhase = "closing";
            queueTransition();
        }

        function toggleDashboard(tabName) {
            const normalizedTab = normalizeTab(tabName);

            if (isIndicatorActive(normalizedTab)) {
                closeDashboard();
                return;
            }

            openDashboard(normalizedTab);
        }

        property Timer transitionTimer: Timer {
            id: transitionTimer
            interval: screenState.dashboardTransitionMs
            onTriggered: screenState.finishTransition()
        }

        property Background.Window background: Background.Window {
            screen: screenState.screen
        }

        property Bar.Window bar: Bar.Window {
            screen: screenState.screen
            shellScreenState: screenState
            IpcHandler {
                target: IpcTargets.name(`bar-${screen.name}`)
                function open() {
                    bar.open();
                }
                function close() {
                    bar.close();
                }
                function toggle() {
                    bar.toggle();
                }
            }
        }

        property Quickmenu.Window quickmenu: Quickmenu.Window {
            screen: screenState.screen
            shellScreenState: screenState
        }

        property HyprlandPreview.Window hyprlandPreview: HyprlandPreview.Window {
            screen: screenState.screen
            topInset: bar.implicitHeight
        }

        property Launcher.Launcher launcher: Launcher.Launcher {
            screen: screenState.screen
            shellScreenState: screenState
        }
    }

    Variants {
        id: screenStates
        model: Quickshell.screens
        delegate: ScreenState {}
    }

    function isTestMode() {
        return Quickshell.env("PHENIX_SHELL_TEST_MODE") === "1";
    }

    function activeScreenStates() {
        const focused = root.instances.filter(screenState =>
            Hyprland.focusedMonitor && Hyprland.focusedMonitor === Hyprland.monitorFor(screenState.screen)
        );
        if (focused.length > 0)
            return focused;
        if (root.isTestMode() && root.instances.length > 0)
            return [root.instances[0]];
        return [];
    }

    function forActiveScreens(callback) {
        root.activeScreenStates().forEach(screenState => callback(screenState.screen));
    }

    IpcHandler {
        target: IpcTargets.name("bar")
        Component.onCompleted: { tracer.info("ipc-handler", function() { return { target: "bar" }; }); }
        function open() {
            forActiveScreens(screen => getScreenByName(screen.name).bar.open());
        }
        function close() {
            forActiveScreens(screen => getScreenByName(screen.name).bar.close());
        }
        function toggle() {
            forActiveScreens(screen => getScreenByName(screen.name).bar.toggle());
        }
    }

    IpcHandler {
        target: IpcTargets.name("launcher")
        Component.onCompleted: { tracer.info("ipc-handler", function() { return { target: "launcher" }; }); }
        function open() {
            forActiveScreens(screen => {
                const ss = getScreenByName(screen.name);
                if (ss)
                    ss.launcher.open();
            });
        }
        function openWith(arg: string) {
            try {
                const parsed = JSON.parse(arg);
                forActiveScreens(screen => getScreenByName(screen.name).launcher.open(parsed));
            } catch (e) {
                forActiveScreens(screen => getScreenByName(screen.name).launcher.open(arg));
            }
        }
        function close() {
            forActiveScreens(screen => getScreenByName(screen.name).launcher.close());
        }
        function toggle() {
            forActiveScreens(screen => {
                const ss = getScreenByName(screen.name);
                if (ss) {
                    const launcher = ss.launcher;
                    if (launcher)
                        launcher.visible ? launcher.close() : launcher.open();
                }
            });
        }
        function toggleWith(arg: string) {
            try {
                const parsed = JSON.parse(arg);
                forActiveScreens(screen => {
                    const launcher = getScreenByName(screen.name).launcher;
                    launcher.visible ? launcher.close() : launcher.open(parsed);
                });
            } catch (e) {
                forActiveScreens(screen => {
                    const launcher = getScreenByName(screen.name).launcher;
                    launcher.visible ? launcher.close() : launcher.open(arg);
                });
            }
        }

        // Semantic interaction IPC — drives launcher state via semantic actions, not key events
        function state(arg: string): string {
            const launcher = root.activeLauncher();
            const includeVisual = String(arg || "").toLowerCase() === "visual"
                || String(arg || "").toLowerCase() === "true"
                || String(arg || "").toLowerCase() === "1";
            return launcher
                ? launcher.interactionStateJson(includeVisual)
                : root.launcherError("state", "no_launcher", "No launcher instance available");
        }
        function visualState(): string {
            const launcher = root.activeLauncher();
            return launcher
                ? launcher.interactionStateJson(true)
                : root.launcherError("visualState", "no_launcher", "No launcher instance available");
        }
        function interact(action: string, arg: string): string {
            const launcher = root.activeLauncher();
            return launcher
                ? launcher.interact(action, arg || "")
                : root.launcherError(action, "no_launcher", "No launcher instance available");
        }
        function interactJson(payload: string): string {
            const launcher = root.activeLauncher();
            return launcher
                ? launcher.interactJson(payload || "{}")
                : root.launcherError("interactJson", "no_launcher", "No launcher instance available");
        }
        // Convenience wrappers — route through interactJson for consistency
        function setQuery(query: string): string {
            const launcher = root.activeLauncher();
            return launcher
                ? launcher.interactJson(JSON.stringify({ action: "setQuery", query: query }))
                : root.launcherError("setQuery", "no_launcher", "No launcher instance available");
        }
        function typeText(text: string): string {
            const launcher = root.activeLauncher();
            return launcher
                ? launcher.interactJson(JSON.stringify({ action: "typeText", text: text }))
                : root.launcherError("typeText", "no_launcher", "No launcher instance available");
        }
        function backspace(count: string): string {
            const launcher = root.activeLauncher();
            return launcher
                ? launcher.interactJson(JSON.stringify({ action: "backspace", count: Number(count || 1) }))
                : root.launcherError("backspace", "no_launcher", "No launcher instance available");
        }
        function moveSelection(delta: string): string {
            const launcher = root.activeLauncher();
            return launcher
                ? launcher.interactJson(JSON.stringify({ action: "moveSelection", delta: Number(delta || 0) }))
                : root.launcherError("moveSelection", "no_launcher", "No launcher instance available");
        }
        function expandSelected(): string {
            const launcher = root.activeLauncher();
            return launcher
                ? launcher.interactJson(JSON.stringify({ action: "expandSelected" }))
                : root.launcherError("expandSelected", "no_launcher", "No launcher instance available");
        }
        function collapseSelected(): string {
            const launcher = root.activeLauncher();
            return launcher
                ? launcher.interactJson(JSON.stringify({ action: "collapseSelected" }))
                : root.launcherError("collapseSelected", "no_launcher", "No launcher instance available");
        }
        function activateSelected(arg: string): string {
            let payload = { action: "activateSelected" };
            try { if (arg) payload = Object.assign(payload, JSON.parse(arg)); } catch (e) {}
            const launcher = root.activeLauncher();
            return launcher
                ? launcher.interactJson(JSON.stringify(payload))
                : root.launcherError("activateSelected", "no_launcher", "No launcher instance available");
        }

    }

    IpcHandler {
        target: IpcTargets.name("query")
        Component.onCompleted: { tracer.info("ipc-handler", function() { return { target: "query" }; }); }
        function pipeline(query: string): string {
            const state = root.instances[0];
            return state ? state.launcher.queryPipeline(query) : "{}";
        }
        function policies(query: string): string {
            const state = root.instances[0];
            return state ? state.launcher.queryPolicies(query) : "{}";
        }
        function benchmark(arg: string): string {
            const state = root.instances[0];
            return state ? state.launcher.debugBenchmark(arg) : "{}";
        }
        function benchmarkV2(arg: string): string {
            const state = root.instances[0];
            return state ? state.launcher.debugBenchmarkV2(arg) : "{}";
        }
        function cases(): string {
            const state = root.instances[0];
            return state ? state.launcher.queryCases() : "{}";
        }
        function runCases(): string {
            const state = root.instances[0];
            return state ? state.launcher.queryRunCases() : "{}";
        }
        function visual(query: string): string {
            const state = root.instances[0];
            return state ? state.launcher.queryVisual(query) : "{}";
        }
        function visualState(): string {
            const state = root.instances[0];
            return state ? state.launcher.queryVisualState() : "{}";
        }
        function visualApply(query: string): string {
            const state = root.instances[0];
            return state ? state.launcher.queryVisualApply(query) : "{}";
        }
        function visualDebug(enabled: string): string {
            const state = root.instances[0];
            return state ? state.launcher.queryVisualDebug(enabled) : "{}";
        }

        // Debug V2 IPC endpoints (canonical Evaluation-based)
        function debugOverview(args: string): string {
            const state = root.instances[0];
            return state ? state.launcher.debugOverview(args) : "{}";
        }
        function debugInspect(args: string): string {
            const state = root.instances[0];
            return state ? state.launcher.debugInspect(args) : "{}";
        }
        function debugPolicies(args: string): string {
            const state = root.instances[0];
            return state ? state.launcher.debugPolicies(args) : "{}";
        }
        function debugFind(args: string): string {
            const state = root.instances[0];
            return state ? state.launcher.debugFind(args) : "{}";
        }
        function debugAction(args: string): string {
            const state = root.instances[0];
            return state ? state.launcher.debugAction(args) : "{}";
        }
        function debugStats(args: string): string {
            const state = root.instances[0];
            return state ? state.launcher.debugStats(args) : "{}";
        }
        function debugRaw(args: string): string {
            const state = root.instances[0];
            return state ? state.launcher.debugRaw(args) : "{}";
        }
    }

    IpcHandler {
        target: IpcTargets.name("profiler")
        Component.onCompleted: { tracer.info("ipc-handler", function() { return { target: "profiler" }; }); }
        function handle(request: string): string {
            return JSON.stringify(ProfilerIpc.handle(JSON.parse(request)))
        }
    }

    IpcHandler {
        target: IpcTargets.name("logger")
        Component.onCompleted: { tracer.info("ipc-handler", function() { return { target: "logger" }; }); }
        function handle(request: string): string {
            return JSON.stringify(LoggerIpc.handle(JSON.parse(request)))
        }
    }

    function getScreenByName(screenName: string): ScreenState {
        return root.instances.find(screenState => screenState.screen.name === screenName);
    }

    function getScreenByRegex(screenRegex: string): list<ScreenState> {
        const regex = new RegExp(screenRegex);
        return root.instances.filter(screenState => regex.test(screenState.screen.name));
    }

    function activeScreenState() {
        const focused = root.instances.find(screenState =>
            Hyprland.focusedMonitor && Hyprland.focusedMonitor === Hyprland.monitorFor(screenState.screen)
        );
        return focused || (root.instances.length > 0 ? root.instances[0] : null);
    }

    function activeLauncher() {
        const ss = root.activeScreenState();
        return ss ? ss.launcher : null;
    }

    function launcherError(action, code, message) {
        return JSON.stringify({
            version: 1, type: "launcherInteraction", ok: false,
            action: action || "", before: null, after: null,
            result: null,
            error: { code: code, message: message }
        });
    }
}
