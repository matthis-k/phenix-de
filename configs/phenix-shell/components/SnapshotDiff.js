.pragma library

function empty() {
    return {
        changed: false,
        inserted: [],
        removed: [],
        updated: [],
        moved: [],
        reordered: [],
        displaced: [],
        retained: [],
        operations: [],
        summary: {
            inserted: 0,
            removed: 0,
            updated: 0,
            moved: 0,
            reordered: 0,
            displaced: 0,
            retained: 0
        }
    };
}

function sameValue(a, b) {
    return a === b || (typeof a === "number" && typeof b === "number" && isNaN(a) && isNaN(b));
}

function shallowEqual(a, b) {
    if (sameValue(a, b))
        return true;
    if (!a || !b || typeof a !== "object" || typeof b !== "object")
        return false;
    if (Array.isArray(a) || Array.isArray(b))
        return false;

    var aKeys = Object.keys(a);
    var bKeys = Object.keys(b);
    if (aKeys.length !== bKeys.length)
        return false;

    for (var i = 0; i < aKeys.length; i += 1) {
        var key = aKeys[i];
        if (!Object.prototype.hasOwnProperty.call(b, key) || !sameValue(a[key], b[key]))
            return false;
    }
    return true;
}

function fields(previous, next, equals) {
    var before = previous && typeof previous === "object" ? previous : {};
    var after = next && typeof next === "object" ? next : {};
    var compare = typeof equals === "function" ? equals : sameValue;
    var result = empty();
    var seen = {};
    var key;

    for (key in before) {
        if (!Object.prototype.hasOwnProperty.call(before, key))
            continue;
        seen[key] = true;
        if (!Object.prototype.hasOwnProperty.call(after, key)) {
            result.removed.push({ key: key, previous: before[key] });
            result.operations.push({ type: "remove-field", key: key, previous: before[key] });
        } else if (!compare(before[key], after[key])) {
            result.updated.push({ key: key, previous: before[key], next: after[key] });
            result.operations.push({ type: "update-field", key: key, previous: before[key], next: after[key] });
        } else {
            result.retained.push({ key: key, value: after[key] });
        }
    }

    for (key in after) {
        if (!Object.prototype.hasOwnProperty.call(after, key) || seen[key])
            continue;
        result.inserted.push({ key: key, next: after[key] });
        result.operations.push({ type: "insert-field", key: key, next: after[key] });
    }

    return finish(result);
}

function keyed(previous, next, keyOf, equals) {
    if (typeof keyOf !== "function")
        throw new Error("SnapshotDiff.keyed requires keyOf(item, index)");

    var before = Array.isArray(previous) ? previous : [];
    var after = Array.isArray(next) ? next : [];
    var compare = typeof equals === "function" ? equals : shallowEqual;
    var beforeIndex = buildIndex(before, keyOf, "previous");
    var afterIndex = buildIndex(after, keyOf, "next");
    var result = empty();
    var retainedInTargetOrder = [];
    var i;

    for (i = before.length - 1; i >= 0; i -= 1) {
        var oldKey = String(keyOf(before[i], i));
        if (!Object.prototype.hasOwnProperty.call(afterIndex, oldKey)) {
            var removed = { key: oldKey, index: i, item: before[i] };
            result.removed.push(removed);
            result.operations.push({ type: "remove", key: oldKey, from: i, item: before[i] });
        }
    }

    for (i = 0; i < after.length; i += 1) {
        var newKey = String(keyOf(after[i], i));
        if (!Object.prototype.hasOwnProperty.call(beforeIndex, newKey)) {
            var inserted = { key: newKey, index: i, item: after[i] };
            result.inserted.push(inserted);
            result.operations.push({ type: "insert", key: newKey, to: i, item: after[i] });
            continue;
        }

        var oldEntry = beforeIndex[newKey];
        var retained = {
            key: newKey,
            from: oldEntry.index,
            to: i,
            previous: oldEntry.item,
            next: after[i]
        };
        result.retained.push(retained);
        retainedInTargetOrder.push(retained);

        if (!compare(oldEntry.item, after[i])) {
            result.updated.push(retained);
            result.operations.push({
                type: "update",
                key: newKey,
                at: i,
                previous: oldEntry.item,
                next: after[i]
            });
        }
    }

    classifyMovements(result, retainedInTargetOrder);
    return finish(result);
}

function classifyMovements(result, retainedInTargetOrder) {
    if (!retainedInTargetOrder.length)
        return;

    var previousIndexes = retainedInTargetOrder.map(function(entry) { return entry.from; });
    var stablePositions = longestIncreasingSubsequencePositionSet(previousIndexes);

    for (var i = 0; i < retainedInTargetOrder.length; i += 1) {
        var entry = retainedInTargetOrder[i];
        if (entry.from === entry.to)
            continue;

        var movement = {
            key: entry.key,
            from: entry.from,
            to: entry.to,
            previous: entry.previous,
            next: entry.next,
            movement: stablePositions[i] ? "displaced" : "reorder"
        };

        result.moved.push(movement);
        if (movement.movement === "reorder")
            result.reordered.push(movement);
        else
            result.displaced.push(movement);

        result.operations.push({
            type: movement.movement,
            key: movement.key,
            from: movement.from,
            to: movement.to
        });
    }
}

function longestIncreasingSubsequencePositionSet(values) {
    var tails = [];
    var tailPositions = [];
    var previousPositions = new Array(values.length);

    for (var i = 0; i < values.length; i += 1) {
        var value = values[i];
        var low = 0;
        var high = tails.length;

        while (low < high) {
            var middle = Math.floor((low + high) / 2);
            if (tails[middle] < value)
                low = middle + 1;
            else
                high = middle;
        }

        tails[low] = value;
        previousPositions[i] = low > 0 ? tailPositions[low - 1] : -1;
        tailPositions[low] = i;
    }

    var result = {};
    if (!tailPositions.length)
        return result;

    var position = tailPositions[tailPositions.length - 1];
    while (position >= 0) {
        result[position] = true;
        position = previousPositions[position];
    }
    return result;
}

function buildIndex(items, keyOf, label) {
    var index = {};
    for (var i = 0; i < items.length; i += 1) {
        var rawKey = keyOf(items[i], i);
        if (rawKey === null || rawKey === undefined || String(rawKey) === "")
            throw new Error("SnapshotDiff: " + label + " item at index " + i + " has no stable key");
        var key = String(rawKey);
        if (Object.prototype.hasOwnProperty.call(index, key))
            throw new Error("SnapshotDiff: duplicate " + label + " key '" + key + "'");
        index[key] = { index: i, item: items[i] };
    }
    return index;
}

function finish(result) {
    result.summary = {
        inserted: result.inserted.length,
        removed: result.removed.length,
        updated: result.updated.length,
        moved: result.moved.length,
        reordered: result.reordered.length,
        displaced: result.displaced.length,
        retained: result.retained.length
    };
    result.changed = result.inserted.length > 0
        || result.removed.length > 0
        || result.updated.length > 0
        || result.moved.length > 0;
    return result;
}
