.pragma library

function makeTree() {
    return { endpoints: [] };
}

function registerEndpoint(tree, route, node) {
    if (!tree || !route) return;
    tree.endpoints.push({
        prefix: route.prefix || null,
        pattern: route.pattern || null,
        priority: route.priority || 0,
        combine: route.combine || "shared",
        afterEmpty: route.afterEmpty || "stop",
        mode: route.mode || null,
        boundary: route.boundary || "strict",
        node: node
    });
}

function unregisterEndpoint(tree, node) {
    if (!tree) return;
    tree.endpoints = tree.endpoints.filter(function(ep) { return ep.node !== node; });
}

function tryMatch(text, ep) {
    if (ep.pattern) {
        try {
            return (new RegExp(ep.pattern)).test(text);
        } catch (e) {
            return false;
        }
    }
    if (!ep.prefix) return true;
    if (text.indexOf(ep.prefix) !== 0) return false;
    var next = text[ep.prefix.length];
    var compact = ep.prefix.length === 1 && (ep.prefix === ":" || ep.prefix === "=" || ep.prefix === "?");
    if (ep.boundary !== "any" && !compact && next !== undefined && !/\s/.test(next))
        return false;
    return true;
}

function extractStripped(text, ep) {
    if (ep.pattern) {
        try {
            var re = new RegExp(ep.pattern);
            var m = re.exec(text);
            if (m) {
                var stripped = m[m.length - 1];
                if (stripped !== undefined && stripped !== null)
                    return stripped.replace(/^[:\s]+/, "");
            }
        } catch (e) {}
        return text;
    }
    if (ep.prefix)
        return text.slice(ep.prefix.length).replace(/^[:\s]+/, "");
    return text;
}

function endpointKey(ep) {
    return ep.pattern || ep.prefix || "";
}

function routeQuery(tree, raw) {
    var rawStr = String(raw || "");
    var leading = rawStr.match(/^\s*/)[0];
    var text = rawStr.trim();
    var trailing = rawStr.slice(leading.length + text.length);
    if (!text)
        return { endpoints: [], strippedQuery: "", combine: null, tier: -1 };

    var sorted = tree.endpoints.slice().sort(function(a, b) {
        if (b.priority !== a.priority) return b.priority - a.priority;
        var aLen = a.prefix ? a.prefix.length : 0;
        var bLen = b.prefix ? b.prefix.length : 0;
        return bLen - aLen;
    });

    var tiers = [];
    var currentTier = [];
    var currentPriority = sorted.length > 0 ? sorted[0].priority : 0;
    for (var i = 0; i < sorted.length; i += 1) {
        var ep = sorted[i];
        if (ep.priority !== currentPriority) {
            tiers.push({ priority: currentPriority, endpoints: currentTier });
            currentTier = [];
            currentPriority = ep.priority;
        }
        currentTier.push(ep);
    }
    if (currentTier.length > 0)
        tiers.push({ priority: currentPriority, endpoints: currentTier });

    for (var ti = 0; ti < tiers.length; ti += 1) {
        var tier = tiers[ti];
        var matches = tier.endpoints.filter(function(ep) {
            return tryMatch(text, ep);
        });

        if (matches.length === 0)
            continue;

        // Group matches by endpoint key for dedup
        var seen = {};
        var deduped = [];
        for (var mi = 0; mi < matches.length; mi += 1) {
            var key = endpointKey(matches[mi]);
            if (!seen[key]) {
                seen[key] = true;
                deduped.push(matches[mi]);
            }
        }

        // Sort deduped matches: pattern routes before prefix, longer prefix first
        deduped.sort(function(a, b) {
            var aP = a.pattern ? 1 : 0;
            var bP = b.pattern ? 1 : 0;
            if (aP !== bP) return aP - bP;
            var aLen = a.prefix ? a.prefix.length : 0;
            var bLen = b.prefix ? b.prefix.length : 0;
            return bLen - aLen;
        });

        var exclusive = null;
        for (var mi = 0; mi < deduped.length; mi += 1) {
            var candidate = deduped[mi];
            if (candidate.combine === "exclusive" || candidate.mode === "exclusive") {
                exclusive = candidate;
                break;
            }
        }

        if (exclusive) {
            var stripped = extractStripped(text, exclusive);
            return { endpoints: [exclusive], strippedQuery: stripped + trailing, combine: "exclusive", tier: exclusive.priority };
        }

        var shared = deduped.filter(function(ep) {
            return ep.combine !== "exclusive" && ep.mode !== "exclusive";
        });
        if (shared.length === 0)
            continue;

        var strippedQuery = text;
        // Try each shared endpoint's extractor; first match wins
        for (var si = 0; si < shared.length; si += 1) {
            var extracted = extractStripped(text, shared[si]);
            if (extracted !== text) {
                strippedQuery = extracted;
                break;
            }
        }

        return { endpoints: shared, strippedQuery: strippedQuery + trailing, combine: "shared", tier: currentPriority };
    }

    return { endpoints: [], strippedQuery: text + trailing, combine: null, tier: -1 };
}
