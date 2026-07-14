import Quickshell
import qs.services
import "../logic/DebugLogger.js" as DebugLogger
import "../logic/EvaluationProfiles.js" as EvalProfiles

ModelTreeBackendBase {
    id: root

    readonly property var tracer: Logger.scope("backend.desktop", { category: "backend" })
    readonly property var prof: Profiler.scope("backend.desktop", { category: "backend" })

    category: qsTr("Applications")

    backendId: "desktop"
    name: qsTr("Desktop Applications")
    helpTitle: qsTr("Applications")
    helpDescription: qsTr("Search desktop entries")
    helpIcon: "application-x-executable"
    helpPrefixes: ["@app", "@apps", "@desktop"]
    priority: 80
    maxResults: 6
    routes: [
        { prefix: "@app", priority: 80, combine: "exclusive", afterEmpty: "fallthrough" },
        { prefix: "@apps", priority: 80, combine: "exclusive", afterEmpty: "fallthrough" },
        { prefix: "@desktop", priority: 80, combine: "exclusive", afterEmpty: "fallthrough" },
        { priority: 0, combine: "shared", afterEmpty: "stop" }
    ]

    treeRoots: appTree

    readonly property var appTree: buildAppTree()

    readonly property var fixtureApps: TestMode.isActive ? loadFixtureApps() : []

    function loadFixtureApps() {
        var path = TestMode.fixturePath("DESKTOP");
        var data = TestMode.loadFixtureSync(path);
        if (!data) return [];
        return data.map(function(f) { return {
            id: f.desktopName || (f.name ? f.name.toLowerCase().replace(/[\s-]/g, "_") + ".desktop" : "unknown.desktop"),
            name: f.name || f.id || "",
            genericName: null,
            comment: null,
            icon: f.icon || "application-x-executable",
            actions: f.actions || [],
            noDisplay: false,
            categories: f.categories || [],
            command: f.executable ? [f.executable] : []
        };});
    }

    function appProfile() { return EvalProfiles.appProfile(); }
    function visualRootProfile() { return EvalProfiles.visualRootProfile(); }

    function debugLog(category, message, data) {
        if (root.controller && root.controller.debugEnabled)
            DebugLogger.log(category, message, data);
    }

    function skipEntry(entry) {
        if (entry.noDisplay || !entry.name)
            return true;
        const cats = (entry.categories || []).map(c => c.toLowerCase());
        if (cats.indexOf("consoleonly") >= 0 || cats.indexOf("screensaver") >= 0)
            return true;
        return false;
    }

    function buildAppTree() {
        const entries = TestMode.isActive ? root.fixtureApps : (DesktopEntries.applications.values || []);
        tracer.debug("buildAppTree", function() { return { entryCount: entries ? entries.length : 0, testMode: TestMode.isActive }; });
        const children = [];
        for (const entry of entries) {
            if (skipEntry(entry))
                continue;
            children.push(entryNode(entry));
        }
        return [{
            id: "apps",
            title: qsTr("Applications"),
            subtitle: qsTr("%1 apps").arg(children.length),
            icon: "application-x-executable",
            result: false,
            behavior: { visualRoot: true },
            evaluationProfile: visualRootProfile(),
            children: children
        }];
    }

    function entryNode(entry) {
        const rawActions = entry.actions;
        const actions = [];
        if (rawActions) {
            for (var ai = 0; ai < rawActions.length; ai += 1) {
                if (rawActions[ai] && rawActions[ai].id)
                    actions.push(rawActions[ai]);
            }
        }
        const base = {
            id: entry.id.replace(/\.desktop$/, "").toLowerCase().replace(/[\s-]/g, "_"),
            title: entry.name,
            subtitle: entry.genericName || entry.comment || null,
            icon: entry.icon || "application-x-executable",
            action: { actionId: "open", entryId: entry.id },
            evaluationProfile: appProfile(),
            behavior: { filterChildren: true, depthPenalty: 0.35 }
        };
        if (actions.length > 0) {
            base.children = actions.map(a => ({
                id: a.id,
                title: a.name || a.id,
                subtitle: entry.name,
                icon: a.icon || entry.icon || "application-x-executable",
                action: { entryId: entry.id, actionId: a.id }
            }));
        }
        return base;
    }

    function activate(result, action) {
        tracer.info("activate", function() { return { resultId: result ? result.id : null, entryId: result ? result.metadata?.desktopEntry : null, testMode: TestMode.isActive }; });
        if (TestMode.isActive) {
            root.debugLog("desktop-launch", "Test mode: skipping desktop activation", {
                resultId: result ? result.id : null
            });
            return;
        }
        const metadata = result ? result.metadata || {} : {};
        const cmdAction = (action && action.payload) || (metadata.action && metadata.action.payload) || metadata.action || {};
        const entryId = metadata.desktopEntry || cmdAction.entryId;
        const entry = entryId ? DesktopEntries.byId(entryId) : null;
        if (!entry) {
            root.debugLog("desktop-launch", "Desktop entry not found", {
                resultId: result ? result.id : null,
                entryId: entryId || null,
                actionId: cmdAction.actionId || null
            });
            return;
        }

        const actionId = cmdAction.actionId || (action ? action.id : null);
        root.debugLog("desktop-launch", "Activating desktop entry", {
            resultId: result ? result.id : null,
            entryId: entry.id,
            name: entry.name || null,
            actionId: actionId || "open",
            command: entry.command || [],
            workingDirectory: entry.workingDirectory || "",
            runInTerminal: !!entry.runInTerminal
        });
        if (!actionId || actionId === "open" || actionId === "run") {
            launchDesktopCommand(entry.command, entry.workingDirectory, entry.runInTerminal);
            return;
        }

        var desktopAction = null;
        var availableActionIds = [];
        if (entry.actions) {
            for (var ai = 0; ai < entry.actions.length; ai += 1) {
                var act = entry.actions[ai];
                if (act) {
                    availableActionIds.push(act.id || "");
                    if (act.id === actionId)
                        desktopAction = act;
                }
            }
        }
        if (desktopAction) {
            root.debugLog("desktop-launch", "Activating desktop action", {
                entryId: entry.id,
                actionId: actionId,
                command: desktopAction.command || []
            });
            launchDesktopCommand(desktopAction.command, entry.workingDirectory, entry.runInTerminal);
        } else {
            root.debugLog("desktop-launch", "Desktop action not found", {
                entryId: entry.id,
                actionId: actionId,
                availableActions: availableActionIds
            });
        }
    }

    function launchDesktopCommand(command, workingDirectory, runInTerminal) {
        tracer.debug("launchDesktopCommand", function() { return { commandLen: command ? command.length : 0, workingDir: workingDirectory || "", runInTerminal: runInTerminal }; });
        if (!command || command.length === 0) {
            root.debugLog("desktop-launch", "Empty desktop command", {});
            return;
        }

        const launchCommand = stripDesktopFieldCodes(command);
        if (launchCommand.length === 0) {
            root.debugLog("desktop-launch", "Desktop command only contained field codes", {
                originalCommand: command || []
            });
            return;
        }

        if (runInTerminal) {
            const terminalCommand = ["systemd-run", "--user", "--scope", "--collect", "--same-dir", "--", "setsid", "sh", "-lc", "exec \"${TERMINAL:-kitty}\" -e \"$@\"", "launcher-terminal"].concat(launchCommand);
            root.debugLog("desktop-launch", "Executing terminal desktop command", {
                originalCommand: command,
                launchCommand: launchCommand,
                systemdCommand: terminalCommand,
                workingDirectory: workingDirectory || ""
            });
            Quickshell.execDetached({
                command: terminalCommand,
                workingDirectory: workingDirectory || ""
            });
            return;
        }

        const systemdCommand = ["systemd-run", "--user", "--scope", "--collect", "--same-dir", "--"].concat(launchCommand);
        root.debugLog("desktop-launch", "Executing desktop command", {
            originalCommand: command,
            launchCommand: launchCommand,
            systemdCommand: systemdCommand,
            workingDirectory: workingDirectory || ""
        });
        Quickshell.execDetached({
            command: systemdCommand,
            workingDirectory: workingDirectory || ""
        });
    }

    function stripDesktopFieldCodes(command) {
        return (command || []).filter(arg => !/^%[fFuUdDnNickvm]$/.test(arg || ""));
    }
}
