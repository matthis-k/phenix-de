import QtQml
import Quickshell
import qs.services
import "../../logic/EvaluationProfiles.js" as EvalProfiles

QtObject {
    readonly property var tracer: Logger.scope("backend.actions.phenix", { category: "backend" })
    readonly property var prof: Profiler.scope("backend.actions.phenix", { category: "backend" })
    function isDevMode() { return Quickshell.env("PHENIX_DEV") === "1" || Quickshell.env("DEVMODE") === "1"; }
    function action(id, title, subtitle, icon, color, payload, extra) { return Object.assign({ id: id, title: title, subtitle: subtitle || "", icon: icon, iconColor: color, action: payload }, extra || {}); }
    function roots(context) { tracer.trace("roots", function() { return {}; }); return [{
        id: "phenix", aliases: ["phenix", "nx", "repo"], title: qsTr("Phenix"), icon: "nix-snowflake-symbolic",
        template: "flat-action-group", evaluationProfile: EvalProfiles.groupProfile({
            strategies: ["exact", "prefix", "compact", "substring", "acronym", "fuzzy", "semantic", "usage", "recency"],
            evidence: ["field-match", "switch-action", "semantic", "token-claim", "usage", "recency"]
        }),
        behavior: { filterChildren: true, presentation: "discoverable-command-group", displayPolicy: { discoverable: true, breadcrumbMode: "when-parent-dominates" } },
        children: [
            action("switch", qsTr("Switch System"), qsTr("Switch this system to the current flake"), "system-run-symbolic", Config.styling.primaryAccent, { service: "desktop", op: "terminal", pausedTitle: qsTr("phenix switch"), command: "phenix switch" }, { aliases: ["switch", "rebuild"], actionId: "phenix-switch", risk: { level: "privileged", activation: "confirm" } }),
            action("ai", qsTr("AI"), qsTr("Open Pi in the Phenix workspace"), "utilities-terminal-symbolic", Config.styling.secondaryAccent, { service: "desktop", op: "terminal", command: "phenix ai" }, { aliases: ["ai", "pi"], actionId: "phenix-ai" }),
            action("git", qsTr("Git"), qsTr("Open lazygit in the repo"), "git-symbolic", Config.styling.info, { service: "desktop", op: "terminal", command: "cd \"$PHENIX_FLAKE\" && lazygit" }, { aliases: ["git", "log", "lg", "lazygit"], actionId: "phenix-git" }),
            action("reload_shell", qsTr("Reload Shell"), qsTr("Restart the phenix-shell user service"), "view-refresh-symbolic", Config.styling.warning, { service: "desktop", op: "exec", command: ["phenix", "reload-shell"] }, { aliases: ["reload", "shell", "restart", "phenix-shell"], actionId: "phenix-reload-shell" }),
            { id: "devmode", aliases: ["dev", "devmode", "dev-mode"], title: qsTr("Dev Mode"), subtitle: qsTr("Switch between default and dev specialization"), icon: "applications-development-symbolic", iconColor: Config.styling.urgent, template: "switch", switchState: isDevMode(), switchActions: {
                toggle: { id: "toggle", title: qsTr("Toggle"), state: null, payload: { service: "desktop", op: "devmode" } },
                on: { id: "on", title: qsTr("On"), state: true, payload: { service: "desktop", op: "devmode", enabled: true } },
                off: { id: "off", title: qsTr("Off"), state: false, payload: { service: "desktop", op: "devmode", enabled: false } }
            } }
        ]
    }]; }
}
