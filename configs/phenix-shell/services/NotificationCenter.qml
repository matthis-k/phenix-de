pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.services

Singleton {
    id: root

    readonly property var tracer: Logger.scope("notificationCenter", { category: "notification" })
    readonly property var prof: Profiler.scope("notificationCenter", { category: "notification" })

    readonly property var backend: server

    property alias toastsEnabled: state.toastsEnabled
    readonly property bool doNotDisturbEnabled: !toastsEnabled
    readonly property bool doNotDisturb: !toastsEnabled
    readonly property var notifications: server.trackedNotifications.values || []
    readonly property int count: notifications.length
    readonly property int criticalCount: notifications.filter(notification => notification.urgency === NotificationUrgency.Critical).length
    readonly property bool hasCritical: criticalCount > 0
    readonly property bool hasUrgent: hasCritical
    readonly property int unreadCount: count
    readonly property string badgeText: count > 99 ? "99+" : (count > 0 ? `${count}` : "")

    readonly property string state: {
        if (hasCritical) return "critical";
        if (doNotDisturbEnabled) return "dnd";
        if (count > 0) return "active";
        return "clear";
    }

    readonly property string iconName: doNotDisturbEnabled ? "bell-disabled-symbolic" : "bell-symbolic"
    readonly property color iconColor: {
        if (hasCritical) return Config.styling.critical;
        if (doNotDisturbEnabled) return Config.styling.warning;
        return Config.styling.text0;
    }

    readonly property string label: "Notifications"
    readonly property string statusText: {
        if (doNotDisturbEnabled) return "Do Not Disturb";
        if (count > 0) return `${count} unread`;
        return "No notifications";
    }

    readonly property var presentation: {
        return {
            icon: root.iconName,
            color: root.iconColor,
            label: root.label,
            status: root.statusText,
            state: root.state,
            count: root.count,
            unreadCount: root.unreadCount,
            hasUrgent: root.hasUrgent
        };
    }

    function dismiss(notification) {
        if (notification) {
            root.tracer.debug("dismiss", function() { return { appName: notification.appName } });
            notification.dismiss();
        }
    }

    function clearAll() {
        root.tracer.info("clearAll", function() { return { count: notifications.length } });
        for (const notification of notifications)
            notification.dismiss();
    }

    function invokeDefaultAction(notification) {
        if (!notification) {
            root.tracer.warn("invokeDefaultAction.nullNotification");
            return;
        }

        if (notification.actions.length > 0) {
            root.tracer.debug("invokeDefaultAction", function() { return { appName: notification.appName, actionCount: notification.actions.length } });
            notification.actions[0].invoke();
            return;
        }

        notification.dismiss();
    }

    function urgencyColor(notification) {
        if (!notification)
            return Config.styling.text0;

        if (notification.urgency === NotificationUrgency.Critical)
            return Config.styling.critical;

        if (notification.urgency === NotificationUrgency.Low)
            return Config.styling.text2;

        return Config.styling.text0;
    }

    function renderBody(body) {
        let text = (body || "").trim();
        if (text === "")
            return "";

        text = text
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;");

        text = text.replace(/`([^`]+)`/g, "<code>$1</code>");
        text = text.replace(/\*\*([^*]+)\*\*/g, "<b>$1</b>");
        text = text.replace(/(^|[^*])\*([^*]+)\*(?!\*)/g, "$1<i>$2</i>");
        text = text.replace(/\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)/g, '<a href="$2">$1</a>');

        const lines = text.split(/\n/);
        let inList = false;
        const rendered = [];

        for (const line of lines) {
            const bulletMatch = line.match(/^\s*[-*]\s+(.*)$/);
            if (bulletMatch) {
                if (!inList) {
                    rendered.push("<ul>");
                    inList = true;
                }
                rendered.push(`<li>${bulletMatch[1]}</li>`);
                continue;
            }

            if (inList) {
                rendered.push("</ul>");
                inList = false;
            }

            rendered.push(line);
        }

        if (inList)
            rendered.push("</ul>");

        return rendered.join("<br/>");
    }

    function setDoNotDisturb(value) {
        root.toastsEnabled = !value;
        root.tracer.info("dndSet", function() { return { enabled: !value } });
    }

    function toggleDoNotDisturb() {
        root.toastsEnabled = !root.toastsEnabled;
        root.tracer.info("dndToggled", function() { return { enabled: root.toastsEnabled } });
    }

    function executePayload(payload) {
        if (!payload || payload.service !== "notifications") {
            if (payload) root.tracer.warn("executePayload.wrongService", function() { return { service: payload.service } });
            return false;
        }

        root.tracer.debug("executePayload", function() { return { op: payload.op } });
        switch (payload.op) {
        case "setDnd":
            root.setDoNotDisturb(!!payload.enabled);
            return true;
        case "toggleDnd":
            root.setDoNotDisturb(!root.doNotDisturbEnabled);
            return true;
        case "clearAll":
            root.clearAll();
            return true;
        default:
            root.tracer.warn("executePayload.unknownOp", function() { return { op: payload.op } });
            return false;
        }
    }

    PersistentProperties {
        id: state
        property bool toastsEnabled: true
        reloadableId: "notificationCenterState"
    }

    NotificationServer {
        id: server
        actionsSupported: true
        actionIconsSupported: true
        bodySupported: true
        bodyHyperlinksSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        bodyImagesSupported: true
        persistenceSupported: true
        keepOnReload: true

        onNotification: function(notification) {
            notification.tracked = true;
        }
    }
}
