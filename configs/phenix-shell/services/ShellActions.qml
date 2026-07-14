pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import qs.services

Singleton {
    id: root

    readonly property var tracer: Logger.scope("shellActions", { category: "shell" })
    readonly property var prof: Profiler.scope("shellActions", { category: "shell" })

    signal launcherOpenRequested(var arg)
    signal launcherCloseRequested()
    signal dashboardOpenRequested(string tab)
    signal dashboardToggleRequested(string tab)

    signal hyprlandPreviewRequested(var screen, var toplevel, real x)
    signal hyprlandPreviewHoverDelta(var screen, int delta)

    signal notificationRequested(var payload)

    function openLauncher(arg: var): void {
        root.tracer.trace("openLauncher", function() { return { arg: String(arg) } });
        launcherOpenRequested(arg);
    }

    function closeLauncher(): void {
        root.tracer.trace("closeLauncher");
        launcherCloseRequested();
    }

    function openDashboard(tab: string): void {
        root.tracer.trace("openDashboard", function() { return { tab: tab } });
        dashboardOpenRequested(tab);
    }

    function toggleDashboard(tab: string): void {
        root.tracer.trace("toggleDashboard", function() { return { tab: tab } });
        dashboardToggleRequested(tab);
    }

    function requestHyprlandPreview(screen: var, toplevel: var, x: real): void {
        root.tracer.trace("requestHyprlandPreview", function() { return { screen: String(screen), x: x } });
        hyprlandPreviewRequested(screen, toplevel, x);
    }

    function addHyprlandPreviewHover(screen: var, delta: int): void {
        root.tracer.trace("addHyprlandPreviewHover", function() { return { screen: String(screen), delta: delta } });
        hyprlandPreviewHoverDelta(screen, delta);
    }

    function notify(payload: var): void {
        root.tracer.trace("notify", function() { return { type: typeof payload } });
        notificationRequested(payload);
    }
}
