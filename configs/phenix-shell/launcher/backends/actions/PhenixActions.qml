import QtQml
import Quickshell
import qs.services
import "../../logic/EvaluationProfiles.js" as EvalProfiles

QtObject {
    readonly property var tracer: Logger.scope("backend.actions.phenix", { category: "backend" })
    readonly property var prof: Profiler.scope("backend.actions.phenix", { category: "backend" })

    function isDevMode() {
        return Quickshell.env("PHENIX_DEV") === "1" || Quickshell.env("DEVMODE") === "1";
    }

    function action(id, title, subtitle, icon, color, payload, extra) {
        var options = Object.assign({}, extra || {});
        var aliases = options.aliases || [];
        delete options.aliases;
        return Object.assign({
            id: id,
            display: {
                title: title,
                subtitle: subtitle || "",
                icon: icon,
                iconColor: color
            },
            match: { aliases: aliases },
            action: payload
        }, options);
    }

    function roots(context) {
        tracer.trace("roots", function() { return {}; });
        return [{
            id: "phenix",
            display: {
                title: qsTr("Phenix"),
                icon: "nix-snowflake-symbolic"
            },
            match: {
                aliases: ["phenix", "nx", "repo"],
                evaluationProfile: EvalProfiles.groupProfile({
                    strategies: ["exact", "prefix", "compact", "substring", "acronym", "fuzzy", "semantic", "usage", "recency"],
                    evidence: ["field-match", "switch-action", "semantic", "token-claim", "usage", "recency"]
                })
            },
            template: "flat-action-group",
            behavior: {
                filterChildren: true,
                presentation: "discoverable-command-group",
                displayPolicy: { discoverable: true, breadcrumbMode: "when-parent-dominates" }
            },
            children: [
                action("switch", qsTr("Switch System"), qsTr("Switch this system to the current flake"), "system-run-symbolic", Config.styling.primaryAccent, { service: "desktop", op: "terminal", pausedTitle: qsTr("phenix switch"), command: "phenix switch" }, { actionId: "phenix-switch", aliases: ["switch", "rebuild"], risk: { level: "privileged", activation: "confirm" } }),
                action("ai", qsTr("AI"), qsTr("Open Pi in the Phenix workspace"), "utilities-terminal-symbolic", Config.styling.secondaryAccent, { service: "desktop", op: "terminal", command: "phenix ai" }, { actionId: "phenix-ai", aliases: ["ai", "pi"] }),
                action("git", qsTr("Git"), qsTr("Open lazygit in the repo"), "git-symbolic", Config.styling.info, { service: "desktop", op: "terminal", command: "cd \"$PHENIX_FLAKE\" && lazygit" }, { actionId: "phenix-git", aliases: ["git", "log", "lg", "lazygit"] }),
                action("reload_shell", qsTr("Reload Shell"), qsTr("Restart the phenix-shell user service"), "view-refresh-symbolic", Config.styling.warning, { service: "desktop", op: "exec", command: ["phenix", "reload-shell"] }, { actionId: "phenix-reload-shell", aliases: ["reload", "shell", "restart", "phenix-shell"] }),
                {
                    id: "devmode",
                    display: {
                        title: qsTr("Dev Mode"),
                        subtitle: qsTr("Switch between default and dev specialization"),
                        icon: "applications-development-symbolic",
                        iconColor: Config.styling.urgent
                    },
                    match: { aliases: ["dev", "devmode", "dev-mode"] },
                    template: "switch",
                    switchState: isDevMode(),
                    switchActions: {
                        toggle: { id: "toggle", title: qsTr("Toggle"), state: null, payload: { service: "desktop", op: "devmode" } },
                        on: { id: "on", title: qsTr("On"), state: true, payload: { service: "desktop", op: "devmode", enabled: true } },
                        off: { id: "off", title: qsTr("Off"), state: false, payload: { service: "desktop", op: "devmode", enabled: false } }
                    }
                }
            ]
        }];
    }
}
