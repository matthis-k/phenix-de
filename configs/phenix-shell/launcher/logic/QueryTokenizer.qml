import QtQml
import qs.services

QtObject {
    id: root

    readonly property var tracer: Logger.scope("launcher.queryTokenizer", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.queryTokenizer", { category: "launcher" })

    property var textUtils: null

    function tokenize(rawQuery) {
        tracer.trace("tokenize", function() { return { rawLen: String(rawQuery || "").length }; });
        var raw = typeof rawQuery === "string" ? rawQuery : (rawQuery === undefined || rawQuery === null ? "" : String(rawQuery));
        if (!raw) return { raw: "", normalized: "", tokens: [], isEmpty: true, lastTokenEmpty: false };
        var tokens = [];
        var re = /[^\s:/\\|,;]+/g;
        var match;
        while ((match = re.exec(raw)) !== null) {
            var rawToken = match[0];
            var norm = root.textUtils.normalizeText(rawToken);
            if (!norm) continue;
            tokens.push({ raw: rawToken, normalized: norm, start: match.index, end: match.index + rawToken.length });
        }
        return {
            raw: raw,
            normalized: root.textUtils.normalizeText(raw),
            tokens: tokens,
            isEmpty: tokens.length === 0,
            lastTokenEmpty: raw.charCodeAt(raw.length - 1) === 32 && tokens.length > 0
        };
    }
}
