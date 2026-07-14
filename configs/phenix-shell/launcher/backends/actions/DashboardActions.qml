import QtQml
import qs.services
import "../../logic/EvaluationProfiles.js" as EvalProfiles

QtObject {
    readonly property var tracer: Logger.scope("backend.actions.dashboard", { category: "backend" })
    readonly property var prof: Profiler.scope("backend.actions.dashboard", { category: "backend" })

    property var shellScreenState: null

    function titleForTab(tab) { return tab === "wifi" ? "Wi-Fi" : tab; }
    function iconForTab(tab) {
        switch (tab) {
        case "overview": return "view-grid-symbolic";
        case "audio": return AudioService.outputIconName;
        case "notifications": return NotificationCenter.doNotDisturbEnabled ? "bell-disabled-symbolic" : "bell-symbolic";
        case "bluetooth": return BluetoothService.iconName;
        case "wifi": return NetworkService.iconName;
        case "energy": return PowerService.iconName;
        case "stats": return "utilities-system-monitor-symbolic";
        default: return "view-grid-symbolic";
        }
    }
    function colorForTab(tab) {
        switch (tab) {
        case "audio": return AudioService.outputMuted ? Config.styling.critical : (AudioService.outputVolume === 0 ? Config.styling.warning : Config.styling.text0);
        case "notifications": return NotificationCenter.hasCritical ? Config.styling.critical : (NotificationCenter.doNotDisturbEnabled ? Config.styling.warning : Config.styling.text0);
        case "bluetooth": return BluetoothService.enabled ? Config.styling.bluetooth : Config.styling.critical;
        case "energy": return PowerService.iconColor;
        case "stats": return Stats.presentation.color;
        case "overview": return Config.styling.primaryAccent;
            default: return Config.styling.text0;
        }
    }
    function roots(context) {
        tracer.trace("roots", function() { return {}; });
        var tabs = (shellScreenState && shellScreenState.dashboardTabs) || ["overview", "audio", "notifications", "bluetooth", "wifi", "energy", "stats"];
        return [{ id: "dashboard", aliases: ["db", "dashboard"], title: qsTr("Dashboard"), icon: iconForTab("overview"), iconColor: colorForTab("overview"), template: "flat-action-group", behavior: { filterChildren: true }, evaluationProfile: EvalProfiles.groupProfile({ evidence: ["field-match", "semantic"] }), action: { service: "dashboard", tab: "overview" }, children: tabs.map(function(tab) { return { id: tab, title: titleForTab(tab), icon: iconForTab(tab), iconColor: colorForTab(tab), action: { service: "dashboard", tab: tab } }; }) }];
    }
}
