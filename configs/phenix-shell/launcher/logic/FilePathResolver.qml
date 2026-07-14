import QtQml
import Quickshell
import QtCore
import qs.services

QtObject {
    id: root

    readonly property var tracer: Logger.scope("launcher.filePathResolver", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.filePathResolver", { category: "launcher" })

    property var _nodeCache: ({})
    property var _scanCache: ({})

    function resolveFileQuery(parsed, maxResults) {
        maxResults = maxResults || 8;
        tracer.debug("resolveFileQuery", function() { return { mode: parsed?.mode, maxResults: maxResults }; });

        switch (parsed.mode) {
        case "flat-search":
            return resolveFlatSearch(parsed.tokens, maxResults);
        case "path-explore":
            return resolvePathExplore(parsed.anchor, parsed.tokens, parsed.concretePath, parsed.isDirectory, maxResults);
        case "mixed":
            return resolveMixed(parsed.anchor, parsed.tokens, maxResults);
        case "direct-path":
            return resolveDirectPath(parsed.concretePath, maxResults);
        default:
            return { results: [], resolution: null };
        }
    }

    function resolveFlatSearch(tokens, maxResults) {
        var query = tokens.map(function(t) { return t.raw; }).join(" ");
        if (!query)
            return { results: [], resolution: null };

        var home = StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "");
        return {
            results: [],
            resolution: {
                mode: "flat-search",
                anchor: home,
                resolvedPath: "",
                unresolvedTokens: tokens,
                segments: tokens.map(function(t) {
                    return { token: t.raw, path: "", basename: t.raw, matchKind: "fuzzy", confidence: 0.5, depthFromPrevious: 0 };
                }),
                alternatives: []
            },
            query: query,
            searchRoot: home
        };
    }

    function resolvePathExplore(anchor, tokens, concretePath, isDirectory, maxResults) {
        var segments = [];
        var currentPath = anchor;
        var unresolved = [];
        var alternatives = [];
        var allTokensResolved = true;

        for (var ti = 0; ti < tokens.length; ti += 1) {
            var token = tokens[ti];
            var result = resolveTokenDirect(currentPath, token, maxResults);
            if (result.matched) {
                segments.push({
                    token: token.raw,
                    path: result.path,
                    basename: result.basename,
                    matchKind: result.matchKind,
                    confidence: result.confidence,
                    depthFromPrevious: result.depth
                });
                currentPath = result.path;
                if (result.alternatives && result.alternatives.length > 0)
                    alternatives = alternatives.concat(result.alternatives.map(function(a) {
                        return { tokenIndex: ti, path: a.path, label: a.basename, confidence: a.confidence };
                    }));
            } else {
                var recursiveResult = resolveTokenRecursive(currentPath, token, maxResults);
                if (recursiveResult.matched) {
                    segments.push({
                        token: token.raw,
                        path: recursiveResult.path,
                        basename: recursiveResult.basename,
                        matchKind: recursiveResult.matchKind,
                        confidence: recursiveResult.confidence,
                        depthFromPrevious: recursiveResult.depth
                    });
                    currentPath = recursiveResult.path;
                    if (recursiveResult.alternatives && recursiveResult.alternatives.length > 0)
                        alternatives = alternatives.concat(recursiveResult.alternatives.map(function(a) {
                            return { tokenIndex: ti, path: a.path, label: a.basename, confidence: a.confidence };
                        }));
                } else {
                    unresolved.push(token);
                    allTokensResolved = false;
                    var closerAlts = findCloseAlternatives(currentPath, token.raw, maxResults);
                    for (var ai = 0; ai < closerAlts.length; ai += 1)
                        alternatives.push({ tokenIndex: ti, path: closerAlts[ai].path, label: closerAlts[ai].label, confidence: closerAlts[ai].confidence });
                    segments.push({
                        token: token.raw,
                        path: "",
                        basename: token.raw,
                        matchKind: "unresolved",
                        confidence: 0,
                        depthFromPrevious: 0
                    });
                }
            }
        }

        var resolvedPath = allTokensResolved && segments.length > 0 ? segments[segments.length - 1].path : (segments.length > 0 ? currentPath : anchor);

        return {
            results: [],
            resolution: {
                mode: "path-explore",
                anchor: anchor,
                resolvedPath: resolvedPath,
                unresolvedTokens: unresolved,
                segments: segments,
                alternatives: alternatives.slice(0, maxResults)
            }
        };
    }

    function resolveMixed(anchor, tokens, maxResults) {
        var home = StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "");
        var expandedAnchor = anchor === "~" ? home : anchor;
        return resolvePathExplore(expandedAnchor, tokens, null, false, maxResults);
    }

    function resolveDirectPath(path, maxResults) {
        return {
            results: [],
            resolution: {
                mode: "direct-path",
                anchor: path,
                resolvedPath: path,
                unresolvedTokens: [],
                segments: [{ token: path, path: path, basename: path.split("/").pop(), matchKind: "exact", confidence: 1, depthFromPrevious: 0 }],
                alternatives: []
            }
        };
    }

    function resolveTokenDirect(parentPath, token, maxResults) {
        var normToken = token.normalized || token.raw.toLowerCase();
        var entries = listDirectory(parentPath);

        var exact = null;
        var prefix = [];
        var substring = [];
        var fuzzy = [];

        for (var i = 0; i < entries.length; i += 1) {
            var entry = entries[i];
            var name = entry.basename.toLowerCase();

            if (name === normToken) {
                exact = entry;
                break;
            }
            if (name.indexOf(normToken) === 0)
                prefix.push(entry);
            else if (name.indexOf(normToken) >= 0)
                substring.push(entry);
            else if (fuzzyMatch(name, normToken))
                fuzzy.push(entry);
        }

        if (exact) {
            return {
                matched: true,
                path: exact.path,
                basename: exact.basename,
                matchKind: "exact",
                confidence: 1,
                depth: 0,
                alternatives: prefix.slice(0, maxResults).map(function(e) {
                    return { path: e.path, basename: e.basename, confidence: 0.85 };
                })
            };
        }

        if (prefix.length > 0) {
            var best = prefix[0];
            return {
                matched: true,
                path: best.path,
                basename: best.basename,
                matchKind: "prefix",
                confidence: 0.75 + normToken.length / Math.max(1, best.basename.length) * 0.18,
                depth: 0,
                alternatives: prefix.slice(1, maxResults).map(function(e) {
                    return { path: e.path, basename: e.basename, confidence: 0.7 };
                })
            };
        }

        if (substring.length > 0) {
            var bestSub = substring[0];
            return {
                matched: true,
                path: bestSub.path,
                basename: bestSub.basename,
                matchKind: "substring",
                confidence: 0.55,
                depth: 0,
                alternatives: substring.slice(1, maxResults).map(function(e) {
                    return { path: e.path, basename: e.basename, confidence: 0.5 };
                })
            };
        }

        return { matched: false };
    }

    function resolveTokenRecursive(parentPath, token, maxResults) {
        var normToken = token.normalized || token.raw.toLowerCase();
        var results = [];

        var entries = listDirectoryDeep(parentPath, 3);
        for (var i = 0; i < entries.length && results.length < maxResults; i += 1) {
            var entry = entries[i];
            var name = entry.basename.toLowerCase();
            if (name === normToken) {
                results.push({ path: entry.path, basename: entry.basename, matchKind: "recursive", confidence: 0.9, depth: entry.depth });
            } else if (name.indexOf(normToken) === 0 && results.length < maxResults) {
                results.push({ path: entry.path, basename: entry.basename, matchKind: "recursive", confidence: 0.7, depth: entry.depth });
            }
        }

        if (results.length > 0) {
            return {
                matched: true,
                path: results[0].path,
                basename: results[0].basename,
                matchKind: results[0].matchKind,
                confidence: results[0].confidence,
                depth: results[0].depth,
                alternatives: results.slice(1, maxResults).map(function(r) {
                    return { path: r.path, basename: r.basename, confidence: r.confidence };
                })
            };
        }

        return { matched: false };
    }

    function findCloseAlternatives(parentPath, token, maxResults) {
        var normToken = token.toLowerCase();
        var entries = listDirectory(parentPath);
        var scored = [];

        for (var i = 0; i < entries.length; i += 1) {
            var entry = entries[i];
            var name = entry.basename.toLowerCase();
            var score = fuzzySimilarity(name, normToken);
            if (score > 0.3)
                scored.push({ path: entry.path, label: entry.basename, confidence: score });
        }

        scored.sort(function(a, b) { return b.confidence - a.confidence; });
        return scored.slice(0, maxResults);
    }

    function listDirectory(path) {
        if (root._scanCache[path])
            return root._scanCache[path];

        try {
            var dir = Qt.dir(path);
            if (!dir)
                return [];
            var entries = dir.list("*");
            var result = entries.map(function(name) {
                var fullPath = path + "/" + name;
                return { basename: name, path: fullPath };
            });
            root._scanCache[path] = result;
            return result;
        } catch (e) {
            return [];
        }
    }

    function listDirectoryDeep(path, maxDepth) {
        var results = [];
        function walk(dir, depth) {
            if (depth > maxDepth || !dir) return;
            var entries = listDirectory(dir);
            for (var i = 0; i < entries.length; i += 1) {
                var entry = entries[i];
                results.push({ basename: entry.basename, path: entry.path, depth: depth });
                if (depth < maxDepth)
                    walk(entry.path, depth + 1);
            }
        }
        walk(path, 0);
        return results;
    }

    function fuzzyMatch(name, token) {
        if (token.length < 3) return false;
        return name.indexOf(token) >= 0;
    }

    function fuzzySimilarity(a, b) {
        if (!a || !b) return 0;
        if (a === b) return 1;
        if (a.indexOf(b) === 0) return 0.8;
        if (a.indexOf(b) >= 0) return 0.6;
        if (b.indexOf(a) === 0) return 0.5;
        var common = commonPrefix(a, b);
        return common > 0 ? common / Math.max(a.length, b.length) : 0;
    }

    function commonPrefix(a, b) {
        var min = Math.min(a.length, b.length);
        for (var i = 0; i < min; i += 1) {
            if (a[i] !== b[i]) return i;
        }
        return min;
    }

    function clearScanCache() {
        root._scanCache = {};
    }

    function rowForResolvedPath(resolution, backend) {
        if (!resolution || !resolution.resolvedPath)
            return null;

        var path = resolution.resolvedPath;
        var parts = path.split("/");
        var label = parts[parts.length - 1] || path;
        var isDir = resolution.isDirectory !== false;

        var actions = [
            backend.actionDto("open", "Open", { path: path, actionId: "open" }),
            backend.actionDto("open-folder", "Open Folder", { path: path, actionId: "open-folder" }),
            backend.actionDto("copy-path", "Copy Path", { path: path, actionId: "copy-path" })
        ];

        return {
            id: "file:" + path,
            kind: isDir ? "directory-result" : "file-result",
            label: label,
            subtitle: displayPath(path),
            icon: isDir ? "folder" : iconForPath(path),
            path: path,
            keywords: [path, label],
            showWhenQueryEmpty: true,
            actionList: actions,
            meta: { path: path, fileResolution: resolution },
            children: [],
            lazy: isDir
        };
    }

    function displayPath(path) {
        var home = StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "");
        if (path === home)
            return "~";
        return path.indexOf(home + "/") === 0 ? "~" + path.slice(home.length) : path;
    }

    function iconForPath(path) {
        if (/\.nix$/.test(path))
            return "text-x-nix";
        if (/\.(png|jpe?g|webp|svg)$/.test(path))
            return "image-x-generic";
        if (/\.(mp4|mkv|webm)$/.test(path))
            return "video-x-generic";
        if (/\.(mp3|flac|ogg|wav)$/.test(path))
            return "audio-x-generic";
        return "text-x-generic";
    }
}
