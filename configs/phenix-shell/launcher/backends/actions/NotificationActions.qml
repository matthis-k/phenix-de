import QtQml
import qs.services
import "../../logic/EvaluationProfiles.js" as EvalProfiles

QtObject {
    readonly property var tracer: Logger.scope("backend.actions.notifications", { category: "backend" })
    readonly property var prof: Profiler.scope("backend.actions.notifications", { category: "backend" })
    function roots(context) { tracer.trace("roots", function() { return {}; }); return [{ id: "notifications", aliases: ["notif", "notifications", "notification"], title: qsTr("Notifications"), icon: "bell-symbolic", iconColor: Config.styling.warning, template: "flat-action-group", behavior: { filterChildren: true }, evaluationProfile: EvalProfiles.groupProfile(), children: [
        { id: "dnd", aliases: ["dnd"], title: qsTr("Do Not Disturb"), icon: "bell-disabled-symbolic", iconColor: NotificationCenter.doNotDisturbEnabled ? Config.styling.warning : Config.styling.text1, template: "switch", switchState: NotificationCenter.doNotDisturbEnabled, switchActions: { toggle: { id: "toggle", title: qsTr("Toggle"), state: null, payload: { service: "notifications", op: "toggleDnd" } }, on: { id: "on", title: qsTr("On"), state: true, payload: { service: "notifications", op: "setDnd", enabled: true } }, off: { id: "off", title: qsTr("Off"), state: false, payload: { service: "notifications", op: "setDnd", enabled: false } } } },
        { id: "clear", aliases: ["clear", "clear-all"], title: qsTr("Clear All"), subtitle: qsTr("Dismiss all current notifications"), icon: "user-trash-symbolic", iconColor: Config.styling.critical, action: { service: "notifications", op: "clearAll" } }
    ] }]; }
}
