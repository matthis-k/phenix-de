import QtCore
import Quickshell.Io
import qs.services
import "../logic/"
import "../logic/EvaluationProfiles.js" as EvalProfiles

ProcessBackendBase {
    id: root

    readonly property var tracer: Logger.scope("backend.files", { category: "backend" })
    readonly property var prof: Profiler.scope("backend.files", { category: "backend" })

    property FileQueryParser fileQueryParser: FileQueryParser {}
    property FilePathResolver filePathResolver: FilePathResolver {}
    property string searchRoot: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "")
    property var lazyNodeCache: ({})
    property var lazyScanPath: ""
    property var lazyScanCallback: null

    readonly property var fixtureFileList: TestMode.isActive ? (loadFixtureFiles() || []) : []

    function loadFixtureFiles() {
        try {
            var path = TestMode.fixturePath("FILES");
            if (!path) return [];
            var data = TestMode.loadFixtureSync(path);
            return Array.isArray(data) ? data : [];
        } catch (e) {
            return [];
        }
    }

    function fixtureRootNode(queryText) {
        var list = root.fixtureFileList || [];
        var children = list.map(function(f, i) {
            return root.nodeForPath(f.path, i, f.name, null, null, true);
        });
        return root.backendRootDto(children, {
            subtitle: qsTr("Fixture results (%1)").arg(children.length),
            evaluationProfile: EvalProfiles.fileProfile()
        });
    }

    category: qsTr("Files")

    backendId: "files"
    name: qsTr("Files")
    helpDescription: qsTr("Search files from home")
    helpIcon: "folder"
    helpPrefixes: ["@file", "@files"]
    priority: 60
    maxResults: 5
    routes: [
        { pattern: "^@files?\\s+(.*)", priority: 60, combine: "exclusive", afterEmpty: "stop" },
        { pattern: "^~?/(.*)", priority: 60, combine: "exclusive", afterEmpty: "stop" }
    ]

    property Process lazyScanner: Process {
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var path = root.lazyScanPath;
                var cb = root.lazyScanCallback;
                root.lazyScanPath = "";
                root.lazyScanCallback = null;
                if (cb) {
                    var nodes = root.parseDirectoryOutput(text, path);
                    root.lazyNodeCache[path] = nodes;
                    cb(nodes);
                }
            }
        }
        onExited: function(code) {
            if (code !== 0 && root.lazyScanCallback) {
                var cb = root.lazyScanCallback;
                root.lazyScanPath = "";
                root.lazyScanCallback = null;
                cb([]);
            }
        }
    }

    function scanDirectory(path, callback) {
        tracer.debug("scanDirectory", function() { return { path: path, cached: !!root.lazyNodeCache[path] }; });
        if (root.lazyNodeCache[path]) {
            Qt.callLater(function() { callback(root.lazyNodeCache[path]); });
            return;
        }
        if (root.lazyScanPath === path) return;
        root.lazyScanPath = path;
        root.lazyScanCallback = callback;
        root.lazyScanner.exec({ command: ["fd", ".", path, "--absolute-path", "--max-depth", "1", "--printf", "%p|%y\n"] });
    }

    function parseDirectoryOutput(text, dirPath) {
        var lines = (text || "").trim().split("\n").filter(function(l) { return l.length > 0; });
        return lines.map(function(line, idx) {
            var parts = line.split("|");
            var fpath = parts[0] || "";
            var type = parts[1] || "";
            return root.nodeForPath(fpath, idx, undefined, undefined, undefined, type === "d");
        });
    }

    function shouldParticipate(rawQuery, directive, query) {
        const raw = String(rawQuery || "").trim();

        if (directive && directive.active && directive.backendIds && directive.backendIds.indexOf(root.backendId) >= 0)
            return true;

        if (raw[0] === "/" || raw[0] === "~" || raw.indexOf("file://") === 0 || /^@files?(\s|$)/.test(raw))
            return true;

        var result = raw.indexOf("~ ") === 0 && raw.length > 2;
        tracer.trace("shouldParticipate", function() { return { rawQuery: rawQuery, result: result }; });
        return result;
    }

    function rootNode(query, context) {
        const rawQuery = context && context.directive && context.directive.active ? context.directive.raw : (query ? query.raw : "");
        tracer.debug("rootNode", function() { return { rawQuery: rawQuery, testMode: TestMode.isActive }; });
        if (!shouldParticipate(rawQuery, context ? context.directive : null, query))
            return null;

        if (TestMode.isActive)
            return root.fixtureRootNode(rawQuery);

        var parsed = root.fileQueryParser.parseFileQuery(rawQuery);

        if (parsed.mode === "path-explore" || parsed.mode === "mixed" || parsed.mode === "direct-path") {
            var result = buildExploreResults(parsed);
            print("FILES BACKEND: path-explore result children=" + (result ? (result.children || []).length : 0) + " mode=" + parsed.mode + " path=" + parsed.concretePath);
            return result;
        }

        if (parsed.mode === "flat-search") {
            var result = buildFlatSearchResults(parsed, query, context);
            print("FILES BACKEND: flat-search result children=" + (result ? (result.children || []).length : 0));
            return result;
        }

        print("FILES BACKEND: no matching mode=" + parsed.mode);
        return null;
    }

    function buildExploreResults(parsed) {
        tracer.debug("buildExploreResults", function() { return { mode: parsed.mode, concretePath: parsed.concretePath }; });
        var children = [];
        if (parsed.concretePath) {
            var home = StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "");
            var display = parsed.concretePath.replace(home, "~");
            var resolution = root.filePathResolver.resolveFileQuery(parsed, root.maxResults);

            var nodeOpts = {
                id: "file:" + parsed.concretePath,
                kind: parsed.isDirectory !== false ? "directory-result" : "file-result",
                label: parsed.concretePath.split("/").pop(),
                subtitle: display,
                path: parsed.concretePath,
                keywords: [parsed.concretePath, parsed.concretePath.split("/").pop()],
                showWhenQueryEmpty: true
            };

            if (resolution && resolution.resolution) {
                nodeOpts.meta = {
                    path: parsed.concretePath,
                    fileResolution: resolution.resolution
                };
                if (resolution.resolution.unresolvedTokens && resolution.resolution.unresolvedTokens.length > 0)
                    nodeOpts.subtitle = display + " (? " + resolution.resolution.unresolvedTokens.map(function(t) { return t.raw; }).join(" ") + ")";
                if (resolution.resolution.alternatives && resolution.resolution.alternatives.length > 0)
                    nodeOpts.alternatives = resolution.resolution.alternatives;
            }

            children.push(root.nodeDto(nodeOpts));
        }

        return root.backendRootDto(children, {
            subtitle: "Path Explorer",
            evaluationProfile: EvalProfiles.fileProfile()
        });
    }

    function buildFlatSearchResults(parsed, query, context) {
        tracer.debug("buildFlatSearchResults", function() { return { mode: parsed.mode, hasDirective: !!(context?.directive?.active) }; });
        const rawQuery = context && context.directive && context.directive.active ? context.directive.raw : (query ? query.raw : "");
        const pathQuery = expandHome(fileQueryText(rawQuery));
        const seenPaths = {};
        const children = [];

        var resolution = root.filePathResolver.resolveFileQuery(parsed, root.maxResults);

        if (pathQuery.length > 0) {
            const parts = pathQuery.split("/");
            const filename = parts[parts.length - 1] || "";
            const looksLikeDir = filename.indexOf(".") === -1;
            var node = nodeForPath(pathQuery, 0, undefined, undefined, undefined, looksLikeDir);
            if (resolution && resolution.resolution)
                node.meta = node.meta || {}, node.meta.fileResolution = resolution.resolution;
            children.push(node);
            seenPaths[pathQuery] = true;
        }

        (root.compositeResults || []).forEach(function(result, index) {
            const metadata = result.metadata || {};
            const path = metadata.path || result.subtitle || result.title || "";
            if (!path || seenPaths[path])
                return;
            seenPaths[path] = true;
            children.push(nodeForPath(path, index + 1, result.title, result.subtitle, result.icon));
        });

        return root.backendRootDto(children, {
            subtitle: root.compositeQuery ? qsTr("Results for %1").arg(root.compositeQuery) : root.helpDescription,
            evaluationProfile: EvalProfiles.fileProfile()
        });
    }

    function nodeForPath(path, index, title, subtitle, icon, isDir) {
        const parts = path.split("/");
        const label = title || parts[parts.length - 1] || path;
        var opts = {
            id: "file:" + path,
            kind: isDir ? "directory-result" : "file-result",
            label: label,
            subtitle: subtitle || displayPath(path),
            icon: icon || iconForPath(path),
            path: path,
            keywords: [path, label],
            showWhenQueryEmpty: true,
            usageCount: Math.max(0, root.maxResults - index),
            lastUsedDaysAgo: 9999,
            actionList: [
                root.actionDto("open", qsTr("Open", "action: open file"), { path: path, actionId: "open" }),
                root.actionDto("open-folder", qsTr("Open Folder"), { path: path, actionId: "open-folder" }),
                root.actionDto("copy-path", qsTr("Copy Path"), { path: path, actionId: "copy-path" })
            ],
            meta: { path: path }
        };
        if (isDir) {
            opts.children = root.lazyNodeCache[path] || [];
            opts.lazy = opts.children.length === 0;
        }
        return root.nodeDto(opts);
    }

    function buildCommand(queryText) {
        const text = fileQueryText(queryText);
        if (!text)
            return [];

        const path = text[0] === "/" || text[0] === "~" ? expandHome(text) : root.searchRoot + "/" + text;
        const slash = path.lastIndexOf("/");
        const folder = slash > 0 ? path.slice(0, slash) : "/";
        const name = slash >= 0 ? path.slice(slash + 1) : path;
        return ["fd", "--absolute-path", "--max-results", root.maxResults.toString(), name || ".", folder];
    }

    function fileQueryText(queryText) {
        const text = String(queryText || "").trim();
        if (text.indexOf("file://") === 0)
            return text.slice(7);
        return text.replace(/^@files?(\s+|$)/, "").trim();
    }

    function parseOutput(text, queryText) {
        const lines = (text || "").trim().split("\n").filter(line => line.length > 0);
        return lines.slice(0, root.maxResults).map((line, index) => resultForPath(line, index));
    }

    function expandHome(path) {
        if (path === "~")
            return StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "");
        if (path.indexOf("~/") === 0)
            return StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + path.slice(1);
        return path;
    }

    function displayPath(path) {
        const home = StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "");
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

    function resultForPath(path, index) {
        const parts = path.split("/");
        const title = parts[parts.length - 1] || path;

        return {
            id: "file:" + path,
            title: title,
            subtitle: displayPath(path),
            icon: iconForPath(path),
            metadata: { path: path }
        };
    }

    function activate(result, action) {
        tracer.info("activate", function() { return { path: result?.metadata?.path || action?.payload?.path, actionId: action?.id }; });
        if (TestMode.isActive) {
            print("FILES BACKEND: test mode, skipping file activation");
            return;
        }
        const payload = action && action.payload ? action.payload : null;
        const metadata = result ? result.metadata || {} : {};
        if (!result || !(metadata.path || payload && payload.path))
            return;

        const path = metadata.path || payload.path;
        if (!action || action.id === "open") {
            Quickshell.execDetached({ command: ["xdg-open", path] });
        } else if (action.id === "open-folder") {
            const folder = path.slice(0, path.lastIndexOf("/")) || "/";
            Quickshell.execDetached({ command: ["xdg-open", folder] });
        } else if (action.id === "copy-path") {
            Quickshell.execDetached({ command: ["wl-copy", path] });
        }
    }
}
