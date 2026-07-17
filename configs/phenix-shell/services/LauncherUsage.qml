pragma Singleton
pragma ComponentBehavior: Bound

import QtQml
import Quickshell
import qs.services

Singleton {
    id: root

    readonly property var tracer: Logger.scope("launcher.usage", { category: "launcher" })

    property int revision: 0
    property int maxEntries: 256
    property var history: ({})

    PersistentProperties {
        id: persisted
        reloadableId: "launcherUsageHistory"

        property string historyJson: "{}"
    }

    function isTestMode() {
        return Quickshell.env("PHENIX_SHELL_TEST_MODE") === "1";
    }

    function stableKey(target) {
        if (!target)
            return "";

        const source = String(target.source || target.backendId || target.category || "global");
        const id = String(target.nodeId || target.id || target.key || "");
        if (!id)
            return "";

        const pathParts = target.breadcrumbs || target.path || [];
        const path = Array.isArray(pathParts) ? pathParts.join("/") : String(pathParts || "");
        return [source, id, path].join("|");
    }

    function load() {
        try {
            const parsed = JSON.parse(persisted.historyJson || "{}");
            root.history = parsed && typeof parsed === "object" ? parsed : {};
        } catch (error) {
            root.tracer.warn("load.invalidJson", function() { return { error: String(error) }; });
            root.history = {};
        }
        root.revision++;
    }

    function save(nextHistory) {
        root.history = nextHistory || {};
        persisted.historyJson = JSON.stringify(root.history);
        root.revision++;
    }

    function prune(entries) {
        const keys = Object.keys(entries || {});
        if (keys.length <= root.maxEntries)
            return entries;

        keys.sort(function(a, b) {
            return Number(entries[b]?.lastUsedAt || 0) - Number(entries[a]?.lastUsedAt || 0);
        });

        const retained = {};
        for (let i = 0; i < root.maxEntries; i += 1)
            retained[keys[i]] = entries[keys[i]];
        return retained;
    }

    function record(target) {
        if (root.isTestMode())
            return false;

        const key = root.stableKey(target);
        if (!key)
            return false;

        const current = root.history[key] || {};
        const next = Object.assign({}, root.history);
        next[key] = {
            count: Math.max(0, Number(current.count || 0)) + 1,
            lastUsedAt: Date.now(),
            title: String(target.title || target.label || ""),
            source: String(target.source || target.backendId || "")
        };

        root.save(root.prune(next));
        root.tracer.debug("recorded", function() {
            return { key: key, count: next[key].count };
        });
        return true;
    }

    function metricsFor(target) {
        const explicitCount = Math.max(0, Number(target?.usageCount || 0));
        const explicitDays = Number(target?.lastUsedDaysAgo);

        if (root.isTestMode()) {
            return {
                count: explicitCount,
                daysAgo: isFinite(explicitDays) ? explicitDays : 9999
            };
        }

        const key = root.stableKey(target);
        const entry = key ? root.history[key] : null;
        if (!entry) {
            return {
                count: explicitCount,
                daysAgo: isFinite(explicitDays) ? explicitDays : 9999
            };
        }

        const lastUsedAt = Number(entry.lastUsedAt || 0);
        const daysAgo = lastUsedAt > 0
            ? Math.max(0, (Date.now() - lastUsedAt) / 86400000)
            : 9999;

        return {
            count: Math.max(explicitCount, Number(entry.count || 0)),
            daysAgo: Math.min(isFinite(explicitDays) ? explicitDays : 9999, daysAgo)
        };
    }

    function clear() {
        root.save({});
    }

    Component.onCompleted: root.load()
}
