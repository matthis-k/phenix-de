pragma ComponentBehavior: Bound

import QtQuick
import QtQml
import QtQml.Models
import "../components/SnapshotDiff.js" as SnapshotDiff

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
    property var lastChangeSet: SnapshotDiff.empty()
    property var lastChangeSummary: lastChangeSet.summary
    property var _snapshotRows: []
    property var _recentlyRemovedKeys: ({})
    property bool hasActiveItems: false
    property var _lastSnapshotTime: null
    property string _lastContextKey: ""
    property string _lastInputText: ""

    property string snapshotQuery: ""
    property int snapshotQueryRevision: -1
    property int snapshotGeneration: -1
    property int projectionRevision: -1

    property TransitionPolicy policy: TransitionPolicy { id: transitionPolicy }

    property Timer _removedKeyCleanupTimer: Timer {
        interval: root.recentlyRemovedTtl
        repeat: false
        onTriggered: root.pruneRecentlyRemovedKeys()
    }

    property Timer _leavingRemovalTimer: Timer {
        interval: 1
        repeat: false
        onTriggered: root.removeSettledLeavingRows()
    }

    property Timer _settleTimer: Timer {
        interval: Math.max(
            transitionPolicy.duration(TransitionPolicy.Kind.ListInsert, root.animationMode),
            transitionPolicy.duration(TransitionPolicy.Kind.ListMove, root.animationMode)
        ) + 40
        repeat: false
        onTriggered: root.settleRows()
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
            return false;
        }

        const changes = root.changeSetFor(rows, ctx.changeSet);

        root.snapshotSerial += 1;
        root.lastOperations = [];
        root.lastChangeSet = changes;
        root.lastChangeSummary = changes.summary || SnapshotDiff.empty().summary;

        root.snapshotQuery = String(ctx.inputText || "");
        root.snapshotQueryRevision = nextRevision;
        root.snapshotGeneration = nextGeneration;
        root.projectionRevision = numberOr(ctx.projectionRevision, root.projectionRevision);

        const mode = transitionPolicy.modeForSnapshot({
            inputText: ctx.inputText || "",
            previousInputText: root._lastInputText,
            contextKey: ctx.contextKey || "",
            previousContextKey: root._lastContextKey,
            reason: ctx.reason || "",
            timeSinceLastSnapshot: root.timeSinceLastSnapshot(),
            snapshotSerial: root.snapshotSerial,
            activeItemCount: rows.length,
            previousItemCount: root._snapshotRows.length
        });

        root.animationMode = mode;
        root._lastInputText = ctx.inputText || "";
        root._lastContextKey = ctx.contextKey || "";
        root._lastSnapshotTime = Date.now();

        if (root.hardReplaceSnapshots || mode === TransitionPolicy.Mode.None || ctx.reason === "hard-replace") {
            hardReplace(rows);
        } else {
            reconcileChanges(rows, changes);
        }

        root._snapshotRows = rows;
        recomputeTargets();
        recomputeHasActiveItems();
        scheduleSettling();
        logSnapshot(rows);
        root.snapshotApplied();
        return true;
    }

    function changeSetFor(rows, supplied) {
        if (supplied && Array.isArray(supplied.inserted)
                && Array.isArray(supplied.removed)
                && Array.isArray(supplied.retained))
            return root.normalizedChangeSet(supplied);

        return SnapshotDiff.keyed(
            root._snapshotRows || [],
            rows,
            function(row) { return row.key; },
            root.sameRow
        );
    }

    function normalizedChangeSet(changes) {
        const moved = Array.isArray(changes.moved) ? changes.moved : [];
        const reordered = Array.isArray(changes.reordered)
            ? changes.reordered
            : moved.filter(function(entry) { return entry.movement === "reorder"; });
        const displaced = Array.isArray(changes.displaced)
            ? changes.displaced
            : moved.filter(function(entry) { return entry.movement !== "reorder"; });

        return {
            changed: changes.changed === true,
            inserted: changes.inserted || [],
            removed: changes.removed || [],
            updated: changes.updated || [],
            moved: moved,
            reordered: reordered,
            displaced: displaced,
            retained: changes.retained || [],
            operations: changes.operations || [],
            summary: changes.summary || {
                inserted: (changes.inserted || []).length,
                removed: (changes.removed || []).length,
                updated: (changes.updated || []).length,
                moved: moved.length,
                reordered: reordered.length,
                displaced: displaced.length,
                retained: (changes.retained || []).length
            }
        };
    }

    function sameRow(previous, next) {
        return previous && next
            && previous.payload === next.payload
            && previous.animationRole === next.animationRole
            && previous.fullHeight === next.fullHeight
            && previous.estimatedHeight === next.estimatedHeight;
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

    function reconcileChanges(rows, changes) {
        const targetKeys = makeTargetKeySet(rows);
        const movement = movementMetadata(changes);

        for (let i = 0; i < changes.removed.length; i += 1) {
            const removal = changes.removed[i];
            const index = indexOfKey(removal.key);
            if (index >= 0)
                markLeaving(index, removal);
        }

        for (let i = 0; i < rows.length; i += 1) {
            const row = rows[i];
            const existingIndex = indexOfKey(row.key);
            const metadata = {
                movementKind: movement.kindByKey[row.key] || "stationary",
                contentChanged: movement.updatedKeys[row.key] === true
            };

            if (existingIndex >= 0)
                setTargetPresent(existingIndex, row, i, metadata);
            else
                insertTargetItem(row, i);
        }

        for (let i = visualModel.count - 1; i >= 0; i -= 1) {
            const item = visualModel.get(i);
            if (targetKeys[item.key] || item.phase === "leaving")
                continue;
            markLeaving(i, { key: item.key, index: item.rank, fallback: true });
        }

        scheduleLeavingRemoval();
    }

    function movementMetadata(changes) {
        const kindByKey = {};
        const updatedKeys = {};
        let i;

        for (i = 0; i < (changes.displaced || []).length; i += 1)
            kindByKey[String(changes.displaced[i].key)] = "displaced";
        for (i = 0; i < (changes.reordered || []).length; i += 1)
            kindByKey[String(changes.reordered[i].key)] = "reorder";
        for (i = 0; i < (changes.updated || []).length; i += 1)
            updatedKeys[String(changes.updated[i].key)] = true;

        return {
            kindByKey: kindByKey,
            updatedKeys: updatedKeys
        };
    }

    function makeLiveItem(row, rank, initialY) {
        const full = row.fullHeight || row.estimatedHeight || root.estimatedRowHeight;
        return {
            key: row.key,
            payload: row.payload,
            rank: rank,
            previousRank: rank,
            targetRank: rank,
            zValue: zValueForMovement(rank, "stationary", rank),
            phase: "live",
            movementKind: "stationary",
            contentChanged: false,
            leaveDeadline: 0,
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

    function setTargetPresent(index, row, rank, metadata) {
        const current = visualModel.get(index);
        const measured = positiveOr(current.measuredHeight, row.fullHeight || row.estimatedHeight || root.estimatedRowHeight);
        const wasLeaving = current.phase === "leaving";
        const movementKind = wasLeaving ? "resurrect" : (metadata.movementKind || "stationary");
        const nextPhase = current.phase === "entering" && !wasLeaving ? "entering" : "live";

        clearRecentlyRemoved(row.key);

        visualModel.setProperty(index, "payload", row.payload);
        visualModel.setProperty(index, "previousRank", current.rank);
        visualModel.setProperty(index, "rank", rank);
        visualModel.setProperty(index, "targetRank", rank);
        visualModel.setProperty(index, "phase", nextPhase);
        visualModel.setProperty(index, "movementKind", movementKind);
        visualModel.setProperty(index, "contentChanged", metadata.contentChanged === true);
        visualModel.setProperty(index, "leaveDeadline", 0);
        visualModel.setProperty(index, "animationRole", row.animationRole || "");
        visualModel.setProperty(index, "targetHeight", measured);
        visualModel.setProperty(index, "targetOpacity", 1);
        visualModel.setProperty(index, "targetScale", 1);

        if (nextPhase !== "entering")
            visualModel.setProperty(index, "visualHeight", measured);

        visualModel.setProperty(index, "zValue", zValueForMovement(rank, movementKind, current.rank));

        if (wasLeaving) {
            recordOperation("resurrect", {
                key: row.key,
                from: current.rank,
                to: rank
            });
        } else if (movementKind !== "stationary") {
            recordOperation(movementKind, {
                key: row.key,
                from: current.rank,
                to: rank
            });
        }

        if (metadata.contentChanged === true)
            recordOperation("update", { key: row.key, at: rank });
    }

    function insertTargetItem(row, rank) {
        const insertIndex = insertionIndexForRank(rank);
        const y = insertionYForRank(rank);
        const full = row.fullHeight || row.estimatedHeight || root.estimatedRowHeight;
        const entering = root.animationMode !== TransitionPolicy.Mode.None;

        visualModel.insert(insertIndex, {
            key: row.key,
            payload: row.payload,
            rank: rank,
            previousRank: -1,
            targetRank: rank,
            zValue: zValueForMovement(rank, "insert", -1),
            phase: entering ? "entering" : "live",
            movementKind: "insert",
            contentChanged: false,
            leaveDeadline: 0,
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
                if (idx < 0 || visualModel.get(idx).phase === "leaving")
                    return;

                visualModel.setProperty(idx, "targetOpacity", 1);
                visualModel.setProperty(idx, "targetScale", 1);
                visualModel.setProperty(idx, "targetHeight", positiveOr(visualModel.get(idx).measuredHeight, full));
                visualModel.setProperty(idx, "visualHeight", positiveOr(visualModel.get(idx).measuredHeight, full));
                recomputeTargets();
            });
        }
    }

    function markLeaving(index, removal) {
        const item = visualModel.get(index);
        if (!item || item.phase === "leaving")
            return;

        rememberRecentlyRemoved(item.key);
        visualModel.setProperty(index, "previousRank", item.rank);
        visualModel.setProperty(index, "phase", "leaving");
        visualModel.setProperty(index, "movementKind", "remove");
        visualModel.setProperty(index, "contentChanged", false);
        visualModel.setProperty(index, "leaveDeadline", Date.now() + transitionPolicy.removalDelay(root.animationMode) + 80);
        visualModel.setProperty(index, "targetOpacity", 0);
        visualModel.setProperty(index, "targetScale", 0.98);
        visualModel.setProperty(index, "targetHeight", 0);
        visualModel.setProperty(index, "visualHeight", 0);
        visualModel.setProperty(index, "zValue", -1);

        recordOperation("remove", {
            key: item.key,
            from: removal && removal.index !== undefined ? removal.index : item.rank,
            fallback: !!(removal && removal.fallback)
        });
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

            visualModel.setProperty(
                idx,
                "zValue",
                zValueForMovement(order, item.movementKind || "stationary", item.previousRank)
            );
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
            if (visualModel.get(idx).phase !== "entering")
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
        const now = Date.now();
        let nextDelay = -1;

        for (let i = 0; i < visualModel.count; i += 1) {
            const item = visualModel.get(i);
            if (item.phase !== "leaving")
                continue;

            const deadline = numberOr(item.leaveDeadline, now);
            const remaining = Math.max(1, deadline - now);
            if (nextDelay < 0 || remaining < nextDelay)
                nextDelay = remaining;
        }

        if (nextDelay < 0) {
            root._leavingRemovalTimer.stop();
            return;
        }

        root._leavingRemovalTimer.interval = nextDelay;
        root._leavingRemovalTimer.restart();
    }

    function scheduleSettling() {
        for (let i = 0; i < visualModel.count; i += 1) {
            const item = visualModel.get(i);
            if (item.phase === "entering"
                    || (item.phase !== "leaving" && item.movementKind !== "stationary")
                    || item.contentChanged) {
                root._settleTimer.restart();
                return;
            }
        }
    }

    function settleRows() {
        for (let i = 0; i < visualModel.count; i += 1) {
            const item = visualModel.get(i);
            if (item.phase === "leaving")
                continue;

            if (item.phase === "entering") {
                const settledHeight = positiveOr(item.measuredHeight, root.estimatedRowHeight);
                visualModel.setProperty(i, "phase", "live");
                visualModel.setProperty(i, "targetHeight", settledHeight);
                visualModel.setProperty(i, "visualHeight", settledHeight);
            }
            visualModel.setProperty(i, "previousRank", item.rank);
            visualModel.setProperty(i, "movementKind", "stationary");
            visualModel.setProperty(i, "contentChanged", false);
            visualModel.setProperty(i, "zValue", zValueForMovement(item.rank, "stationary", item.rank));
        }
    }

    function removeSettledLeavingRows() {
        const now = Date.now();

        for (let i = visualModel.count - 1; i >= 0; i -= 1) {
            const item = visualModel.get(i);
            if (item.phase === "leaving" && numberOr(item.leaveDeadline, 0) <= now)
                visualModel.remove(i);
        }

        recomputeTargets();
        recomputeHasActiveItems();
        scheduleLeavingRemoval();
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
        if (item.nodeId)
            return String(item.nodeId);
        return "";
    }

    function indexOfKey(key) {
        for (let i = 0; i < visualModel.count; i += 1) {
            if (String(visualModel.get(i).key) === String(key))
                return i;
        }
        return -1;
    }

    function zValueForMovement(rank, movementKind, previousRank) {
        if (movementKind === "reorder" || movementKind === "resurrect")
            return 30000 - rank;
        if (movementKind === "insert")
            return 20000 - rank;
        if (movementKind === "displaced")
            return 10000 - rank;
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
        root.projectionRevision = -1;
    }

    function resetModel() {
        root._leavingRemovalTimer.stop();
        root._settleTimer.stop();
        visualModel.clear();
        root._snapshotRows = [];
        root.lastChangeSet = SnapshotDiff.empty();
        root.lastChangeSummary = root.lastChangeSet.summary;
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
            "changes", JSON.stringify(root.lastChangeSummary),
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
                movementKind: item.movementKind,
                contentChanged: item.contentChanged,
                leaveDeadline: item.leaveDeadline,
                rank: item.rank,
                previousRank: item.previousRank,
                targetRank: item.targetRank
            });
        }

        return {
            snapshotSerial: root.snapshotSerial,
            projectionRevision: root.projectionRevision,
            query: root.snapshotQuery,
            queryRevision: root.snapshotQueryRevision,
            generation: root.snapshotGeneration,
            animationMode: root.animationMode,
            debugEnabled: root.debugEnabled,
            modelCount: visualModel.count,
            contentHeight: root.contentHeight,
            rows: rows,
            changeSummary: root.lastChangeSummary,
            lastOperations: root.lastOperations,
            recentlyRemovedKeys: recentlyRemoved,
            metrics: extra || {}
        };
    }
}
