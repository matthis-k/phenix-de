pragma Singleton
import QtQml
import Quickshell
import qs.services

// Screen-scoped command router for dynamically created preview windows.
// Windows register their concrete owner; callers address the capability by screen.
Singleton {
    readonly property var tracer: Logger.scope("hyprlandPreview.coordinator", { category: "shell" })
    property var _previews: ({})

    function screenKey(screen) {
        return screen && screen.name ? String(screen.name) : "";
    }

    function registerPreview(screen, preview) {
        var key = screenKey(screen);
        if (!key || !preview)
            return false;
        _previews[key] = preview;
        return true;
    }

    function unregisterPreview(screen, preview) {
        var key = screenKey(screen);
        if (!key || _previews[key] !== preview)
            return false;
        delete _previews[key];
        return true;
    }

    function previewFor(screen) {
        return _previews[screenKey(screen)] || null;
    }

    function showPreviewAtGlobal(screen, toplevel, x) {
        var preview = previewFor(screen);
        tracer.trace("showPreviewAtGlobal", function() {
            return { screen: screenKey(screen), x: x, available: !!preview };
        });
        if (!preview)
            return false;
        preview.showPreviewAtGlobal(toplevel, x);
        return true;
    }

    function addExternalHover(screen, delta) {
        var preview = previewFor(screen);
        if (!preview)
            return false;
        preview.externalHovers += delta;
        return true;
    }

    function clearPreview(screen) {
        var preview = previewFor(screen);
        if (!preview)
            return false;
        preview.clearPreview();
        return true;
    }
}
