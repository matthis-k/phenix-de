pragma Singleton
import QtQml
import Quickshell
import qs.services

Singleton {
    readonly property var prof: Profiler.scope("launcher.rows", { category: "launcher" })
    readonly property var tracer: Logger.scope("launcher.rows", { category: "launcher" })
    function isContextOnly(row) {
        return !!(row
            && row.semantics
            && row.semantics.representation
            && row.semantics.representation.retainParent === false);
    }

    function hasActivation(row) {
        if (!row || isContextOnly(row))
            return false;
        return !!(row.actions && row.actions.length > 0 || row.hasAction || row.canExecuteNow || row.executable || row.switchActions || row.control || row.expandable || (row.children && row.children.length > 0));
    }

    function isSelectable(row, queryInfo) {
        var queryIsEmpty = queryInfo && queryInfo.isEmpty !== undefined ? !!queryInfo.isEmpty : false;
        return hasActivation(row) && (queryIsEmpty || (row.ownScore || 0) > 0 || !!row.ownVisible);
    }

    function hasSelectableDescendant(row, queryInfo) {
        return (row.children || []).some(function(child) { return isSelectable(child, queryInfo) || hasSelectableDescendant(child, queryInfo); });
    }

    function selectableRows(rows, queryInfo) {
        return (rows || []).filter(function(row) { return isSelectable(row, queryInfo) || hasSelectableDescendant(row, queryInfo); });
    }

    function shiftRowDepth(row, delta) {
        var out = Object.assign({}, row, { depth: Math.max(0, (row.depth || 0) + delta) });
        if (row.children && row.children.length)
            out.children = row.children.map(function(child) { return shiftRowDepth(child, delta); });
        return out;
    }

    function promoteContainerRows(rows, queryInfo) {
        var out = [];
        for (var i = 0; i < (rows || []).length; i += 1) {
            var row = rows[i];
            var children = row && row.children || [];
            var contextOnly = isContextOnly(row);
            if (row && (!isSelectable(row, queryInfo) || contextOnly) && children.length > 0) {
                var promoted = promoteContainerRows(children, queryInfo);
                for (var pi = 0; pi < promoted.length; pi += 1)
                    out.push(shiftRowDepth(promoted[pi], (row.depth || 0) - (promoted[pi].depth || 0)));
                continue;
            }
            if (row && children.length > 0)
                row = Object.assign({}, row, { children: promoteContainerRows(children, queryInfo) });
            if (row)
                out.push(row);
        }
        return out;
    }

    function dropInertRows(rows) {
        var out = [];
        for (var i = 0; i < (rows || []).length; i += 1) {
            var row = rows[i];
            if (!row)
                continue;
            var children = dropInertRows(row.children || []);
            var hasVisibleChildren = children.length > 0;
            if (children.length !== (row.children || []).length)
                row = Object.assign({}, row, { children: children, expandable: children.length > 0 });
            // Keep rows that have activation, have visible children, or are expandable
            // (expandable means they had children at row construction time, even if not currently visible).
            // This prevents dropping non-trailing-space parent groups like Phenix.
            if (!hasActivation(row) && !hasVisibleChildren && !row.expandable)
                continue;
            out.push(row);
        }
        return out;
    }

    function structuralDepth(row) {
        return (row && row.breadcrumbs && row.breadcrumbs.length) || 0;
    }

    function effectiveMatchDepth(row) {
        if (!row)
            return 0;
        if (row.matchDepth !== undefined && row.matchDepth < 9999)
            return (row.depth || 0) + row.matchDepth;
        var ownScore = row.ownScore || 0;
        var children = row.children || [];
        var bestChildScore = 0;
        for (var i = 0; i < children.length; i += 1)
            bestChildScore = Math.max(bestChildScore, children[i].score || 0);
        if (bestChildScore > 0 && bestChildScore >= ownScore) {
            var bestDepth = 9999;
            for (var ci = 0; ci < children.length; ci += 1) {
                if (Math.abs((children[ci].score || 0) - bestChildScore) <= 0.0001)
                    bestDepth = Math.min(bestDepth, effectiveMatchDepth(children[ci]));
            }
            if (bestDepth < 9999)
                return bestDepth;
        }
        return row.depth || 0;
    }

    function sortRows(rows, queryInfo, directiveInfo) {
        if (directiveInfo && directiveInfo.active && queryInfo && queryInfo.isEmpty)
            return (rows || []).slice();
        return (rows || []).slice().sort(function(a, b) {
            var scoreDelta = (b.score || 0) - (a.score || 0);
            if (Math.abs(scoreDelta) > 0.0001) return scoreDelta;
            var switchDelta = (b.switchState !== null && b.switchState !== undefined ? 1 : 0) - (a.switchState !== null && a.switchState !== undefined ? 1 : 0);
            if (switchDelta !== 0) return switchDelta;
            var structuralDepthDelta = structuralDepth(a) - structuralDepth(b);
            if (structuralDepthDelta !== 0) return structuralDepthDelta;
            return effectiveMatchDepth(a) - effectiveMatchDepth(b);
        });
    }

    function findWordBoundaryMatch(text, token, startFrom) {
        if (startFrom === undefined) startFrom = 0;
        var idx = startFrom;
        while ((idx = text.indexOf(token, idx)) >= 0) {
            if (idx === 0) return idx;
            var prev = text[idx - 1];
            if (prev === " " || prev === "-" || prev === "_") return idx;
            idx += 1;
        }
        return -1;
    }

    function filterRowChildren(row, queryTokens) {
        if (!row || !row.filterChildren || !row.children || !queryTokens || queryTokens.length === 0)
            return;
        var parentTitle = (row.title || "").toLowerCase();
        var consumedParentPos = {};
        var consumedChildIdx = {};

        for (var ti = 0; ti < queryTokens.length; ti += 1) {
            var token = queryTokens[ti];
            var matched = false;
            var searchPos = 0;
            while (!matched) {
                var pos = findWordBoundaryMatch(parentTitle, token, searchPos);
                if (pos < 0) break;
                if (!consumedParentPos[pos]) {
                    consumedParentPos[pos] = true;
                    matched = true;
                    break;
                }
                searchPos = pos + 1;
            }
            if (matched) continue;

            for (var ci = 0; ci < row.children.length; ci += 1) {
                var childText = ((row.children[ci].title || "") + " " + (row.children[ci].subtitle || "")).toLowerCase();
                if (findWordBoundaryMatch(childText, token) >= 0) {
                    consumedChildIdx[String(ci)] = true;
                    matched = true;
                }
            }
        }

        var hasChildMatch = false;
        for (var key in consumedChildIdx) {
            hasChildMatch = true;
            break;
        }
        if (hasChildMatch) {
            var keep = consumedChildIdx;
            row.children = row.children.filter(function(child, idx) { return keep[String(idx)]; });
        }
    }

    function filterChildrenByQuery(rows, queryInfo) {
        var tokenStrs = (queryInfo && queryInfo.tokens || []).map(function(token) { return token.normalized; }).filter(Boolean);
        for (var i = 0; i < (rows || []).length; i += 1)
            filterRowChildren(rows[i], tokenStrs);
        return rows || [];
    }

    function _finalizeRows(rows, queryInfo, directiveInfo, options) {
        options = options || {};
        tracer.trace("finalizeRows", function() { return { rowCount: (rows || []).length, queryEmpty: !!(queryInfo && queryInfo.isEmpty), directiveActive: !!(directiveInfo && directiveInfo.active) }; });
        var out = (rows || []).slice();
        if (options.filterRowChildren)
            out = filterChildrenByQuery(out, queryInfo);
        if (options.promoteContainerRows !== false)
            out = promoteContainerRows(out, queryInfo);
        if (options.dropInertRows !== false)
            out = dropInertRows(out);
        if (options.onlySelectable)
            out = selectableRows(out, queryInfo);
        if (options.sortRows !== false)
            out = sortRows(out, queryInfo, directiveInfo);
        return out;
    }

    readonly property var finalizeRows: prof.fn("finalizeRows", _finalizeRows)
}
