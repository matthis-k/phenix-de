pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.services

Singleton {
    id: root

    readonly property var tracer: Logger.scope("hyprland.service", { category: "hyprland" })
    readonly property var prof: Profiler.scope("hyprland.service", { category: "hyprland" })

    readonly property var backend: Hyprland

    readonly property int visualOrderNatural: 0
    readonly property int visualOrderColumnMajor: 1
    readonly property int visualOrderLayoutExport: 2

    property int defaultToplevelOrder: root.visualOrderColumnMajor
    property real columnOverlapThreshold: 0.5

    property int revision: 0

    function refresh(): void {
        root.tracer.info("refresh");
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
        root.revision++;
    }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() { root.revision++; }
        function onFocusedMonitorChanged() { root.revision++; }
        function onActiveToplevelChanged() { root.revision++; }
    }

    readonly property var monitors: Hyprland.monitors.values || []
    readonly property var workspaces: Hyprland.workspaces.values || []
    readonly property var toplevels: Hyprland.toplevels.values || []

    readonly property var focusedMonitor: Hyprland.focusedMonitor
    readonly property var focusedWorkspace: Hyprland.focusedWorkspace

    function monitorFor(screen: var): var {
        return Hyprland.monitorFor(screen);
    }

    function workspacesForScreen(screen: var, rev: int): var {
        const mon = Hyprland.monitorFor(screen);
        if (!mon)
            return [];
        const result = [...Hyprland.workspaces.values]
            .filter(ws => ws.monitor && ws.monitor.name === mon.name)
            .sort((a, b) => workspaceNumber(a) - workspaceNumber(b));
        return result;
    }

    function workspaceNumber(workspace: var): int {
        const id = Number(workspace?.id);
        if (Number.isFinite(id) && id > 0)
            return id;
        const name = Number.parseInt(workspace?.name || "", 10);
        return Number.isFinite(name) ? name : Number.MAX_SAFE_INTEGER;
    }

    function normalizeWorkspace(workspace: var): var {
        if (!workspace)
            return null;
        return {
            id: workspaceNumber(workspace),
            name: workspace.name,
            number: workspaceNumber(workspace),
            active: Hyprland.focusedWorkspace?.id === workspace.id,
            monitorName: workspace.monitor ? workspace.monitor.name : "",
            urgent: workspace.urgent || false,
            special: workspace.special || false,
            rawId: workspace.id
        };
    }

    function normalizeToplevel(toplevel: var): var {
        if (!toplevel)
            return null;
        const geo = toplevel.wayland ? {
            x: toplevel.wayland.x,
            y: toplevel.wayland.y,
            width: toplevel.wayland.width,
            height: toplevel.wayland.height,
            centerX: toplevel.wayland.x + toplevel.wayland.width / 2,
            centerY: toplevel.wayland.y + toplevel.wayland.height / 2
        } : { x: 0, y: 0, width: 0, height: 0, centerX: 0, centerY: 0 };

        return {
            id: toplevel.address || "",
            title: toplevel.title || toplevel.wayland?.title || "",
            active: toplevel.activated && Hyprland.focusedWorkspace?.id === toplevel?.workspace?.id,
            floating: toplevel.floating || false,
            fullscreen: toplevel.fullscreen || false,
            workspaceId: toplevel.workspace ? toplevel.workspace.id : 0,
            geometry: geo
        };
    }

    function rawWorkspaceById(id: var): var {
        id = Number(id);
        for (const ws of Hyprland.workspaces.values || []) {
            if (ws.id === id)
                return ws;
        }
        return null;
    }

    function rawToplevelById(id: var): var {
        for (const tl of Hyprland.toplevels.values || []) {
            if (tl.address === id || tl.wayland?.id === id)
                return tl;
        }
        return null;
    }

    function activateWorkspace(id: var): void {
        const ws = rawWorkspaceById(id);
        if (ws && ws.activate) {
            root.tracer.info("activateWorkspace", function() { return { id: id, name: ws.name } });
            ws.activate();
        } else {
            root.tracer.warn("activateWorkspace.notFound", function() { return { id: id } });
        }
    }

    function activateToplevel(id: var): void {
        const tl = rawToplevelById(id);
        if (tl && tl.wayland && tl.wayland.activate) {
            root.tracer.info("activateToplevel", function() { return { id: id, title: tl.title } });
            tl.wayland.activate();
        } else {
            root.tracer.warn("activateToplevel.notFound", function() { return { id: id } });
        }
    }

    function closeToplevel(id: var): void {
        const tl = rawToplevelById(id);
        if (tl && tl.wayland && tl.wayland.close) {
            root.tracer.info("closeToplevel", function() { return { id: id, title: tl.title } });
            tl.wayland.close();
        } else {
            root.tracer.warn("closeToplevel.notFound", function() { return { id: id } });
        }
    }

    function findMatchingColumn(columns: var, entry: var): var {
        let best = null;
        let bestOverlap = 0;

        const left = entry.geometry.x;
        const right = entry.geometry.x + entry.geometry.width;
        const width = Math.max(1, entry.geometry.width);

        for (const column of columns) {
            const overlap = Math.max(0, Math.min(right, column.maxX) - Math.max(left, column.minX));
            const overlapRatio = overlap / width;

            if (overlapRatio > bestOverlap) {
                bestOverlap = overlapRatio;
                best = column;
            }
        }

        const result = bestOverlap >= root.columnOverlapThreshold ? best : null;
        root.tracer.trace("findMatchingColumn", function() { return { entry: entry.id, columns: columns.length, matched: !!result, overlap: bestOverlap } });
        return result;
    }

    function toplevelsForWorkspace(workspace: var, orderMode: int): var {
        const _ = root.revision;
        if (orderMode === undefined || orderMode === null)
            orderMode = root.defaultToplevelOrder;

        if (orderMode === root.visualOrderNatural) {
            const result = [];
            const toplevels = [];
            for (let i = 0; workspace?.toplevels && i < workspace.toplevels.length; ++i)
                toplevels.push(workspace.toplevels[i]);
            for (const tl of toplevels) {
                const entry = root.normalizeToplevel(tl);
                if (entry)
                    result.push(entry);
            }
            return result;
        }

        if (orderMode === root.visualOrderColumnMajor || orderMode === root.visualOrderLayoutExport) {
            return root.orderedColumnMajor(workspace);
        }

        return [];
    }

    function orderedToplevelsForWorkspace(workspace: var, rev: int): var {
        if (!workspace) {
            print("HyprlandService: orderedToplevelsForWorkspace called with null workspace");
            return [];
        }
        return root.toplevelsForWorkspace(workspace, root.defaultToplevelOrder);
    }

    function orderedColumnMajor(workspace: var): var {
        const tiled = [];
        const floating = [];

        const toplevels = [];
        for (let i = 0; workspace?.toplevels && i < workspace.toplevels.length; ++i)
            toplevels.push(workspace.toplevels[i]);

        for (const tl of toplevels) {
            const entry = root.normalizeToplevel(tl);
            if (!entry)
                continue;

            if (entry.floating) {
                floating.push(entry);
            } else {
                tiled.push(entry);
            }
        }

        if (tiled.length === 0)
            return floating;

        const columns = [];

        for (const entry of tiled) {
            const col = root.findMatchingColumn(columns, entry);
            if (col) {
                col.entries.push(entry);
                col.minX = Math.min(col.minX, entry.geometry.x);
                col.maxX = Math.max(col.maxX, entry.geometry.x + entry.geometry.width);
                col.minY = Math.min(col.minY, entry.geometry.y);
                col.maxY = Math.max(col.maxY, entry.geometry.y + entry.geometry.height);
            } else {
                columns.push({
                    entries: [entry],
                    minX: entry.geometry.x,
                    maxX: entry.geometry.x + entry.geometry.width,
                    minY: entry.geometry.y,
                    maxY: entry.geometry.y + entry.geometry.height
                });
            }
        }

        columns.sort((a, b) => a.minX - b.minX || a.minY - b.minY);

        for (const col of columns) {
            col.entries.sort((a, b) => {
                const yDiff = a.geometry.y - b.geometry.y;
                if (yDiff !== 0)
                    return yDiff;
                const xDiff = a.geometry.x - b.geometry.x;
                if (xDiff !== 0)
                    return xDiff;
                const wsDiff = (a.workspaceId || 0) - (b.workspaceId || 0);
                if (wsDiff !== 0)
                    return wsDiff;
                return String(a.id).localeCompare(String(b.id));
            });
        }

        const result = [];
        for (const col of columns) {
            for (const entry of col.entries)
                result.push(entry);
        }

        for (const entry of floating)
            result.push(entry);

        return result;
    }
}
