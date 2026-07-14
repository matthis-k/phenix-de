import QtQml
import Quickshell
import qs.services
import "actions" as Actions
import "../logic/EvaluationProfiles.js" as EvalProfiles

TreeBackendBase {
    id: root

    readonly property var tracer: Logger.scope("backend.desktopActions", { category: "backend" })
    readonly property var prof: Profiler.scope("backend.desktopActions", { category: "backend" })

    property var shellScreenState: null
    category: qsTr("Desktop Actions")
    backendId: "desktop-actions"
    name: qsTr("Desktop Actions")
    helpDescription: qsTr("Run networking, session, system, and dashboard actions")
    helpIcon: "system-run"
    helpPrefixes: [":"]
    priority: 120
    maxResults: 8
    dynamicCompositeRoot: false
    routes: [
        { prefix: ":", priority: 120, combine: "exclusive", afterEmpty: "fallthrough" },
        { priority: 0, combine: "shared", afterEmpty: "stop" }
    ]

    property QtObject phenixActions: Actions.PhenixActions {}
    property QtObject sessionActions: Actions.SessionActions {}
    property QtObject screenshotActions: Actions.ScreenshotActions {}
    property QtObject dashboardActions: Actions.DashboardActions { shellScreenState: root.shellScreenState }
    property QtObject networkActions: Actions.NetworkActions {}
    property QtObject audioActions: Actions.AudioActions {}
    property QtObject powerActions: Actions.PowerActions {}
    property QtObject notificationActions: Actions.NotificationActions {}

    Connections { target: AudioService; function on_RevisionChanged() { root.invalidateCompositeRootCache(); } }
    Connections { target: VpnService; function onConnectedChanged() { root.invalidateCompositeRootCache(); } function onConnectingChanged() { root.invalidateCompositeRootCache(); } }
    Connections { target: BluetoothService; function on_RevisionChanged() { root.invalidateCompositeRootCache(); } }
    Connections { target: PowerService; function onProfileChanged() { root.invalidateCompositeRootCache(); } }
    Connections { target: NotificationCenter; function onDoNotDisturbEnabledChanged() { root.invalidateCompositeRootCache(); } function onHasCriticalChanged() { root.invalidateCompositeRootCache(); } }
    Connections { target: NetworkService; function onWifiEnabledChanged() { root.invalidateCompositeRootCache(); } function onWifiHardwareEnabledChanged() { root.invalidateCompositeRootCache(); } function onConnectedSsidChanged() { root.invalidateCompositeRootCache(); } function onHasWiredConnectionChanged() { root.invalidateCompositeRootCache(); } function onConnectedNetworkChanged() { root.invalidateCompositeRootCache(); } }

    function fixtureProfile() { return EvalProfiles.groupProfile(); }

    readonly property var fixtureTree: TestMode.isActive ? buildFixtureTree() : null

    function fixtureVpnProfile() { return EvalProfiles.switchProfile(); }

    function buildFixtureTree() {
        var path = TestMode.fixturePath("ACTIONS");
        var entries = TestMode.loadFixtureSync(path);
        if (!entries || entries.length === 0) return [];

        var groupBehaviors = {
            "Audio": { filterChildren: true, selectable: false }
        };

        var groups = {};
        var vpnDestinations = [];
        var vpnSwitchActions = {};
        for (var i = 0; i < entries.length; i++) {
            var entry = entries[i];
            var p = entry.path || [];
            if (p.length < 3) continue;

            var groupName = p[1];
            var itemName = p[p.length - 1];

            if (entry.type === "vpn-destination") {
                vpnDestinations.push({
                    id: entry.id,
                    aliases: [itemName.toLowerCase()],
                    title: itemName,
                    executable: true,
                    action: { service: "vpn", op: "connect", destination: entry.destinationValue }
                });
                continue;
            }

            var isSwitch = entry.type === "switch";

            if (!groups[groupName]) {
                var safeId = groupName.toLowerCase().replace(/[\s-]/g, "_");
                groups[groupName] = {
                    id: safeId,
                    aliases: [groupName.toLowerCase()],
                    title: groupName,
                    template: "flat-action-group",
                    behavior: groupBehaviors[groupName] || { filterChildren: true, selectable: true },
                    evaluationProfile: root.fixtureProfile(),
                    children: {}
                };
            }

            var itemKey = entry.type === "vpn-destination" ? "vpn" : itemName.toLowerCase().replace(/[\s-]/g, "_");
            if (entry.type !== "vpn-destination" && !groups[groupName].children[itemKey]) {
                groups[groupName].children[itemKey] = root.fixtureItemNode(entry, itemName, groupName);
            }

            if (isSwitch) {
                var actionKey = entry.id || entry.title.toLowerCase().replace(/[\s-]/g, "_");
                if (!vpnSwitchActions[actionKey]) {
                    vpnSwitchActions[actionKey] = {
                        id: actionKey,
                        title: entry.title,
                        state: entry.state !== undefined ? entry.state : null,
                        payload: { service: "test", op: "noop" }
                    };
                }
                var item = groups[groupName].children[itemKey];
                if (item) {
                    if (!item.switchActions) item.switchActions = {};
                    item.switchActions[entry.group || actionKey] = vpnSwitchActions[actionKey];
                }
            }
        }

        // Build VPN switch node with destinations as children
        if (vpnSwitchActions && Object.keys(vpnSwitchActions).length > 0) {
            var vpnNode = {
                id: "networking_vpn",
                aliases: ["vpn", "connect to"],
                title: "VPN",
                template: "switch",
                switchState: false,
                behavior: { filterChildren: true, depthPenalty: 1, exploration: { descend: false } },
                evaluationProfile: root.fixtureVpnProfile(),
                switchActions: vpnSwitchActions,
                children: vpnDestinations
            };
            if (groups["Networking"]) {
                groups["Networking"].children["vpn"] = vpnNode;
            }
        }

        var result = [];
        var groupOrder = ["Phenix", "Session", "Networking", "Audio", "Power", "Notifications"];
        var sorted = Object.keys(groups).sort(function(a, b) {
            var ai = groupOrder.indexOf(a);
            var bi = groupOrder.indexOf(b);
            return (ai >= 0 ? ai : 99) - (bi >= 0 ? bi : 99);
        });
        for (var gi = 0; gi < sorted.length; gi++) {
            var g = groups[sorted[gi]];
            var children = [];
            var itemKeys = Object.keys(g.children);
            itemKeys.sort();
            for (var ci = 0; ci < itemKeys.length; ci++) {
                children.push(g.children[itemKeys[ci]]);
            }
            g.children = children;
            result.push(g);
        }
        return result;
    }

    function fixtureItemNode(entry, itemName, groupName) {
        var safeGroup = groupName.toLowerCase().replace(/[\s-]/g, "_");
        var safeItem = itemName.toLowerCase().replace(/[\s-]/g, "_");
        var node = {
            id: safeGroup + "." + safeItem,
            aliases: [itemName.toLowerCase()],
            title: itemName,
            behavior: { filterChildren: true },
            executable: true,
            hasAction: true
        };

        if (entry.type === "switch") {
            node.template = "switch";
            node.switchActions = {};
            node.switchState = entry.state !== undefined ? entry.state : false;
        } else {
            node.action = { service: "test", op: "noop" };
            if (entry.risk) {
                node.risk = entry.risk;
                node.dangerous = true;
            }
            if (entry.semantics) {
                node.semantics = entry.semantics;
            }
        }
        return node;
    }

    function effectiveTreeRoots() {
        tracer.debug("effectiveTreeRoots", function() { return { testMode: TestMode.isActive, fixtureTree: !!(TestMode.isActive && root.fixtureTree) }; });
        if (TestMode.isActive && root.fixtureTree)
            return root.fixtureTree;

        return [].concat(
            phenixActions.roots({}),
            sessionActions.roots({}),
            screenshotActions.roots({}),
            dashboardActions.roots({ shellScreenState: root.shellScreenState }),
            networkActions.roots({}),
            audioActions.roots({}),
            powerActions.roots({}),
            notificationActions.roots({})
        ).filter(Boolean);
    }

    function activate(result, action) {
        tracer.info("activate", function() { return { resultId: result ? result.id : null, service: action ? action.payload?.service : null, testMode: TestMode.isActive }; });
        if (TestMode.isActive)
            return;

        var payload = action && action.payload || {};
        if (!payload.service)
            return;

        switch (payload.service) {
        case "desktop":
            runDesktopPayload(payload);
            break;
        case "dashboard":
            if (root.shellScreenState)
                root.shellScreenState.openDashboard(payload.tab || "overview");
            break;
        }
    }

    function runDesktopPayload(payload) {
        if (payload.op === "exec" && payload.command) {
            Quickshell.execDetached({ command: payload.command });
        } else if (payload.op === "terminal") {
            if (payload.pausedTitle)
                launchTerminalPaused(payload.pausedTitle, payload.command || "");
            else
                launchTerminal(payload.command || "");
        } else if (payload.op === "devmode") {
            var enabled = payload.enabled === null || payload.enabled === undefined ? !(Quickshell.env("PHENIX_DEV") === "1" || Quickshell.env("DEVMODE") === "1") : !!payload.enabled;
            if (enabled)
                launchTerminalPaused(qsTr("Enable dev mode"), "if [ -x /run/current-system/specialisation/dev/bin/switch-to-configuration ]; then sudo /run/current-system/specialisation/dev/bin/switch-to-configuration test; else printf '%s\\n' 'dev specialization is not available'; exit 1; fi");
            else
                launchTerminalPaused(qsTr("Disable dev mode"), "sudo /run/current-system/bin/switch-to-configuration test");
        }
    }

    function launchTerminal(command) {
        Quickshell.execDetached({ command: ["systemd-run", "--user", "--scope", "--collect", "--same-dir", "--", "setsid", "sh", "-lc", "exec \"${TERMINAL:-kitty}\" -e sh -lc \"$1\"", "launcher-terminal", command] });
    }

    function launchTerminalPaused(title, command) {
        var script = "printf '%s\\n\\n' " + shellQuote(title) + "; " + command + "; status=$?; printf '\\nPress Enter to close...'; read -r _; exit $status";
        launchTerminal(script);
    }

    function shellQuote(text) {
        return "'" + String(text || "").replace(/'/g, "'\\''") + "'";
    }
}
