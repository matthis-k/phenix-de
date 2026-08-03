import QtQml
import "../SnapshotDiff.js" as SnapshotDiff

QtObject {
    function result(ok, label, detail) {
        return { ok: ok, label: label, detail: detail || "" };
    }

    function runAll() {
        return {
            name: "SnapshotDiff",
            results: [
                testInsertionDisplacement(),
                testExplicitReorder(),
                testRemovalDisplacement(),
                testStableOrder()
            ]
        };
    }

    function testInsertionDisplacement() {
        const diff = SnapshotDiff.keyed(["A", "B", "C"], ["X", "A", "B", "C"], function(item) { return item; });
        const ok = diff.inserted.length === 1
            && diff.reordered.length === 0
            && diff.displaced.length === 3;
        return result(ok, "insertion-displacement", JSON.stringify(diff.summary));
    }

    function testExplicitReorder() {
        const diff = SnapshotDiff.keyed(["A", "B", "C"], ["C", "A", "B"], function(item) { return item; });
        const ok = diff.reordered.length === 1
            && diff.reordered[0].key === "C"
            && diff.displaced.length === 2;
        return result(ok, "explicit-reorder", JSON.stringify(diff.summary));
    }

    function testRemovalDisplacement() {
        const diff = SnapshotDiff.keyed(["A", "B", "C"], ["A", "C"], function(item) { return item; });
        const ok = diff.removed.length === 1
            && diff.reordered.length === 0
            && diff.displaced.length === 1
            && diff.displaced[0].key === "C";
        return result(ok, "removal-displacement", JSON.stringify(diff.summary));
    }

    function testStableOrder() {
        const diff = SnapshotDiff.keyed(["A", "B"], ["A", "B"], function(item) { return item; });
        const ok = !diff.changed && diff.moved.length === 0;
        return result(ok, "stable-order", JSON.stringify(diff.summary));
    }
}
