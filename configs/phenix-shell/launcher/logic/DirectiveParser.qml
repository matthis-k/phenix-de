import QtQml
import qs.services

QtObject {
    id: root

    readonly property var tracer: Logger.scope("launcher.directiveParser", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.directiveParser", { category: "launcher" })

    function parseDirective(rawQuery, backends) {
        tracer.trace("parseDirective", function() { return { rawQuery: rawQuery, backendCount: (backends || []).length }; });
        var raw = String(rawQuery || "");
        var trimmed = raw.replace(/^\s+/, "");
        var directives = [];
        for (var i = 0; i < (backends || []).length; i += 1) {
            var backend = backends[i];
            var prefixes = backend && backend.helpPrefixes ? backend.helpPrefixes : [];
            for (var pi = 0; pi < prefixes.length; pi += 1) {
                directives.push({ prefix: prefixes[pi], backendIds: [backend.backendId], label: backend.helpTitle || backend.name || backend.backendId });
            }
        }
        directives.sort(function(a, b) { return b.prefix.length - a.prefix.length; });
        for (var di = 0; di < directives.length; di += 1) {
            var d = directives[di];
            if (!d.prefix || trimmed.indexOf(d.prefix) !== 0)
                continue;
            var next = trimmed[d.prefix.length];
            var compactPrefix = d.prefix.length === 1 && (d.prefix === ":" || d.prefix === "=");
            if (!compactPrefix && next !== undefined && !/\s/.test(next) && next !== ":" && next !== "/")
                continue;
            return {
                active: true, raw: raw, searchRaw: trimmed.slice(d.prefix.length).replace(/^[:\s]+/, ""),
                prefix: d.prefix, label: d.label, tags: [], kinds: [], backendIds: d.backendIds
            };
        }
        return { active: false, raw: raw, searchRaw: raw, prefix: "", label: "All", tags: [], kinds: [], backendIds: [] };
    }
}
