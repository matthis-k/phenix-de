pragma ComponentBehavior: Bound

import QtQuick
import QtQml
import QtQml.Models

QtObject {
    id: root

    property ListModel model: ListModel { id: visualModel }

    property int animationMode: TransitionPolicy.Mode.Full
    property int recentlyRemovedTtl: 400
    property bool debugEnabled: false
    property bool hardReplaceSnapshots: false

    property real contentHeight: 0
    property real estimatedRowHeight: 60

    property int snapshotSerial: 0
    property var lastOperations: []
    property var _recentlyRemovedKeys: ({})
    property bool hasActiveItems: false
    property var _lastSnapshotTime: null
    property string _lastContextKey: ""
    property string _lastInputText: ""

    property string snapshotQuery: ""
    property int snapshotQueryRevision: -1
    property int snapshotGeneration: -1

    property TransitionPolicy policy: TransitionPolicy { id: transitionPolicy }

    property Timer _removedKeyCleanupTimer: Timer {
        interval: root.recentlyRemovedTtl
        repeat: false
        onTriggered: root.pruneRecentlyRemovedKeys()
    }

    property Timer _leavingRemovalTimer: Timer {
        interval: transitionPolicy.removalDelay(root.animationMode) + 80
        repeat: false
        onTriggered: root.removeSettledLeavingRows()
    }

    signal snapshotApplied()

    function applySnapshot(items, context) {
        const rows = normaliseItems(items || []);
        const ctx = context || {};

        const nextRevision = numberOr(ctx.queryRevision, -1);
        const nextGeneration = numberOr(ctx.generation, -1);

        if (isStaleSnapshot(nextRevision, nextGeneration)) {
            recordOperation("drop-stale-snapshot", {
                nextRevision: nextRevision,
                currentRevision: root.snapshotQueryRevision,
                nextGeneration: nextGeneration,
                currentGeneration: root.snapshotGeneration
            });
            return;
        }

        root.snapshotSerial += 1;
        root.lastOperations = [];

        root.snapshotQuery = String(ctx.inputText || "");
        root.snapshotQueryRevision = nextRevision;
        root.snapshotGeneration = nextGeneration;

        const mode = transitionPolicy.modeForSnapshot({
            inputText: ctx.inputText || "",
            previousInputText: root._lastInputText,
            contextKey: ctx.contextKey || "",
            previousContextKey: root._lastContextKey,
            reason: ctx.reason || "",
            timeSinceLastSnapshot: root.timeSinceLastSnapshot(),
            snapshotSerial: root.snapshotSerial,
            activeItemCount: rows.length,
            previousItemCount: visualModel.count
        });

        root.animationMode = mode;
        root._lastInputText = ctx.inputText || "";
        root._lastContextKey = ctx.contextKey || "";
        root._lastSnapshotTime = Date.now();

        if (root.hardReplaceSnapshots || mode === TransitionPolicy.Mode.None || ctx.reason === "hard-replace") {
            hardReplace(rows);
        } else {
            reconcileKeyed(rows, ctx);
        }

        recomputeTargets();
        recomputeHasActiveItems();
        logSnapshot(rows);
        root.snapshotApplied();
    }

    function numberOr(value, fallback) {
        const n = Number(value);
        return Number.isFinite(n) ? n : fallback;
    }

    function isStaleSnapshot(nextRevision, nextGeneration) {
        if (nextRevision >= 0 && root.snapshotQueryRevision >= 0 && nextRevision < root.snapshotQueryRevision)
            return true;
        if (nextGeneration >= 0 && root.snapshotGeneration >= 0 && nextGeneration < root.snapshotGeneration)
            return true;
        return false;
    }

    function hardReplace(rows) {
        visualModel.clear();
        root._recentlyRemovedKeys = ({});

        let y = 0;
        for (let i = 0; i < rows.length; i += 1) {
            const row = rows[i];
            const item = makeLiveItem(row, i, y);
            visualModel.append(item);
            y += item.targetHeight;
        }

        root.contentHeight = y;
        recordOperation("hard-replace", { count: rows.length });
    }

    function reconcileKeyed(rows, ctx) {
        const targetKeys = makeTargetKeySet(rows);

        for (let i = 0; i < rows.length; i += 1) {
            const row = rows[i];
            clearRecentlyRemoved(row.key);

            const existingIndex = indexOfKey(row.key);
            if (existingIndex >= 0) {
                setTargetPresent(existingIndex, row, i);
            } else {
                insertTargetItem(row, i, rows);
            }
        }

        for (let i = visualModel.count - 1; i >= 0; i -= 1) {
            const item = visualModel.get(i);
            if (targetKeys[item.key])
                continue;
            if (item.phase === "leaving")
                continue;

            rememberRecentlyRemoved(item.key);
            visualModel.setProperty(i, "phase", "leaving");
            visualModel.setProperty(i, "targetOpacity", 0);
            visualModel.setProperty(i, "targetScale", 0.98);
            visualModel.setProperty(i, "targetHeight", 0);
            visualModel.setProperty(i, "visualHeight", item.visualHeight);
            visualModel.setProperty(i, "zValue", -1);
            recordOperation("remove", { key: item.key, from: i });
        }

        scheduleLeavingRemoval();
    }

    function makeLiveItem(row, rank, initialY) {
        const full = row.fullHeight || row.estimatedHeight || root.estimatedRowHeight;
        return {
            key: row.key,
            payload: row.payload,
            rank: rank,
            targetRank: rank,
            zValue: zValueForRank(rank),
            phase: "live",
            animationRole: row.animationRole || "",
            y: initialY,
            targetY: initialY,
            visualHeight: full,
            targetHeight: full,
            measuredHeight: full,
            targetOpacity: 1,
            targetScale: 1
        };
    }

    function setTargetPresent(index, row, rank) {
        const current = visualModel.get(index);
        const measured = positiveOr(current.measuredHeight, row.fullHeight || row.estimatedHeight || root.estimatedRowHeight);

        visualModel.setProperty(index, "payload", row.payload);
        visualModel.setProperty(index, "rank", rank);
        visualModel.setProperty(index, "targetRank", rank);
        visualModel.setProperty(index, "zValue", zValueForRank(rank));
        visualModel.setProperty(index, "phase", current.phase === "entering" ? "entering" : "live");
        visualModel.setProperty(index, "animationRole", row.animationRole || "");
        visualModel.setProperty(index, "targetHeight", measured);
        visualModel.setProperty(index, "targetOpacity", 1);
        visualModel.setProperty(index, "targetScale", 1);

        recordOperation("target-live", {
            key: row.key,
            index: index,
            rank: rank,
            previousPhase: current.phase
        });
    }

    function insertTargetItem(row, rank, rows) {
        const insertIndex = insertionIndexForRank(rank);
        const y = insertionYForRank(rank);
        const full = row.fullHeight || row.estimatedHeight || root.estimatedRowHeight;
        const entering = root.animationMode !== TransitionPolicy.Mode.None;

        visualModel.insert(insertIndex, {
            key: row.key,
            payload: row.payload,
            rank: rank,
            targetRank: rank,
            zValue: zValueForRank(rank),
            phase: entering ? "entering" : "live",
            animationRole: row.animationRole || "",
            y: y,
            targetY: y,
            visualHeight: entering ? 0 : full,
            targetHeight: full,
            measuredHeight: full,
            targetOpacity: entering ? 0 : 1,
            targetScale: entering ? 0.96 : 1
        });

        recordOperation("insert", {
            key: row.key,
            to: insertIndex,
            rank: rank,
            phase: entering ? "entering" : "live"
        });

        if (entering) {
            Qt.callLater(function() {
                const idx = indexOfKey(row.key);
                if (idx < 0)
                    return;
                if (visualModel.get(idx).phase === "leaving")
                    return;

                visualModel.setProperty(idx, "targetOpacity", 1);
                visualModel.setProperty(idx, "targetScale", 1);
                visualModel.setProperty(idx, "targetHeight", positiveOr(visualModel.get(idx).measuredHeight, full));
                visualModel.setProperty(idx, "visualHeight", positiveOr(visualModel.get(idx).measuredHeight, full));
                recomputeTargets();
            });
        }
    }

    function insertionIndexForRank(rank) {
        for (let i = 0; i < visualModel.count; i += 1) {
            const item = visualModel.get(i);
            if (item.phase === "leaving")
                continue;
            if (item.rank > rank)
                return i;
        }
        return visualModel.count;
    }

    function insertionYForRank(rank) {
        let y = 0;
        for (let i = 0; i < visualModel.count; i += 1) {
            const item = visualModel.get(i);
            if (item.phase === "leaving")
                continue;
            if (item.rank >= rank)
                break;
            y += positiveOr(item.targetHeight, item.visualHeight || root.estimatedRowHeight);
        }
        return y;
    }

    function recomputeTargets() {
        const liveIndices = [];
        for (let i = 0; i < visualModel.count; i += 1) {
            if (visualModel.get(i).phase !== "leaving")
                liveIndices.push(i);
        }

        liveIndices.sort(function(a, b) {
            const ia = visualModel.get(a);
            const ib = visualModel.get(b);
            if (ia.rank !== ib.rank)
                return ia.rank - ib.rank;
            return String(ia.key).localeCompare(String(ib.key));
        });

        let y = 0;
        for (let order = 0; order < liveIndices.length; order += 1) {
            const idx = liveIndices[order];
            const item = visualModel.get(idx);
            const h = positiveOr(item.measuredHeight, item.targetHeight || root.estimatedRowHeight);

            visualModel.setProperty(idx, "targetRank", order);
            visualModel.setProperty(idx, "targetY", y);
            visualModel.setProperty(idx, "targetHeight", h);

            if (item.phase !== "entering")
                visualModel.setProperty(idx, "visualHeight", h);

            visualModel.setProperty(idx, "zValue", zValueForRank(order));
            y += h;
        }

        root.contentHeight = y;
    }

    function updateMeasuredHeight(key, measuredHeight) {
        const idx = indexOfKey(key);
        if (idx < 0)
            return;

        const h = positiveOr(measuredHeight, root.estimatedRowHeight);
        const old = positiveOr(visualModel.get(idx).measuredHeight, root.estimatedRowHeight);

        if (Math.abs(old - h) < 0.5)
            return;

        visualModel.setProperty(idx, "measuredHeight", h);

        if (visualModel.get(idx).phase !== "leaving") {
            visualModel.setProperty(idx, "targetHeight", h);
            visualModel.setProperty(idx, "visualHeight", h);
        }

        recordOperation("measure", { key: key, height: h });
        recomputeTargets();
    }

    function positiveOr(value, fallback) {
        const n = Number(value);
        return Number.isFinite(n) && n > 0 ? n : fallback;
    }

    function makeTargetKeySet(rows) {
        const keys = ({});
        for (let i = 0; i < rows.length; i += 1)
            keys[rows[i].key] = true;
        return keys;
    }

    function clearRecentlyRemoved(key) {
        if (!key || root._recentlyRemovedKeys[key] === undefined)
            return;

        const next = Object.assign({}, root._recentlyRemovedKeys);
        delete next[key];
        root._recentlyRemovedKeys = next;
    }

    function rememberRecentlyRemoved(key) {
        if (!key)
            return;

        const next = Object.assign({}, root._recentlyRemovedKeys);
        next[key] = Date.now();
        root._recentlyRemovedKeys = next;
        root._removedKeyCleanupTimer.restart();
    }

    function pruneRecentlyRemovedKeys() {
        const now = Date.now();
        const next = ({});

        for (const key in root._recentlyRemovedKeys) {
            if (now - root._recentlyRemovedKeys[key] <= root.recentlyRemovedTtl)
                next[key] = root._recentlyRemovedKeys[key];
        }

        root._recentlyRemovedKeys = next;

        if (Object.keys(next).length > 0)
            root._removedKeyCleanupTimer.restart();
    }

    function scheduleLeavingRemoval() {
        for (let i = 0; i < visualModel.count; i += 1) {
            if (visualModel.get(i).phase === "leaving") {
                root._leavingRemovalTimer.restart();
                return;
            }
        }
    }

    function removeSettledLeavingRows() {
        for (let i = visualModel.count - 1; i >= 0; i -= 1) {
            if (visualModel.get(i).phase === "leaving")
                visualModel.remove(i);
        }

        recomputeTargets();
        recomputeHasActiveItems();
    }

    function normaliseItems(items) {
        const rows = [];
        const seen = ({});

        for (let i = 0; i < items.length; i += 1) {
            const item = items[i];
            const key = keyForItem(item);

            if (!key) {
                console.warn("[TransitionListCoordinator] item missing stable key at index", i);
                continue;
            }

            if (seen[key]) {
                console.warn("[TransitionListCoordinator] duplicate key:", key);
                continue;
            }

            seen[key] = true;
            rows.push({
                key: key,
                payload: item.payload !== undefined ? item.payload : item,
                rank: i,
                animationRole: item.animationRole || "",
                fullHeight: item.fullHeight || 0,
                estimatedHeight: item.estimatedHeight || root.estimatedRowHeight
            });
        }

        return rows;
    }

    function keyForItem(item) {
        if (!item)
            return "";
        if (item.key)
            return String(item.key);
        if (item.id)
            return String(item.id);
        return "";
    }

    function indexOfKey(key) {
        for (let i = 0; i < visualModel.count; i += 1) {
            if (visualModel.get(i).key === key)
                return i;
        }
        return -1;
    }

    function zValueForRank(rank) {
        return 10000 - rank;
    }

    function timeSinceLastSnapshot() {
        if (!root._lastSnapshotTime)
            return 9999;
        return Date.now() - root._lastSnapshotTime;
    }

    function recomputeHasActiveItems() {
        for (let i = 0; i < visualModel.count; i += 1) {
            if (visualModel.get(i).phase !== "leaving") {
                root.hasActiveItems = true;
                return;
            }
        }
        root.hasActiveItems = false;
    }

    function resetTransientState() {
        root._lastInputText = "";
        root._lastContextKey = "";
        root._recentlyRemovedKeys = ({});
        root._lastSnapshotTime = null;
        root.animationMode = TransitionPolicy.Mode.None;
        root.snapshotQuery = "";
        root.snapshotQueryRevision = -1;
        root.snapshotGeneration = -1;
    }

    function resetModel() {
        visualModel.clear();
        root.contentHeight = 0;
        root.hasActiveItems = false;
        root.resetTransientState();
    }

    function recordOperation(type, details) {
        const operation = Object.assign({ type: type }, details || {});
        root.lastOperations = root.lastOperations.concat([operation]);
        if (root.debugEnabled)
            console.warn("[TransitionListCoordinator]", JSON.stringify(operation));
    }

    function logSnapshot(rows) {
        if (!root.debugEnabled)
            return;
        console.warn(
            "[TransitionListCoordinator] snapshot",
            root.snapshotSerial,
            "mode", root.animationMode,
            "input", rows.length,
            "model", visualModel.count,
            "q:", root.snapshotQuery,
            "rev:", root.snapshotQueryRevision
        );
    }

    function debugState(extra) {
        const rows = [];
        const recentlyRemoved = Object.keys(root._recentlyRemovedKeys);

        for (let i = 0; i < visualModel.count; i += 1) {
            const item = visualModel.get(i);
            rows.push({
                index: i,
                key: item.key,
                phase: item.phase,
                rank: item.rank,
                targetRank: item.targetRank,
                y: item.y,
                targetY: item.targetY,
                visualHeight: item.visualHeight,
                targetHeight: item.targetHeight,
                measuredHeight: item.measuredHeight,
                opacity: item.targetOpacity,
                scale: item.targetScale,
                zValue: item.zValue
            });
        }

        return {
            snapshotSerial: root.snapshotSerial,
            query: root.snapshotQuery,
            queryRevision: root.snapshotQueryRevision,
            generation: root.snapshotGeneration,
            animationMode: root.animationMode,
            debugEnabled: root.debugEnabled,
            modelCount: visualModel.count,
            contentHeight: root.contentHeight,
            rows: rows,
            lastOperations: root.lastOperations,
            recentlyRemovedKeys: recentlyRemoved,
            metrics: extra || {}
        };
    }
}
