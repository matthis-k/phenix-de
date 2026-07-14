pragma Singleton
import QtQml
import Quickshell

Singleton {
    function forShapedItem(ev, shapedItem, parentContext) {
        if (!shapedItem) return emptyContext();

        var placement = shapedItem.placement || "standalone";
        var decision = shapedItem.decision || {};
        var hints = shapedItem.presentationHints || {};

        var parentShown = parentContext ? parentContext.parentShown : false;
        var ancestorsShown = parentContext ? parentContext.ancestorsShown : false;
        var chain = dedupeAdjacent(collectChain(ev));

        var showBreadcrumbs = decideBreadcrumbVisibility(placement, decision, hints, chain);
        var showBackendBadge = decideBackendBadge(placement, decision);
        var showActionHint = decideActionHint(placement, decision);
        var density = hints.density || "normal";

        var breadcrumbs = buildBreadcrumbs(ev, chain, placement);
        var breadcrumbText = showBreadcrumbs ? breadcrumbs.join(" > ") : "";

        return {
            placement: placement,
            parentShown: parentShown,
            ancestorsShown: ancestorsShown,
            showBreadcrumbs: showBreadcrumbs,
            showBackendBadge: showBackendBadge,
            showActionHint: showActionHint,
            density: density,
            breadcrumbs: breadcrumbs,
            breadcrumbText: breadcrumbText
        };
    }

    function emptyContext() {
        return {
            placement: "standalone",
            parentShown: false,
            ancestorsShown: false,
            showBreadcrumbs: false,
            showBackendBadge: false,
            showActionHint: false,
            density: "normal",
            breadcrumbs: [],
            breadcrumbText: ""
        };
    }

    function decideBreadcrumbVisibility(placement, decision, hints, chain) {
        if (hints.breadcrumbMode === "hidden") return false;
        if (hints.breadcrumbMode === "always") return true;

        switch (placement) {
        case "group-child": return false;
        case "group": return false;
        case "nested-group": return false;
        case "filtered-group": return false;
        case "promoted-child": return chain.length > 0;
        case "flattened": return chain.length > 0;
        case "standalone": return chain.length > 1;
        default: return false;
        }
    }

    function decideBackendBadge(placement, decision) {
        if (decision && decision.hideBackendBadge) return false;
        return placement === "standalone" || placement === "promoted-child" || placement === "flattened";
    }

    function decideActionHint(placement, decision) {
        if (decision && decision.hideActionHint) return false;
        return placement !== "group-child" && placement !== "group";
    }

    function collectChain(ev) {
        if (!ev || !ev.node) return [];
        var chain = [];
        var node = ev.node;
        while (node && node.kind !== "root") {
            chain.unshift(node.label || node.id || "");
            node = node.parent;
        }
        return chain;
    }

    function buildBreadcrumbs(ev, chain, placement) {
        if (!chain.length) return [];
        if (placement === "standalone" && chain.length <= 1) return [];

        var br = chain.slice();
        if (br.length > 0) br.pop();
        return dedupeAdjacent(br);
    }

    function dedupeAdjacent(items) {
        var out = [];
        for (var i = 0; i < (items || []).length; i += 1) {
            if (out.length > 0 && out[out.length - 1] === items[i])
                continue;
            out.push(items[i]);
        }
        return out;
    }

    function toDebug(ctx) {
        if (!ctx) return null;
        return {
            placement: ctx.placement,
            parentShown: ctx.parentShown,
            ancestorsShown: ctx.ancestorsShown,
            showBreadcrumbs: ctx.showBreadcrumbs,
            showBackendBadge: ctx.showBackendBadge,
            showActionHint: ctx.showActionHint,
            density: ctx.density,
            breadcrumbs: ctx.breadcrumbs,
            breadcrumbText: ctx.breadcrumbText
        };
    }
}
