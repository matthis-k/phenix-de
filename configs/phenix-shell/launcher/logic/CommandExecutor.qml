import QtQml
import qs.services

// Executes the finite launcher command algebra against narrow injected ports.
QtObject {
    id: root

    required property var runtime
    required property var controlPort
    required property var serviceCommands
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
                var serviceSuccess = root.serviceCommands.execute(payload);
                return outcome(serviceSuccess, false, serviceSuccess ? "" : "service-command-failed");
            }

            var backend = root.runtime.backendFor(target.source || target.backendId);
            if (!backend)
                return outcome(false, false, "backend-not-found");

            if (!backend.activate(target, action))
                return outcome(false, false, "backend-activation-unsupported");
            if (target.switchActions)
                root.runtime.refreshSwitchResult(target, action);
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

        if (!text || !root.runtime.replaceQuery(text))
            return outcome(false, false, "missing-query-replacement");
        return outcome(true, false, "");
    }

    function adjustControl(target, args) {
        var control = target && target.control;
        if (!control || control.kind !== "slider")
            return outcome(false, false, "missing-slider-control");
        var success = root.controlPort.adjust(control, Number(args.delta || 0));
        return outcome(success, false, success ? "" : "control-command-failed");
    }

    function setControl(target, args) {
        var control = target && target.control;
        if (!control)
            return outcome(false, false, "missing-control");
        var success = root.controlPort.setValue(control, Number(args.value));
        return outcome(success, false, success ? "" : "control-command-failed");
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

    function canActivate(target, action) {
        var risk = target.risk || action.risk || {};
        var node = {
            id: target.id || target.nodeId || "",
            label: target.title || target.label || "",
            risk: risk,
            dangerous: !!(target.dangerous || action.dangerous)
        };
        return ActivationGate.canActivate(
            node,
            action,
            root.runtime.activationContext(),
            root.runtime.query,
            root.runtime.confirmationSatisfied
        );
    }

    function outcome(success, close, error) {
        return {
            success: success === true,
            close: close === true,
            error: error || ""
        };
    }
}
