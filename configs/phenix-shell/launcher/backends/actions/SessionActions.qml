import QtQml
import qs.services
import "../../logic/EvaluationProfiles.js" as EvalProfiles

QtObject {
    readonly property var tracer: Logger.scope("backend.actions.session", { category: "backend" })
    readonly property var prof: Profiler.scope("backend.actions.session", { category: "backend" })

    function node(id, aliases, title, subtitle, icon, color, operation, risk) {
        return {
            id: id,
            aliases: aliases,
            title: title,
            subtitle: subtitle,
            icon: icon,
            iconColor: color,
            action: { service: "session", op: operation },
            dangerous: !!risk,
            risk: risk || null
        };
    }

    function roots(context) {
        tracer.trace("roots", function() { return {}; });
        return [{
            id: "session",
            aliases: ["session", "system"],
            title: qsTr("Session"),
            icon: "system-shutdown-symbolic",
            template: "flat-action-group",
            behavior: { filterChildren: true },
            evaluationProfile: EvalProfiles.groupProfile({ evidence: ["field-match", "semantic"] }),
            children: [
                node("lock", ["lock"], qsTr("Lock"), qsTr("Lock the current session"), "system-lock-screen-symbolic", Config.styling.info, "lock"),
                node("logout", ["logout", "exit"], qsTr("Log Out"), qsTr("Exit the current session"), "system-log-out-symbolic", Config.styling.warning, "logout", { level: "session", activation: "confirm-and-explicit-prefix" }),
                node("shutdown", ["shutdown", "poweroff", "power-off"], qsTr("Shut Down"), qsTr("Power off this machine"), "system-shutdown-symbolic", Config.styling.critical, "shutdown", { level: "power", activation: "confirm-and-explicit-prefix" }),
                node("reboot", ["reboot", "restart"], qsTr("Reboot"), qsTr("Restart this machine"), "system-reboot-symbolic", Config.styling.urgent, "reboot", { level: "power", activation: "confirm-and-explicit-prefix" }),
                node("hibernate", ["hibernate", "suspend-to-disk"], qsTr("Hibernate"), qsTr("Suspend this machine to disk"), "system-suspend-hibernate-symbolic", Config.styling.secondaryAccent, "hibernate", { level: "power", activation: "confirm-and-explicit-prefix" })
            ]
        }];
    }
}
