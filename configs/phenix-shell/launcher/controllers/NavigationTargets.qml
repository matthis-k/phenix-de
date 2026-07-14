import QtQml
import qs.services

QtObject {
    readonly property var tracer: Logger.scope("launcher.navTargets", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.navTargets", { category: "launcher" })
    id: root

    property var controller: null

    function rowKey(row) {
        return row ? row.id || row.nodeId || "" : "";
    }

    function walkRows(rows, visitor) {
        function visit(row, parentIndex, depth, path) {
            if (!row) return false;
            var key = root.rowKey(row);
            var currentPath = path.concat([key]);
            if (visitor(row, parentIndex, depth, currentPath) === false)
                return false;
            var children = row.children || [];
            for (var i = 0; i < children.length; i += 1) {
                if (visit(children[i], parentIndex, depth + 1, currentPath) === false)
                    return false;
            }
            return true;
        }

        for (var i = 0; i < (rows || []).length; i += 1) {
            if (visit(rows[i], i, 0, []) === false)
                return;
        }
    }

    function findRowByKey(rows, key) {
        var found = null;
        root.walkRows(rows || [], function(row) {
            if (root.rowKey(row) === key) {
                found = row;
                return false;
            }
            return true;
        });
        return found;
    }

    function findParentResultByKey(results, key) {
        for (var i = 0; i < results.length; i += 1) {
            if (root.findRowByKey([results[i]], key))
                return results[i];
        }
        return null;
    }

    function _flatten(results, collapsedState, selectable) {
        var out = [];
        function visit(row, parentIndex, depth, path) {
            if (!row) return;
            var children = row.children || [];
            var key = root.rowKey(row);
            var currentPath = path.concat([key]);
            var isExpanded = row.alwaysExpanded !== false;
            if (selectable(row))
                out.push({ key: key, row: row, parentIndex: parentIndex, depth: depth, treeDepth: depth, path: currentPath, isTreeChild: depth > 0 });
            if (!isExpanded || collapsedState[parentIndex])
                return;
            for (var i = 0; i < children.length; i += 1)
                visit(children[i], parentIndex, depth + 1, currentPath);
        }
        for (var i = 0; i < (results || []).length; i += 1)
            visit(results[i], i, 0, []);
        tracer.debug("flatten", function() { return { results: (results || []).length, targets: out.length, collapsedKeys: Object.keys(collapsedState).length }; });
        return out;
    }

    readonly property var flatten: prof.fn("flatten", _flatten)

    function stepTarget(targets, currentKey, delta) {
        if (!targets || targets.length === 0)
            return null;
        var current = targets.findIndex(function(target) { return target.key === currentKey; });
        if (current < 0)
            current = 0;
        var next = (current + delta + targets.length) % targets.length;
        return targets[next];
    }

    function findInChildren(row, key) {
        return key ? root.findRowByKey(row ? [row] : [], key) : null;
    }
}
