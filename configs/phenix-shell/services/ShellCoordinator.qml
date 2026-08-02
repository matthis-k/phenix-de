pragma Singleton
import QtQml
import Quickshell
import qs.services

// Direct command owner for shell interactions. Callers receive one coordinator
// instead of broadcasting imperative requests through a process-global event bus.
Singleton {
    readonly property var tracer: Logger.scope("shell.coordinator", { category: "shell" })
    readonly property var prof: Profiler.scope("shell.coordinator", { category: "shell" })

    function screenState(screen) {
        return screen ? ShellState.getScreenByName(screen.name) : null;
    }

    function requestHyprlandPreview(screen, toplevel, x) {
        var state = screenState(screen);
        tracer.trace("requestHyprlandPreview", function() {
            return { screen: screen ? screen.name : "", x: x, available: !!state };
        });
        if (!state || !state.hyprlandPreview)
            return false;
        state.hyprlandPreview.showPreviewAtGlobal(toplevel, x);
        return true;
    }

    function addHyprlandPreviewHover(screen, delta) {
        var state = screenState(screen);
        if (!state || !state.hyprlandPreview)
            return false;
        state.hyprlandPreview.externalHovers += delta;
        return true;
    }

    function clearHyprlandPreview(screen) {
        var state = screenState(screen);
        if (!state || !state.hyprlandPreview)
            return false;
        state.hyprlandPreview.clearPreview();
        return true;
    }

    function openLauncher(arg) {
        var state = ShellState.activeScreenState();
        if (!state || !state.launcher)
            return false;
        state.launcher.open(arg);
        return true;
    }

    function closeLauncher() {
        var state = ShellState.activeScreenState();
        if (!state || !state.launcher)
            return false;
        state.launcher.close();
        return true;
    }

    function openDashboard(tab) {
        var state = ShellState.activeScreenState();
        if (!state)
            return false;
        state.openDashboard(tab);
        return true;
    }

    function toggleDashboard(tab) {
        var state = ShellState.activeScreenState();
        if (!state)
            return false;
        state.toggleDashboard(tab);
        return true;
    }
}
