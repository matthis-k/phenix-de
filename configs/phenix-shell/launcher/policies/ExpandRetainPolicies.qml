import QtQml
import qs.services
import "../" as Launcher
import "../logic/"

QtObject {
    readonly property var tracer: Logger.scope("policy.expandRetain", { category: "policy" })
    readonly property var prof: Profiler.scope("policy.expandRetain", { category: "policy" })

    Component.onCompleted: {
        Launcher.PolicyRegistry.registerExpand("expand-when", function(ev, ctx, args) {
            var mode = (args && args.mode) || "own-match";
            var maxChildren = (args && args.maxChildren) || 8;
            var minScore = (args && args.minScore) || 0.1;
            if (!ev || !ev.children) return { decision: { expand: false, maxChildren: 0 }, reasons: [{ code: "no_children", text: "no children" }] };

            var visibleChildren = ev.children.filter(function(c) {
                return c.visible && c.score >= minScore;
            });

            var ownMatched = !!(ev.ownVisible || (ev.ownScore || 0) >= minScore);
            var expand = false;
            if (mode === "all") expand = true;
            else if (mode === "visible-children") expand = visibleChildren.length > 0;
            else expand = ownMatched;

            return {
                decision: {
                    expand: expand,
                    maxChildren: maxChildren
                },
                reasons: [{ code: expand ? "expand_when_expanded" : "expand_when_not_expanded", text: "expand-when: mode " + mode + ", ownMatched " + ownMatched + ", " + visibleChildren.length + " visible children" }]
            };
        });

        Launcher.PolicyRegistry.registerExpand("expand-on-own-match", function(ev, ctx, args) {
            var maxChildren = (args && args.maxChildren) || 8;
            var minScore = (args && args.minScore) || 0.1;
            var ownMatched = !!(ev && (ev.ownVisible || (ev.ownScore || 0) >= minScore));
            return {
                decision: {
                    expand: ownMatched,
                    maxChildren: maxChildren,
                    includeAllChildren: ownMatched
                },
                reasons: [{ code: ownMatched ? "own_match_expand" : "no_own_match", text: ownMatched ? "expand-on-own-match: parent has own match" : "expand-on-own-match: parent has no own match" }]
            };
        });

        Launcher.PolicyRegistry.registerExpand("expand-on-trailing-space", function(ev, ctx, args) {
            var maxChildren = (args && args.maxChildren) || 8;
            var ownRequired = !(args && args.ownRequired === false);
            var ownMatched = !!(ev && (ev.ownVisible || (ev.ownScore || 0) > 0));
            var trailing = !!(ctx && ctx.query && ctx.query.lastTokenEmpty);
            var expand = trailing && (!ownRequired || ownMatched);
            return {
                decision: {
                    expand: expand,
                    maxChildren: maxChildren,
                    includeAllChildren: expand
                },
                reasons: [{ code: expand ? "trailing_space_expand" : "no_trailing_space", text: expand ? "expand-on-trailing-space" : "expand-on-trailing-space: no trailing-space browse" }]
            };
        });

        Launcher.PolicyRegistry.registerExpand("expand-on-own-match-or-trailing-space", function(ev, ctx, args) {
            var maxChildren = (args && args.maxChildren) || 8;
            var minScore = (args && args.minScore) || 0.1;
            var ownMatched = !!(ev && (ev.ownVisible || (ev.ownScore || 0) >= minScore));
            var trailing = !!(ctx && ctx.query && ctx.query.lastTokenEmpty);
            var residual = (ev && ev.tokenFlow && ev.tokenFlow.passed) ? ev.tokenFlow.passed.length : 0;
            var expand = ownMatched || trailing;
            var browseAll = trailing && residual === 0;
            var filterByResidual = !trailing && residual > 0;
            return {
                decision: {
                    expand: expand,
                    maxChildren: maxChildren,
                    includeAllChildren: browseAll,
                    minScore: filterByResidual ? 0.02 : (browseAll ? 0 : 0.25)
                },
                reasons: [{ code: expand ? (browseAll ? "trailing_browse_all" : filterByResidual ? "residual_filter" : "own_match_expand") : "not_expanded", text: expand ? (browseAll ? "expand-on-own-match-or-trailing-space: trailing browse includes all children" : filterByResidual ? "expand-on-own-match-or-trailing-space: residual tokens filter children" : "expand-on-own-match-or-trailing-space: own match expands children") : "expand-on-own-match-or-trailing-space: not expanded" }]
            };
        });

        Launcher.PolicyRegistry.registerExpand("expand-on-explicit-parent-token", function(ev, ctx, args) {
            var maxChildren = (args && args.maxChildren) || 8;
            var minScore = (args && args.minScore) || 0.25;
            var expand = !!(ev && (ev.ownVisible || (ev.ownScore || 0) >= minScore));
            return {
                decision: {
                    expand: expand,
                    maxChildren: maxChildren
                },
                reasons: [{ code: expand ? "parent_token_expand" : "no_parent_token", text: expand ? "expand-on-explicit-parent-token" : "expand-on-explicit-parent-token: parent token absent" }]
            };
        });

        Launcher.PolicyRegistry.registerExpand("expand-on-child-match", function(ev, ctx, args) {
            var maxChildren = (args && args.maxChildren) || 8;
            var minScore = (args && args.minScore) || 0.1;
            var visibleChildren = (ev && ev.children || []).filter(function(c) {
                return c.visible && c.score >= minScore;
            });
            return {
                decision: {
                    expand: visibleChildren.length > 0,
                    maxChildren: maxChildren
                },
                reasons: [{ code: visibleChildren.length > 0 ? "child_match_expand" : "no_child_match", text: "expand-on-child-match: " + visibleChildren.length + " visible children" }]
            };
        });

        Launcher.PolicyRegistry.registerExpand("expand-all", function(ev, ctx, args) {
            var maxChildren = (args && args.maxChildren) || 24;
            return {
                decision: {
                    expand: true,
                    maxChildren: maxChildren
                },
                reasons: [{ code: "expand_all", text: "expand-all: all children visible" }]
            };
        });

        Launcher.PolicyRegistry.registerExpand("expand-none", function(ev, ctx, args) {
            return {
                decision: {
                    expand: false,
                    maxChildren: 0
                },
                reasons: [{ code: "expand_none", text: "expand-none: no children visible" }]
            };
        });

        Launcher.PolicyRegistry.registerRetainParent("retain-parent-when", function(ev, ctx, args) {
            var condition = (args && args.condition) || "has-own-score";
            var retain = true;
            var reasonText = "";

            switch (condition) {
            case "own-match":
            case "has-own-score":
                retain = (ev.ownScore || 0) > 0;
                reasonText = retain ? "retain-parent-when: parent has own score" : "retain-parent-when: parent has no own score";
                break;
            case "has-actions":
                var hasActions = (ev.node && ev.node.actionList && ev.node.actionList.length > 0) || (ev.node && ev.node.switchActions);
                retain = !!hasActions;
                reasonText = retain ? "retain-parent-when: parent has actions" : "retain-parent-when: parent has no actions";
                break;
            case "switched":
                var isSwitch = !!(ev.node && ev.node.switchState !== undefined);
                retain = isSwitch;
                reasonText = retain ? "retain-parent-when: parent is a switch" : "retain-parent-when: parent is not a switch";
                break;
            case "has-risk":
                var hasRisk = (ev.node && (ev.node.risk || ev.node.dangerous));
                retain = !!hasRisk;
                reasonText = retain ? "retain-parent-when: parent has risk context" : "retain-parent-when: parent has no risk";
                break;
            default:
                reasonText = "retain-parent-when: unknown condition '" + condition + "', retaining";
            }

            return {
                decision: { retain: retain },
                reasons: [{ code: retain ? "retain_parent" : "suppress_parent", text: reasonText }]
            };
        });

        Launcher.PolicyRegistry.registerRetainParent("retain-always", function(ev, ctx, args) {
            return {
                decision: { retain: true },
                reasons: [{ code: "retain_always", text: "retain-always" }]
            };
        });

        Launcher.PolicyRegistry.registerRetainParent("retain-never", function(ev, ctx, args) {
            return {
                decision: { retain: false },
                reasons: [{ code: "retain_never", text: "retain-never" }]
            };
        });

        Launcher.PolicyRegistry.registerDefaultAction("default-action-owner", function(ev, ctx, args) {
            var ownerId = (args && args.ownerId) || (ev.node && ev.node.id) || "";
            var actionId = (args && args.actionId) || "";

            return {
                decision: {
                    ownerId: ownerId,
                    actionId: actionId
                },
                reasons: [{ code: "default_action_owner", text: args && args.reason ? args.reason : "policy declared" }]
            };
        });

        Launcher.PolicyRegistry.registerDefaultAction("default-action-expand", function(ev, ctx, args) {
            return {
                decision: {
                    ownerId: ev.node ? ev.node.id : "",
                    actionId: "expand"
                },
                reasons: [{ code: "default_action_expand", text: "default-action-expand: enter expands the group" }]
            };
        });
    }
}
