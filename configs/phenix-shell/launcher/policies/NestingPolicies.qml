import QtQml
import qs.services
import "../" as Launcher
import "../logic/"

QtObject {
    readonly property var tracer: Logger.scope("policy.nesting", { category: "policy" })
    readonly property var prof: Profiler.scope("policy.nesting", { category: "policy" })

    Component.onCompleted: {
        Launcher.PolicyRegistry.registerNesting("self-item", function(ev, ctx, args) {
            return {
                decision: {
                    intent: "self-item",
                    includeChildren: "none",
                    childSource: "evaluated-children",
                    retainContext: false,
                    allowVisualTakeover: true
                },
                reasons: [{ code: "self_item", text: "self-item: standalone leaf result" }]
            };
        });

        Launcher.PolicyRegistry.registerNesting("self-group-on-trailing-space", function(ev, ctx, args) {
            var ownMatched = !!(ev && (ev.ownVisible || (ev.ownScore || 0) > 0));
            var trailing = !!(ctx && ctx.query && ctx.query.lastTokenEmpty);
            var residual = (ev && ev.tokenFlow && ev.tokenFlow.passed) ? ev.tokenFlow.passed.length : 0;
            var isBrowse = ownMatched && trailing && residual === 0;
            return {
                decision: {
                    intent: isBrowse ? "self-group" : "self-item",
                    includeChildren: isBrowse ? "all" : "none",
                    childSource: "evaluated-children",
                    retainContext: isBrowse,
                    allowVisualTakeover: !isBrowse
                },
                reasons: [{ code: isBrowse ? "trailing_browse_group" : "not_browse", text: isBrowse ? "self-group-on-trailing-space: trailing browse includes all children" : "self-group-on-trailing-space: not a trailing browse" }]
            };
        });

        Launcher.PolicyRegistry.registerNesting("self-group-with-matching-children", function(ev, ctx, args) {
            var ownMatched = !!(ev && (ev.ownVisible || (ev.ownScore || 0) > 0));
            var trailing = !!(ctx && ctx.query && ctx.query.lastTokenEmpty);
            var residual = (ev && ev.tokenFlow && ev.tokenFlow.passed) ? ev.tokenFlow.passed.length : 0;
            var hasResidualSearch = ownMatched && !trailing && residual > 0;
            return {
                decision: {
                    intent: hasResidualSearch ? "self-group" : "parent-item",
                    includeChildren: hasResidualSearch ? "matching" : "none",
                    childSource: "evaluated-children",
                    retainContext: true,
                    allowVisualTakeover: !hasResidualSearch
                },
                reasons: [{ code: hasResidualSearch ? "residual_group" : "no_residual", text: hasResidualSearch ? "self-group-with-matching-children: " + residual + " residual tokens filter children" : "self-group-with-matching-children: no residual tokens" }]
            };
        });

        Launcher.PolicyRegistry.registerNesting("namespace-dynamic-group", function(ev, ctx, args) {
            var ownMatched = !!(ev && (ev.ownVisible || (ev.ownScore || 0) > 0));
            var trailing = !!(ctx && ctx.query && ctx.query.lastTokenEmpty);
            var residual = (ev && ev.tokenFlow && ev.tokenFlow.passed) ? ev.tokenFlow.passed.length : 0;
            var isBrowse = trailing && residual === 0;
            var hasResidualSearch = !trailing && residual > 0;
            var include;
            if (isBrowse) include = "all";
            else if (hasResidualSearch) include = "matching";
            else include = "none";
            var isGroup = ownMatched && (isBrowse || hasResidualSearch);
            var childInfo = ev && ev.children ? "kids=" + ev.children.length + " vis=" + ev.children.filter(function(c) { return c.visible; }).length + " cand=" + ev.children.filter(function(c) { return c.candidate; }).length : "no-ev-children";
            return {
                decision: {
                    intent: isGroup ? "self-group" : "parent-item",
                    includeChildren: include,
                    childSource: "evaluated-children",
                    retainContext: true,
                    allowVisualTakeover: !isGroup
                },
                reasons: [{ code: isGroup ? (isBrowse ? "trailing_browse_namespace" : "residual_namespace") : "no_group", text: isGroup ? (isBrowse ? "namespace-dynamic-group: trailing browse " + include + " children (" + childInfo + ")" : "namespace-dynamic-group: matching children filtered by residual (" + childInfo + ")") : "namespace-dynamic-group: own match without browse (" + childInfo + ")" }]
            };
        });

        Launcher.PolicyRegistry.registerNesting("desktop-app-actions", function(ev, ctx, args) {
            var ownMatched = !!(ev && (ev.ownVisible || (ev.ownScore || 0) > 0));
            var trailing = !!(ctx && ctx.query && ctx.query.lastTokenEmpty);
            var residual = (ev && ev.tokenFlow && ev.tokenFlow.passed) ? ev.tokenFlow.passed.length : 0;
            var isBrowse = trailing && residual === 0;
            var hasResidualSearch = !trailing && residual > 0;
            var include;
            if (isBrowse) include = "all";
            else if (hasResidualSearch) include = "matching";
            else include = "none";
            var isGroup = ownMatched && (isBrowse || hasResidualSearch);
            return {
                decision: {
                    intent: isGroup ? "self-group" : "self-item",
                    includeChildren: include,
                    childSource: "evaluated-children",
                    retainContext: isGroup,
                    allowVisualTakeover: hasResidualSearch
                },
                reasons: [{ code: isGroup ? (isBrowse ? "desktop_trailing_browse" : "desktop_residual") : "desktop_no_group", text: isGroup ? (isBrowse ? "desktop-app-actions: trailing browse " + include + " children" : "desktop-app-actions: matching children for '" + (ctx.query ? ctx.query.raw : "") + "'") : "desktop-app-actions: own match without browse" }]
            };
        });
    }
}
