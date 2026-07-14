pragma Singleton
import Quickshell
import qs.services
import "Tokenize.qml"

Singleton {
    readonly property var tracer: Logger.scope("launcher.actionPolicy", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.actionPolicy", { category: "launcher" })
    readonly property var baseAliases: ({
        on: ["on", "enable", "connect"],
        off: ["off", "disable", "disconnect"],
        toggle: ["toggle", "switch"]
    })

    function selectDefaultAction(node, query, ev, ctx) {
        tracer.trace("selectDefaultAction", function() { return { nodeId: node?.id }; });
        var candidates = actionCandidates(node, query, ev, ctx);
        if (!candidates.length)
            return null;
        candidates.sort(compareCandidates);
        return candidates[0];
    }

    function defaultActionForNode(node, query, ev, ctx) {
        var selected = selectDefaultAction(node, query, ev, ctx);
        return selected ? selected.action : null;
    }

    function actionCandidates(node, query, ev, ctx) {
        if (!node)
            return [];

        var actions = node.actionList || [];
        var out = [];

        if (node.switchActions) {
            appendSwitchCandidate(out, node, "toggle", query, ev, ctx);
            appendSwitchCandidate(out, node, "on", query, ev, ctx);
            appendSwitchCandidate(out, node, "off", query, ev, ctx);
            return scored(out, query, ev, ctx);
        }

        for (var i = 0; i < actions.length; i += 1) {
            var action = actions[i];
            if (!action)
                continue;
            out.push({
                id: action.id || "",
                role: action.default ? "default" : "custom",
                action: action,
                score: 0,
                priority: action.default ? 50 : Math.max(0, 40 - i),
                reasons: action.default ? ["explicit-default"] : (i === 0 ? ["first-action"] : [])
            });
        }
        return scored(out, query, ev, ctx);
    }

    function appendSwitchCandidate(out, node, role, query, ev, ctx) {
        if (!node.switchActions || !node.switchActions[role])
            return;
        out.push({
            id: role,
            role: role,
            action: node.switchActions[role],
            score: 0,
            priority: role === "toggle" ? 30 : 20,
            reasons: role === "toggle" ? ["switch-fallback"] : []
        });
    }

    function scored(candidates, query, ev, ctx) {
        return (candidates || []).map(function(candidate) {
            var scoredCandidate = Object.assign({}, candidate);
            var score = scoreCandidate(scoredCandidate, query, ev, ctx);
            scoredCandidate.score = score.score;
            scoredCandidate.priority = score.priority;
            scoredCandidate.reasons = score.reasons;
            return scoredCandidate;
        });
    }

    function scoreCandidate(candidate, query, ev, ctx) {
        var score = Number(candidate.score || 0);
        var priority = Number(candidate.priority || 0);
        var reasons = (candidate.reasons || []).slice();

        if (candidate.role === "default") {
            score += 0.6;
            priority += 20;
        }

        if (candidate.role === "toggle")
            score += 0.2;

        var aliasScore = scoreAliases(candidate, query, ev, ctx);
        if (aliasScore.score > 0) {
            score += aliasScore.score;
            priority += 80;
            reasons.push(aliasScore.reason);
        }

        var evidenceScore = scoreEvidence(candidate, ev);
        if (evidenceScore > 0) {
            score += evidenceScore;
            priority += 40;
            reasons.push("action-evidence");
        }

        return { score: Tokenize.clamp(score, 0, 2), priority: priority, reasons: reasons };
    }

    function compareCandidates(a, b) {
        if ((b.score || 0) !== (a.score || 0))
            return (b.score || 0) - (a.score || 0);
        if ((b.priority || 0) !== (a.priority || 0))
            return (b.priority || 0) - (a.priority || 0);
        return 0;
    }

    function scoreAliases(candidate, query, ev, ctx) {
        var tokens = queryTokens(query);
        if (!tokens.length)
            return { score: 0, reason: "" };

        var aliases = aliasesForCandidate(candidate, ev);
        var best = { score: 0, reason: "" };
        for (var ti = 0; ti < tokens.length; ti += 1) {
            for (var ai = 0; ai < aliases.length; ai += 1) {
                var alias = aliases[ai];
                var token = tokens[ti];
                var score = aliasMatchScore(token, alias);
                if (score > best.score)
                    best = { score: score, reason: "query-alias:" + alias };
            }
        }
        return best;
    }

    function queryTokens(query) {
        return ((query && query.tokens) || []).map(function(t) { return t.normalized || ""; }).filter(Boolean);
    }

    function aliasesForCandidate(candidate, ev) {
        var aliases = [];
        if (baseAliases[candidate.role])
            aliases = aliases.concat(baseAliases[candidate.role]);

        var action = candidate.action || {};
        aliases.push(candidate.id || "");
        aliases.push(action.id || "");
        aliases.push(action.label || action.title || "");
        if (action.payload) {
            aliases.push(action.payload.actionId || "");
            aliases.push(action.payload.op || "");
        }

        var node = ev && ev.node;
        if (node && node.switchActions && baseAliases[candidate.role]) {
            var acronym = String(node.label || "").replace(/[^A-Za-z0-9]/g, "").charAt(0).toLowerCase();
            if (acronym) {
                if (candidate.role === "on") aliases.push(acronym + "o");
                else if (candidate.role === "off") aliases.push(acronym + "f");
                else if (candidate.role === "toggle") aliases.push(acronym + "t");
            }
        }

        var seen = {};
        return aliases.map(function(alias) { return Tokenize.normalizeText(alias); }).filter(function(alias) {
            if (!alias || seen[alias]) return false;
            seen[alias] = true;
            return true;
        });
    }

    function aliasMatchScore(token, alias) {
        if (!token || !alias)
            return 0;
        if (token === alias)
            return 1;
        if (alias.indexOf(token) === 0 && token.length >= 2)
            return 0.78 + token.length / Math.max(20, alias.length * 20);
        if (alias.length > token.length && alias.lastIndexOf(token) === alias.length - token.length)
            return token.length >= 2 ? 0.72 + token.length / Math.max(20, alias.length * 20) : 0.75;
        return 0;
    }

    function scoreEvidence(candidate, ev) {
        var evidence = ev && ev.evidence || [];
        var best = 0;
        for (var i = 0; i < evidence.length; i += 1) {
            var item = evidence[i];
            if (item.actionId && item.actionId === candidate.id)
                best = Math.max(best, Number(item.effective || item.score || 0));
            if (item.actionRole && item.actionRole === candidate.role)
                best = Math.max(best, Number(item.effective || item.score || 0));
        }
        return best;
    }

    function selectedActionMetadata(candidate) {
        if (!candidate)
            return null;
        return {
            id: candidate.id || "",
            role: candidate.role || "custom",
            score: Number(candidate.score || 0),
            priority: Number(candidate.priority || 0),
            reasons: (candidate.reasons || []).slice()
        };
    }
}
