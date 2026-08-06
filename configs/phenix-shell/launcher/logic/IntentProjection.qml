pragma Singleton
import QtQml
import Quickshell
import qs.services

Singleton {
    id: root

    readonly property var tracer: Logger.scope("launcher.intentProjection", { category: "launcher" })

    function configFor(node) {
        return node && node.behavior ? node.behavior.intentProjection || null : null;
    }

    function evaluate(ev, ctx) {
        var node = ev && ev.node;
        if (!node)
            return null;

        var query = ctx && ctx.query;
        if (!query || query.isEmpty || query.lastTokenEmpty)
            return null;

        var config = configFor(node);
        var passed = ev.tokenFlow && ev.tokenFlow.passed || [];
        if (passed.length === 0) {
            return config && config.subjects === "children"
                ? baseProjection(ev, "no residual subject intent; retain the base slot")
                : null;
        }

        var actionIndexes = actionTokenIndexes(node, passed);
        var actionOnly = Object.keys(actionIndexes).length === passed.length;
        if (!config) {
            if (node.switchActions && actionOnly)
                return actionOnlyProjection(ev, "explicit action intent remains on the switch slot");
            return null;
        }
        if (config.subjects !== "children")
            return node.switchActions && actionOnly
                ? actionOnlyProjection(ev, "explicit action intent remains on the configured slot")
                : null;

        var parentMatched = !!(ev.ownVisible || Number(ev.ownScore || 0) >= Number(config.minParentScore === undefined ? 0.05 : config.minParentScore));
        if (config.requireParentMatch !== false && !parentMatched)
            return rejectedProjection(ev, config, passed, "parent intent did not match");

        var subjectIndexes = [];
        for (var pi = 0; pi < passed.length; pi += 1) {
            if (!actionIndexes[pi])
                subjectIndexes.push(pi);
        }

        if (subjectIndexes.length === 0)
            return actionOnlyProjection(ev, "explicit action intent remains on the parent slot");

        var candidates = [];
        for (var ci = 0; ci < (ev.children || []).length; ci += 1) {
            var child = ev.children[ci];
            if (!child || !child.node || !child.allowed)
                continue;

            var identityCoverage = identityCoveredIndexes(child);
            var covered = 0;
            for (var si = 0; si < subjectIndexes.length; si += 1) {
                if (identityCoverage[subjectIndexes[si]])
                    covered += 1;
            }
            if (covered === 0)
                continue;

            var coverage = covered / subjectIndexes.length;
            var minCoverage = Number(config.minResidualCoverage === undefined ? 1 : config.minResidualCoverage);
            var score = Math.max(Number(child.ownScore || 0), Number(child.score || 0));
            var minScore = Number(config.minSubjectScore === undefined ? 0.18 : config.minSubjectScore);
            if (coverage + 0.0001 < minCoverage || score + 0.0001 < minScore)
                continue;

            candidates.push({
                ev: child,
                coverage: coverage,
                covered: covered,
                score: score
            });
        }

        candidates.sort(function(a, b) {
            if (Math.abs(b.coverage - a.coverage) > 0.0001)
                return b.coverage - a.coverage;
            if (Math.abs(b.score - a.score) > 0.0001)
                return b.score - a.score;
            return String(a.ev.node.label || a.ev.node.id || "").localeCompare(String(b.ev.node.label || b.ev.node.id || ""));
        });

        if (candidates.length === 0)
            return rejectedProjection(ev, config, passed, "no single child covered the subject intent");

        var best = candidates[0];
        var proxyScore = Math.max(Number(ev.ownScore || 0), best.score);
        tracer.trace("subjectSelected", function() {
            return {
                slotOwnerId: node.id || "",
                subjectOwnerId: best.ev.node.id || "",
                score: proxyScore,
                coverage: best.coverage
            };
        });
        return {
            configured: true,
            active: true,
            actionOnly: false,
            suppressChildren: true,
            slotOwnerId: node.id || "",
            subjectOwnerId: best.ev.node.id || "",
            proxyScore: proxyScore,
            coveredSubjectTokens: best.covered,
            totalSubjectTokens: subjectIndexes.length,
            reason: "selected one child that covered the residual subject intent"
        };
    }

    function baseProjection(ev, reason) {
        return {
            configured: true,
            active: false,
            actionOnly: false,
            suppressChildren: true,
            slotOwnerId: ev && ev.node ? ev.node.id || "" : "",
            subjectOwnerId: "",
            proxyScore: Math.max(Number(ev && ev.ownScore || 0), Number(ev && ev.score || 0)),
            coveredSubjectTokens: 0,
            totalSubjectTokens: 0,
            reason: reason || "retain the base slot"
        };
    }

    function actionOnlyProjection(ev, reason) {
        var projection = baseProjection(ev, reason || "explicit action intent remains on the current slot");
        projection.actionOnly = true;
        return projection;
    }

    function rejectedProjection(ev, config, passed, reason) {
        var penalty = Number(config.unusedTokenPenalty === undefined ? 0.12 : config.unusedTokenPenalty);
        return {
            configured: true,
            active: false,
            actionOnly: false,
            suppressChildren: true,
            slotOwnerId: ev && ev.node ? ev.node.id || "" : "",
            subjectOwnerId: "",
            proxyScore: Math.max(0, Number(ev && ev.ownScore || 0) * penalty),
            coveredSubjectTokens: 0,
            totalSubjectTokens: passed ? passed.length : 0,
            reason: reason || "subject intent was not covered"
        };
    }

    function resolveRow(ev, decision, ctx, fallbackSelectedAction) {
        if (!ev || !ev.node)
            return null;

        var projection = decision && decision.projection || null;
        var subjectEv = projection && projection.subjectOwnerId
            ? findChildEv(ev, projection.subjectOwnerId)
            : null;
        var effectiveEv = subjectEv || ev;
        var node = effectiveEv.node;
        var selectedAction = subjectEv
            ? selectAction(node, ctx && ctx.query, effectiveEv, ctx)
            : selectAction(node, ctx && ctx.query, effectiveEv, ctx, fallbackSelectedAction);
        var action = selectedAction ? selectedAction.action : null;
        var explicitAction = isExplicitAction(selectedAction);
        var actionPresentation = presentationForAction(action);
        var useActionPresentation = !!actionPresentation && (!!subjectEv || explicitAction);
        var title = useActionPresentation && actionPresentation.title
            ? actionPresentation.title
            : node.label || "";
        var subtitle = useActionPresentation && actionPresentation.subtitle !== undefined
            ? actionPresentation.subtitle
            : node.subtitle || "";
        var icon = useActionPresentation && actionPresentation.icon
            ? actionPresentation.icon
            : node.icon || null;
        var iconColor = useActionPresentation && actionPresentation.iconColor
            ? actionPresentation.iconColor
            : node.iconColor || null;
        var subjectSelected = !!subjectEv;
        var lockedSlot = !!(projection && projection.configured);
        var actionOwnerId = selectedAction ? selectedAction.id || (action && action.id) || "" : "";

        return {
            ev: effectiveEv,
            node: node,
            selectedAction: selectedAction,
            action: action,
            title: title,
            subtitle: subtitle,
            icon: icon,
            iconColor: iconColor,
            subjectSelected: subjectSelected,
            lockedSlot: lockedSlot,
            activationExplicit: subjectSelected || explicitAction,
            slotOwnerId: ev.node.id || "",
            subjectOwnerId: subjectSelected ? node.id || "" : "",
            actionOwnerId: actionOwnerId,
            explicitAction: explicitAction,
            reason: projection && projection.reason
                ? projection.reason
                : explicitAction
                    ? "explicit action intent selected one action variant"
                    : "base node presentation"
        };
    }

    function selectAction(node, query, ev, ctx, fallbackSelectedAction) {
        var candidates = ActionPolicy.actionCandidates(node, query, ev, ctx);
        var explicitCandidates = candidates.filter(isExplicitAction);
        if (explicitCandidates.length > 0) {
            explicitCandidates.sort(ActionPolicy.compareCandidates);
            return explicitCandidates[0];
        }

        if (node && node.switchActions) {
            var preferredRole = "";
            if (node.switchActions.toggle)
                preferredRole = "toggle";
            else if (node.switchState === true && node.switchActions.off)
                preferredRole = "off";
            else if (node.switchActions.on)
                preferredRole = "on";
            else if (node.switchActions.off)
                preferredRole = "off";

            if (preferredRole) {
                for (var ci = 0; ci < candidates.length; ci += 1) {
                    if (candidates[ci].role === preferredRole || candidates[ci].id === preferredRole)
                        return candidates[ci];
                }
            }
        }

        return fallbackSelectedAction || ActionPolicy.selectDefaultAction(node, query, ev, ctx);
    }

    function isExplicitAction(candidate) {
        if (!candidate)
            return false;
        var reasons = candidate.reasons || [];
        for (var i = 0; i < reasons.length; i += 1) {
            var reason = String(reasons[i] || "");
            if (reason.indexOf("query-alias:") === 0 || reason === "action-evidence")
                return true;
        }
        return false;
    }

    function actionTokenIndexes(node, tokens) {
        var covered = {};
        if (!node || !node.switchActions)
            return covered;

        var roles = ["toggle", "on", "off"];
        for (var ti = 0; ti < (tokens || []).length; ti += 1) {
            var token = tokens[ti] && (tokens[ti].normalized || tokens[ti].raw) || "";
            token = Tokenize.normalizeText(token);
            if (!token)
                continue;
            for (var ri = 0; ri < roles.length; ri += 1) {
                var role = roles[ri];
                var action = node.switchActions[role];
                if (!action)
                    continue;
                var aliases = aliasesForAction(role, action);
                for (var ai = 0; ai < aliases.length; ai += 1) {
                    if (ActionPolicy.aliasMatchScore(token, aliases[ai]) > 0) {
                        covered[ti] = true;
                        break;
                    }
                }
                if (covered[ti])
                    break;
            }
        }
        return covered;
    }

    function aliasesForAction(role, action) {
        var aliases = [];
        var base = ActionPolicy.baseAliases && ActionPolicy.baseAliases[role] || [];
        aliases = aliases.concat(base);
        aliases = aliases.concat(action && action.aliases || []);
        if (action) {
            aliases.push(action.id || "");
            aliases.push(action.label || action.title || "");
            if (action.payload) {
                aliases.push(action.payload.op || "");
                aliases.push(action.payload.actionId || "");
            }
            var presentation = presentationForAction(action);
            if (presentation) {
                aliases.push(presentation.title || "");
                aliases.push(presentation.subtitle || "");
            }
        }

        var seen = {};
        var out = [];
        for (var i = 0; i < aliases.length; i += 1) {
            var normalized = Tokenize.normalizeText(aliases[i]);
            if (!normalized)
                continue;
            var pieces = [normalized].concat(normalized.split(/\s+/));
            for (var pi = 0; pi < pieces.length; pi += 1) {
                var piece = pieces[pi];
                if (!piece || seen[piece])
                    continue;
                seen[piece] = true;
                out.push(piece);
            }
        }
        return out;
    }

    function identityCoveredIndexes(childEv) {
        var covered = {};
        var evidence = childEv && (childEv.ownEvidence || childEv.evidence) || [];
        for (var ei = 0; ei < evidence.length; ei += 1) {
            var item = evidence[ei];
            if (isActionEvidence(item))
                continue;
            if (item.tokenIndex !== undefined && item.tokenIndex !== null)
                covered[Number(item.tokenIndex)] = true;
            for (var ti = 0; ti < (item.tokenIndexes || []).length; ti += 1)
                covered[Number(item.tokenIndexes[ti])] = true;
        }
        return covered;
    }

    function isActionEvidence(item) {
        if (!item)
            return false;
        if (item.actionId || item.actionRole || item.field === "action" || item.strategy === "switch-action")
            return true;
        return String(item.kind || "").indexOf("action-") === 0;
    }

    function findChildEv(parentEv, childId) {
        for (var i = 0; i < (parentEv && parentEv.children || []).length; i += 1) {
            var child = parentEv.children[i];
            if (child && child.node && child.node.id === childId)
                return child;
        }
        return null;
    }

    function presentationForAction(action) {
        if (!action)
            return null;
        return action.presentation || action.payload && action.payload.presentation || null;
    }

    function toDebug(projection) {
        if (!projection)
            return null;
        return {
            active: !!projection.active,
            actionOnly: !!projection.actionOnly,
            slotOwnerId: projection.slotOwnerId || "",
            subjectOwnerId: projection.subjectOwnerId || "",
            actionOwnerId: projection.actionOwnerId || "",
            proxyScore: Number(projection.proxyScore || 0),
            reason: projection.reason || ""
        };
    }
}
