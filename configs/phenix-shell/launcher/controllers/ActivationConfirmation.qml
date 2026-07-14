import QtQuick
import QtQml
import qs.services

QtObject {
    readonly property var tracer: Logger.scope("launcher.confirm", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.confirm", { category: "launcher" })
    id: root

    property var controller: null
    property var pendingConfirmId: null
    property int pendingConfirmTimeoutMs: 1600

    property Timer pendingConfirmTimer: Timer {
        interval: root.pendingConfirmTimeoutMs
        onTriggered: root.pendingConfirmId = null
    }

    function requiresConfirm(activation) {
        return activation === "confirm" || activation === "confirm-and-explicit-prefix" || activation === "terminal-confirm-or-explicit-prefix";
    }

    function _checkActivation(result, executeCallback) {
        if (!result) {
            tracer.trace("checkActivation", function() { return { confirmed: true, reason: "no result" }; });
            return { confirmed: true };
        }

        if (result.risk && result.risk.activation) {
            if (result.id === root.pendingConfirmId) {
                tracer.info("checkActivation", function() { return { resultId: result.id, action: "confirmed", risk: result.risk.activation }; });
                root.pendingConfirmId = null;
                pendingConfirmTimer.stop();
                return { confirmed: true };
            }
            if (root.requiresConfirm(result.risk.activation)) {
                tracer.info("checkActivation", function() { return { resultId: result.id, action: "pendingConfirm", risk: result.risk.activation }; });
                root.pendingConfirmId = result.id;
                pendingConfirmTimer.restart();
                if (root.controller)
                    root.controller.resultsRefreshRequested();
                return { confirmed: false, needsConfirm: true };
            }
        }

        return { confirmed: true };
    }

    readonly property var checkActivation: prof.fn("checkActivation", _checkActivation)

    function activateWithConfirm(result, slotName) {
        var check = root.checkActivation(result);
        if (!check.confirmed)
            return { close: false, closeRequested: false, needsConfirm: check.needsConfirm };

        if (!root.controller)
            return { close: false };

        var recipeResult = root.controller.runRecipeSlot(slotName || "activate");
        return { close: recipeResult.close, closeRequested: recipeResult.close };
    }
}
