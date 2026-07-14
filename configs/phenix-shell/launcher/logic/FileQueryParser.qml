import QtQml
import Quickshell
import QtCore
import qs.services

QtObject {
    id: root

    readonly property var tracer: Logger.scope("launcher.fileQueryParser", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.fileQueryParser", { category: "launcher" })

    function parseFileQuery(rawQuery) {
        tracer.trace("parseFileQuery", function() { return { rawQuery: rawQuery }; });
        var text = String(rawQuery || "").trim();
        if (!text)
            return { mode: "none", tokens: [], raw: text, directive: null };

        var directive = parseDirective(text);
        var searchText = directive ? directive.searchText : text;

        if (directive && directive.prefix === "@file") {
            if (isSlashPath(searchText))
                return buildPathExplore(searchText, "@file");
            return { mode: "flat-search", tokens: tokenize(searchText), raw: text, directive: directive };
        }

        if (text.indexOf("file://") === 0) {
            var pathText = text.slice(7);
            return buildPathExplore(pathText, "file://");
        }

        if (text === "~" || text.indexOf("~/") === 0 || text.indexOf("/") === 0) {
            return buildPathExplore(text, "path");
        }

        if (text.indexOf("~ ") === 0 || text.indexOf("~  ") === 0) {
            var rest = text.slice(text[1] === " " ? 2 : 3).trim();
            if (rest)
                return { mode: "mixed", anchor: "~", tokens: tokenize(rest), raw: text, directive: null };
            return buildPathExplore("~", "path");
        }

        return { mode: "none", tokens: [], raw: text, directive: null };
    }

    function buildPathExplore(text, source) {
        var home = StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "");
        var expanded = expandHome(text, home);
        var isDir = text[text.length - 1] === "/" || text === "~";

        if (isDir || text.indexOf("/") < 0) {
            return {
                mode: "path-explore",
                anchor: expanded || home,
                tokens: [],
                raw: text,
                directive: null,
                concretePath: expanded,
                isDirectory: true
            };
        }

        var slash = expanded.lastIndexOf("/");
        var anchor = slash >= 0 ? expanded.slice(0, slash) : expanded;
        var filename = slash >= 0 ? expanded.slice(slash + 1) : "";

        return {
            mode: "path-explore",
            anchor: anchor,
            tokens: filename ? [{ raw: filename, normalized: filename.toLowerCase() }] : [],
            raw: text,
            directive: null,
            concretePath: expanded,
            isDirectory: false
        };
    }

    function parseDirective(text) {
        var match = /^@files?\s+(.*)/.exec(text);
        if (match)
            return { prefix: "@file", searchText: match[1].trim() };
        return null;
    }

    function isSlashPath(text) {
        return text.indexOf("~/") === 0 || text.indexOf("/") === 0 || text === "~";
    }

    function expandHome(path, home) {
        if (!home)
            home = StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "");
        if (path === "~")
            return home;
        if (path.indexOf("~/") === 0)
            return home + path.slice(1);
        return path;
    }

    function tokenize(text) {
        if (!text) return [];
        var words = text.split(/\s+/).filter(function(w) { return w.length > 0; });
        return words.map(function(w) {
            return { raw: w, normalized: w.toLowerCase() };
        });
    }

    function queryModeLabel(mode) {
        switch (mode) {
        case "path-explore": return "Path Explorer";
        case "flat-search": return "File Search";
        case "direct-path": return "Direct Path";
        case "mixed": return "Mixed Search";
        default: return "";
        }
    }
}
