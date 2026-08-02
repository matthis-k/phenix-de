import QtQml
import qs.services

// Executes the finite launcher command algebra. This is deliberately a normal
// dependency owned by LauncherActionController, not a process-global registry.
QtObject {
    id: root

    required property var controller
    property var legacyIntentExecutor: null

    readonly property var tracer: Logger.scope("launcher.commandExecutor", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.commandExecutor", { category: "launcher" })

    function execute(rawCommand, target) {
        var command;
        try {
            command = CommandSpec.normalize(rawCommand);
        } catch (error) {
            root.tracer.error("parseFailed", function() { return { error: String(error) }; });
            return outcome(false, false, "invalid-command");
        }

        root.tracer.trace("execute", function() {
            return {
                kind: command.kind,
                targetId: target && (target.id || target.nodeId) || ""
            };
        });

        switch (command.kind) {
        case "activate":
            return activate(target, command.args);
        case "close":
            return outcome(true, true, "");
        case "edit-query":
            return editQuery(target, command.args);
        case "adjust-control":
            return adjustControl(target, command.args);
        case "set-control":
            return setControl(target, command.args);
        case "toggle-control":
            return activate(target, { prefer: ["toggle", "mute", "toggle-mute"] });
        case "noop":
            return outcome(true, false, "");
        default:
            return outcome(false, false, "unsupported-command");
        }
    }

    function executeRecipe(recipe, target) {
        var commands;
        try {
            commands = CommandSpec.normalizeRecipe(recipe);
        } catch (error) {
            root.tracer.error("recipeParseFailed", function() { return { error: String(error) }; });
            return outcome(false, false, "invalid-recipe");
        }

        var success = true;
        var error = "";
        for (var i = 0; i < commands.length; i += 1) {
            var result = root.execute(commands[i], target);
            if (!result.success) {
                success = false;
                error = result.error || error;
            }
            if (result.close)
                return outcome(success, true, error);
        }
        return outcome(success, false, error);
    }

    function activate(target, args) {
        if (!target)
            return outcome(false, false, "missing-target");

        var action = resolveAction(target, args || {});
        if (!action)
            return outcome(false, false, "missing-action");

        if (!canActivate(target, action))
            return outcome(false, false, "activation-blocked");

        try {
            if (action.intent) {
                if (!root.legacyIntentExecutor)
                    return outcome(false, false, "missing-legacy-intent-port");
                var intentResult = root.legacyIntentExecutor.applyIntent(target, action.intent);
                return outcome(intentResult !== false, !!intentResult, intentResult === false ? "legacy-intent-failed" : "");
            }

            var payload = action.payload || {};
            if (payload.service) {
                var serviceSuccess = dispatchServicePayload(payload, target);
                return outcome(serviceSuccess, false, serviceSuccess ? "" : "service-command-failed");
            }

            var backend = backendFor(target.source || target.backendId);
            if (!backend)
                return outcome(false, false, "backend-not-found");

            backend.activate(target, action);
            if (target.switchActions && root.controller && root.controller.actions)
                root.controller.actions.refreshSwitchResult(target, action);
            return outcome(true, false, "");
        } catch (error) {
            root.tracer.error("activationFailed", function() {
                return {
                    targetId: target.id || target.nodeId || "",
                    actionId: action.id || "",
                    error: String(error)
                };
            });
            return outcome(false, false, String(error));
        }
    }

    function editQuery(target, args) {
        var text = "";
        if (args.from === "metadata.replaceQuery" && target && target.metadata)
            text = target.metadata.replaceQuery || "";
        else if (args.text !== undefined)
            text = String(args.text);

        if (!text || !root.controller || typeof root.controller.queryReplacementRequested !== "function")
            return outcome(false, false, "missing-query-replacement");

        root.controller.queryReplacementRequested(text);
        return outcome(true, false, "");
    }

    function adjustControl(target, args) {
        var control = target && target.control;
        if (!control || control.kind !== "slider")
            return outcome(false, false, "missing-slider-control");

        var delta = Number(args.delta || 0);
        var step = Number(control.step || 1);
        switch (control.target) {
        case "brightness": {
            var brightness = alignedControlValue(Brightness.percent, delta, step, control.from || 0, control.to || 100);
            Brightness.setPercent(brightness);
            return outcome(true, false, "");
        }
        case "pipewire":
        case "audio": {
            var current = AudioService.volumePercentById(control.nodeId);
            if (current === null || current === undefined)
                return outcome(false, false, "audio-node-not-found");
            var volume = alignedControlValue(current, delta, step, control.from || 0, control.to || 150);
            return outcome(AudioService.setVolumeById(control.nodeId, volume), false, "audio-command-failed");
        }
        case "power-profile":
            PowerService.cycleProfile(delta * step);
            return outcome(true, false, "");
        default:
            return outcome(false, false, "unsupported-control-target");
        }
    }

    function setControl(target, args) {
        var control = target && target.control;
        if (!control)
            return outcome(false, false, "missing-control");

        var value = Number(args.value);
        switch (control.target) {
        case "brightness":
            Brightness.setPercent(value);
            return outcome(true, false, "");
        case "pipewire":
        case "audio":
            return outcome(AudioService.setVolumeById(control.nodeId, value), false, "audio-command-failed");
        case "power-profile":
            PowerService.setProfile(PowerService.profileFromIndex(value));
            return outcome(true, false, "");
        default:
            return outcome(false, false, "unsupported-control-target");
        }
    }

    function resolveAction(target, args) {
        if (args.action && args.action !== "default")
            return actionById(target, args.action) || { id: args.action };

        var preferred = args.prefer || [];
        for (var i = 0; i < preferred.length; i += 1) {
            var preferredAction = actionById(target, preferred[i]);
            if (preferredAction)
                return preferredAction;
        }

        var actions = target.actions || [];
        for (var ai = 0; ai < actions.length; ai += 1) {
            if (actions[ai] && actions[ai].default)
                return actions[ai];
        }
        return actions[0] || null;
    }

    function actionById(target, actionId) {
        if (target.switchActions && target.switchActions[actionId])
            return target.switchActions[actionId];
        var actions = target.actions || [];
        for (var i = 0; i < actions.length; i += 1) {
            if (actions[i] && actions[i].id === actionId)
                return actions[i];
        }
        return null;
    }

    function backendFor(id) {
        var backends = root.controller && root.controller.backends || [];
        for (var i = 0; i < backends.length; i += 1) {
            var backend = backends[i];
            var backendId = root.controller && typeof root.controller.backendId === "function"
                ? root.controller.backendId(backend)
                : backend && backend.backendId || "";
            if (backend && backendId === id)
                return backend;
        }
        return null;
    }

    function canActivate(target, action) {
        var risk = target.risk || action.risk || {};
        var node = {
            id: target.id || target.nodeId || "",
            label: target.title || target.label || "",
            risk: risk,
            dangerous: !!(target.dangerous || action.dangerous)
        };
        var query = root.controller && root.controller.query || "";
        var confirmed = !!(root.controller && root.controller.confirmationSatisfied);
        return ActivationGate.canActivate(node, action, root.controller, query, confirmed);
    }

    function dispatchServicePayload(payload, target) {
        switch (String(payload.service || "")) {
        case "brightness":
            return Brightness.executePayload ? Brightness.executePayload(payload) : false;
        case "audio":
            return AudioService.executePayload(payload);
        case "power":
            return PowerService.executePayload(payload);
        case "network":
            return NetworkService.executePayload(payload);
        case "vpn":
            return VpnService.executePayload(payload);
        case "bluetooth":
            return BluetoothService.executePayload(payload);
        case "notifications":
            return NotificationCenter.executePayload ? NotificationCenter.executePayload(payload) : false;
        case "session":
            return SessionController.executePayload(payload);
        default:
            return false;
        }
    }

    function alignedControlValue(current, delta, step, from, to) {
        var base = delta < 0 ? Math.floor(current / step) * step : Math.ceil(current / step) * step;
        if (Math.abs(base - current) < 0.0001)
            base += delta * step;
        return Math.max(from, Math.min(to, base));
    }

    function outcome(success, close, error) {
        return {
            success: success === true,
            close: close === true,
            error: error || ""
        };
    }
}
