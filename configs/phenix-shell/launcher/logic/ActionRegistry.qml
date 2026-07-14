pragma Singleton
import QtQml
import Quickshell
import qs.services
import "ActivationGate.qml"
import "DebugLogger.js" as DebugLogger

Singleton {
    readonly property var tracer: Logger.scope("launcher.actionRegistry", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.actionRegistry", { category: "launcher" })

    property var _executors: ({})
    property bool debugEnabled: false

    function register(name, executor) {
        _executors[name] = executor;
    }

    function isTestMode() {
        return Quickshell.env("NEWSHELL_TEST_MODE") === "1";
    }

    function isDestructiveStep(step) {
        if (!step) return false;
        var name = String(step.name || "").toLowerCase();
        var args = step.args || {};
        return name === "shutdown" || name === "reboot" || name === "logout" ||
            name === "power-off" || name === "hibernate" || name === "suspend" ||
            args.service === "session" || String(args.op || "").match(/^(shutdown|reboot|logout|power-off|hibernate|suspend)$/);
    }

    function execute(step, target, controller) {
        step = ActionSpec.normalize(step);
        var name = step.name || "";
        var args = step.args || {};
        tracer.trace("execute", function() { return { name: name, targetId: target?.id || target?.nodeId || "" }; });
        var executor = _executors[name];

        if (!executor) {
            if (debugEnabled)
                console.warn("[ActionRegistry] no executor for step: " + name);
            return { close: false, success: false };
        }

        if (isTestMode() && isDestructiveStep(step)) {
            if (debugEnabled)
                console.log("[ActionRegistry] dry-run in test mode for step: " + name);
            return { close: false, success: true, dryRun: true, step: name, reason: "NEWSHELL_TEST_MODE" };
        }

        try {
            var result = executor(target, args, controller);
            if (result === true || (result && result.close))
                return { close: true, success: true };
            if (result === false)
                return { close: false, success: false };
            if (result && typeof result === "object")
                return { close: !!result.close, success: result.success !== false };
            return { close: false, success: true };
        } catch (e) {
            if (debugEnabled)
                console.warn("[ActionRegistry] executor error for " + name + ": " + e);
            return { close: false, success: false };
        }
    }

    function executeRecipe(recipe, target, controller) {
        if (!recipe || !Array.isArray(recipe))
            return { close: false, success: false };

        var success = true;
        for (var i = 0; i < recipe.length; i += 1) {
            var step = recipe[i];
            var result = execute(step, target, controller);
            if (!result.success)
                success = false;
            if (result.close)
                return { close: true, success: success };
        }
        return { close: false, success: success };
    }

    function _resolveActionFromArgs(target, args) {
        if (args.action && args.action !== "default") {
            var actionId = args.action;

            if (target.switchActions && target.switchActions[actionId])
                return target.switchActions[actionId];

            var actions = target.actions || [];
            for (var i = 0; i < actions.length; i += 1) {
                if (actions[i].id === actionId)
                    return actions[i];
            }
            return { id: actionId };
        }

        if (args.prefer && Array.isArray(args.prefer)) {
            for (var pi = 0; pi < args.prefer.length; pi += 1) {
                var pid = args.prefer[pi];
                if (target.switchActions && target.switchActions[pid])
                    return target.switchActions[pid];
                var targetActions = target.actions || [];
                for (var ai = 0; ai < targetActions.length; ai += 1) {
                    if (targetActions[ai].id === pid)
                        return targetActions[ai];
                }
            }
        }

        var actions = target.actions || [];
        var defaultAction = actions.find(function(a) { return a.default; }) || actions[0] || null;
        return defaultAction;
    }

    function _runAction(target, action, controller) {
        if (!target || !action)
            return { close: false, success: false };

        tracer.debug("_runAction", function() { return { targetId: target.id || target.nodeId || "", actionId: action.id || "" }; });
        try {
            if (!_targetCanActivate(target, action, controller)) {
                if (debugEnabled)
                    DebugLogger.log("action", "activation blocked by risk gate", { targetId: target.id || target.nodeId || "", actionId: action.id || "" });
                return { close: false, success: false };
            }

            if (action.intent) {
                var legacyResult = controller._legacyApplyIntent(target, action.intent);
                return { close: !!legacyResult, success: true };
            }

            var payload = action.payload || {};
            if (payload && payload.service) {
                var dispatched = dispatchServicePayload(payload, target, controller);
                if (dispatched)
                    return { close: false, success: true };
            }

            var backend = null;
            for (var i = 0; i < (controller.backends || []).length; i += 1) {
                if (controller.backends[i] && controller.backendId(controller.backends[i]) === target.source) {
                    backend = controller.backends[i];
                    break;
                }
            }
            if (!backend)
                return { close: false, success: false };

            backend.activate(target, action);
            if (debugEnabled)
                DebugLogger.log("action", "run-action activated", {
                    targetId: target.id || target.nodeId || "",
                    actionId: action.id || ""
                });
            if (target.switchActions)
                controller.refreshSwitchResult(target, action);
            return { close: false, success: true };
        } catch (e) {
            if (debugEnabled)
                DebugLogger.log("action", "run-action failed: " + e, {});
            return { close: false, success: false };
        }
    }

    function _targetCanActivate(target, action, controller) {
        var nodeRisk = target.risk || (action && action.risk) || {};
        var nodeForGate = {
            id: target.id || target.nodeId || "",
            label: target.title || target.label || "",
            risk: nodeRisk,
            dangerous: !!(target.dangerous || (action && action.dangerous))
        };
        var queryText = (controller && controller.query) || "";
        var confirmed = !!(controller && controller.confirmationSatisfied);
        return ActivationGate.canActivate(nodeForGate, action, controller, queryText, confirmed);
    }

    function alignedControlValue(current, delta, step, from, to) {
        var base = delta < 0 ? Math.floor(current / step) * step : Math.ceil(current / step) * step;
        if (Math.abs(base - current) < 0.0001)
            base += delta * step;
        return Math.max(from, Math.min(to, base));
    }

    function dispatchServicePayload(payload, target, controller) {
        if (!payload || !payload.service)
            return false;

        switch (String(payload.service)) {
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
        default:
            return false;
        }
    }

    function _buildExecutors() {
        register("run-action", function(target, args, controller) {
            if (!target)
                return { close: false, success: false };

            var action = _resolveActionFromArgs(target, args);
            if (!action)
                return { close: false, success: false };

            return _runAction(target, action, controller);
        });

        register("close", function(target, args, controller) {
            return { close: true, success: true };
        });

        register("edit-query", function(target, args, controller) {
            var mode = args.mode || "replace";
            var text = "";

            if (args.from === "metadata.replaceQuery" && target.metadata && target.metadata.replaceQuery)
                text = target.metadata.replaceQuery;
            else if (args.text !== undefined)
                text = String(args.text);

            if (text && typeof controller.queryReplacementRequested === "function")
                controller.queryReplacementRequested(text);

            return { close: false, success: true };
        });

        register("adjust-control", function(target, args, controller) {
            if (!target || !target.control || target.control.kind !== "slider")
                return { close: false, success: false };

            var delta = Number(args.delta) || 0;
            var control = target.control;
            var step = control.step || 5;

            if (control.target === "brightness") {
                var aligned = alignedControlValue(Brightness.percent, delta, step, control.from || 0, control.to || 100);
                Brightness.setPercent(aligned);
                return { close: false, success: true };
            }

            if (control.target === "pipewire" || control.target === "audio") {
                var current = AudioService.volumePercentById(control.nodeId);
                if (current === null || current === undefined)
                    return { close: false, success: false };
                var next = alignedControlValue(current, delta, step, control.from || 0, control.to || 150);
                AudioService.setVolumeById(control.nodeId, next);
                return { close: false, success: true };
            }

            if (control.target === "power-profile") {
                PowerService.cycleProfile(delta * (control.step || 1));
                return { close: false, success: true };
            }

            return { close: false, success: false };
        });

        register("set-control", function(target, args, controller) {
            if (!target || !target.control)
                return { close: false, success: false };
            var control = target.control;
            var value = Number(args.value);
            if (control.target === "brightness") {
                Brightness.setPercent(value);
                return { close: false, success: true };
            }
            if (control.target === "pipewire" || control.target === "audio") {
                AudioService.setVolumeById(control.nodeId, value);
                return { close: false, success: true };
            }
            if (control.target === "power-profile") {
                PowerService.setProfile(PowerService.profileFromIndex(value));
                return { close: false, success: true };
            }
            return { close: false, success: false };
        });

        register("toggle", function(target, args, controller) {
            return _runAction(target, _resolveActionFromArgs(target, { prefer: ["toggle", "mute", "toggle-mute"] }), controller);
        });

        register("noop", function(target, args, controller) {
            return { close: false, success: true };
        });
    }

    Component.onCompleted: _buildExecutors()
}
