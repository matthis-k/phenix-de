pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.services

Singleton {
    id: root

    readonly property var tracer: Logger.scope("power.service", { category: "power" })
    readonly property var prof: Profiler.scope("power.service", { category: "power" })

    readonly property var backend: UPower

    readonly property var battery: UPower.displayDevice
    readonly property bool available: hasBattery || true
    readonly property bool hasBattery: battery?.isLaptopBattery === true
    readonly property real batteryPercent: hasBattery ? Math.round((battery.percentage || 0) * 100) : 0
    readonly property bool charging: hasBattery && battery.state === UPowerDeviceState.Charging
    readonly property int timeToFull: hasBattery ? (battery.timeToFull || 0) : 0
    readonly property int timeToEmpty: hasBattery ? (battery.timeToEmpty || 0) : 0

    readonly property int profile: PowerProfiles.profile
    readonly property var profiles: [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
    property string currentOperationKind: ""
    property string currentOperationTarget: ""
    property bool currentOperationRunning: false
    property string currentOperationLastError: ""

    readonly property var operation: ({
        kind: currentOperationKind,
        target: currentOperationTarget,
        running: currentOperationRunning,
        lastError: currentOperationLastError
    })
    readonly property bool busy: currentOperationRunning

    function beginOperation(kind, target) {
        currentOperationKind = kind || "";
        currentOperationTarget = target || "";
        currentOperationRunning = true;
        currentOperationLastError = "";
    }

    function finishOperation(success, message) {
        currentOperationRunning = false;
        currentOperationLastError = success ? "" : (message || `${currentOperationKind || "operation"} failed`);
    }

    readonly property string state: {
        if (hasBattery && batteryPercent <= 10) return "critical";
        if (hasBattery && batteryPercent <= 20) return "warning";
        return "normal";
    }

    readonly property string iconName: {
        if (hasBattery)
            return battery.iconName || "battery-missing-symbolic";
        return profileIconName(profile);
    }

    readonly property color iconColor: batteryColor(batteryPercent, charging)

    readonly property string label: hasBattery ? "Battery" : "Power"
    readonly property string statusText: {
        if (hasBattery) return batterySummary();
        return profileLabel(profile);
    }

    readonly property var presentation: {
        return {
            icon: root.iconName,
            color: root.iconColor,
            label: root.label,
            status: root.statusText,
            state: root.state,
            hasBattery: root.hasBattery,
            batteryPercent: root.batteryPercent,
            charging: root.charging,
            profile: root.profile
        };
    }

    readonly property var batteryPresentation: hasBattery ? {
        icon: root.iconName,
        color: root.iconColor,
        percent: root.batteryPercent,
        charging: root.charging,
        timeToFull: root.timeToFull,
        timeToEmpty: root.timeToEmpty,
        summary: root.batterySummary()
    } : null

    readonly property var profilePresentation: {
        return {
            icon: root.profileIconName(root.profile),
            color: root.profileColor(root.profile),
            label: root.profileLabel(root.profile),
            profile: root.profile,
            control: {
                kind: "slider",
                target: "power-profile",
                from: 0,
                to: 2,
                step: 1,
                value: root.profileIndex(root.profile)
            }
        };
    }

    function setProfile(profile) {
        beginOperation("set-profile", profileLabel(profile));
        PowerProfiles.profile = profile;
        finishOperation(true, "");
        root.tracer.info("profileSet", function() { return { profile: profileLabel(profile) } });
    }

    function cycleProfile(direction) {
        const idx = profileIndex(PowerProfiles.profile);
        const newIdx = Math.max(0, Math.min(2, idx + direction));
        root.tracer.debug("cycleProfile", function() { return { direction: direction, from: profileLabel(PowerProfiles.profile), to: profileLabel(profileFromIndex(newIdx)) } });
        setProfile(profileFromIndex(newIdx));
    }

    function executePayload(payload) {
        if (!payload || payload.service !== "power") {
            if (payload) root.tracer.warn("executePayload.wrongService", function() { return { service: payload.service } });
            return false;
        }

        root.tracer.debug("executePayload", function() { return { op: payload.op } });
        switch (payload.op) {
        case "setProfile":
            root.setProfile(root.profileFromIndex(payload.index));
            return true;
        case "cycleProfile":
            root.cycleProfile(Number(payload.delta || 0));
            return true;
        default:
            root.tracer.warn("executePayload.unknownOp", function() { return { op: payload.op } });
            return false;
        }
    }

    function profileIndex(profile) {
        switch (profile) {
        case PowerProfile.PowerSaver: return 0;
        case PowerProfile.Performance: return 2;
        default: return 1;
        }
    }

    function profileFromIndex(index) {
        switch (Math.round(index)) {
        case 0: return PowerProfile.PowerSaver;
        case 2: return PowerProfile.Performance;
        default: return PowerProfile.Balanced;
        }
    }

    function profileLabel(profile) {
        switch (profile) {
        case PowerProfile.PowerSaver: return "Power Saver";
        case PowerProfile.Performance: return "Performance";
        default: return "Balanced";
        }
    }

    function profileIconName(profile) {
        switch (profile) {
        case PowerProfile.PowerSaver: return "power-profile-power-saver-symbolic";
        case PowerProfile.Performance: return "power-profile-performance-symbolic";
        default: return "power-profile-balanced-symbolic";
        }
    }

    function profileColor(profile) {
        switch (profile) {
        case PowerProfile.PowerSaver: return Config.styling.good;
        case PowerProfile.Performance: return Config.styling.critical;
        default: return Config.colors.yellow;
        }
    }

    function batteryColor(percent, charging) {
        if (percent <= 10) return Config.styling.critical;
        if (percent <= 20) return Config.styling.warning;
        if (percent <= 60) return Config.styling.text0;
        return Config.styling.good;
    }

    function formatDuration(seconds, prefix) {
        if (!seconds || seconds <= 0)
            return "";
        const h = Math.floor(seconds / 3600);
        const m = Math.floor(seconds / 60) % 60;
        return `${prefix}${h}h${m}m`;
    }

    function batterySummary() {
        if (!battery || !hasBattery)
            return "No battery";
        const pct = `${Math.floor((battery.percentage || 0) * 100)}%`;
        if (battery.state === UPowerDeviceState.Charging) {
            const duration = formatDuration(battery.timeToFull, "Full in ");
            return duration ? `${pct} • ${duration}` : pct;
        }
        const duration = formatDuration(battery.timeToEmpty, "Empty in ");
        return duration ? `${pct} • ${duration}` : pct;
    }
}
