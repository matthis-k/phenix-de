import QtQml
import qs.services

QtObject {
    id: root

    readonly property var tracer: Logger.scope("launcher.textMatchUtils", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.textMatchUtils", { category: "launcher" })

    property var _normCache: ({})
    property int _normCacheSize: 0
    readonly property int _normCacheMax: 200

    function clamp(n, min, max) {
        return Math.max(min === undefined ? 0 : min, Math.min(max === undefined ? 1 : max, n));
    }

    function normalizeText(text) {
        var value = typeof text === "string" ? text : (text === undefined || text === null ? "" : String(text));
        tracer.trace("normalizeText", function() { return { inputLen: value.length, cached: _normCache[value] !== undefined }; });
        if (!value) return "";
        var cached = _normCache[value];
        if (cached !== undefined) return cached;
        var result = value;
        if (result.normalize)
            result = result.normalize("NFKD").replace(/[\u0300-\u036f]/g, "");
        result = result.toLowerCase();
        if (_normCacheSize < _normCacheMax) {
            _normCache[value] = result;
            _normCacheSize += 1;
        }
        return result;
    }

    function splitWordsWithRanges(text) {
        var source = typeof text === "string" ? text : (text === undefined || text === null ? "" : String(text));
        if (!source) return [];
        var words = [];
        var re = /[A-Za-z0-9]+/g;
        var match;
        while ((match = re.exec(source)) !== null) {
            words.push({
                raw: match[0],
                norm: normalizeText(match[0]),
                start: match.index,
                end: match.index + match[0].length
            });
        }
        return words;
    }

    function compactWithMap(text) {
        var source = typeof text === "string" ? text : (text === undefined || text === null ? "" : String(text));
        if (!source) return { compact: "", map: [] };
        var chars = [];
        var map = [];
        var len = source.length;
        for (var i = 0; i < len; i += 1) {
            var c = source[i];
            if (c >= "a" && c <= "z") {
                chars.push(c);
                map.push(i);
            } else if (c >= "A" && c <= "Z") {
                chars.push(c.toLowerCase());
                map.push(i);
            } else if (c >= "0" && c <= "9") {
                chars.push(c);
                map.push(i);
            }
        }
        return { compact: chars.join(""), map: map };
    }

    function fuzzyMaxDistance(text) {
        var len = String(text || "").length;
        if (len >= 6) return 2;
        if (len >= 4) return 1;
        return 0;
    }

    function containsCharacterMultiset(haystack, needle) {
        haystack = String(haystack || "");
        needle = String(needle || "");
        if (needle.length > haystack.length)
            return false;
        var counts = {};
        for (var i = 0; i < haystack.length; i += 1)
            counts[haystack[i]] = (counts[haystack[i]] || 0) + 1;
        for (var j = 0; j < needle.length; j += 1) {
            if (!counts[needle[j]])
                return false;
            counts[needle[j]] -= 1;
        }
        return true;
    }

    function fuzzyDistanceLimit(a, b) {
        var limit = fuzzyMaxDistance(a);
        if (String(a || "").length >= 3 && containsCharacterMultiset(b, a))
            limit = Math.max(limit, 2);
        return limit;
    }

    function boundedDamerauLevenshtein(a, b, maxDistance) {
        a = String(a || "");
        b = String(b || "");
        maxDistance = maxDistance || 0;
        if (a === b)
            return 0;
        if (!maxDistance || Math.abs(a.length - b.length) > maxDistance)
            return maxDistance + 1;
        var prevPrev = [];
        var prev = [];
        var cur = [];
        for (var j = 0; j <= b.length; j += 1)
            prev[j] = j;
        for (var i = 1; i <= a.length; i += 1) {
            cur = [i];
            var rowMin = cur[0];
            for (var bj = 1; bj <= b.length; bj += 1) {
                var cost = a[i - 1] === b[bj - 1] ? 0 : 1;
                var value = Math.min(prev[bj] + 1, cur[bj - 1] + 1, prev[bj - 1] + cost);
                if (i > 1 && bj > 1 && a[i - 1] === b[bj - 2] && a[i - 2] === b[bj - 1])
                    value = Math.min(value, prevPrev[bj - 2] + 1);
                cur[bj] = value;
                rowMin = Math.min(rowMin, value);
            }
            if (rowMin > maxDistance)
                return maxDistance + 1;
            prevPrev = prev;
            prev = cur;
        }
        return prev[b.length];
    }

    function getAcronymRanges(text) {
        var words = splitWordsWithRanges(text);
        if (!words.length) return [];
        var out = [];
        for (var i = 0; i < words.length; i += 1) {
            var w = words[i];
            var ch = w.norm[0];
            if (ch) out.push({ char: ch, start: w.start, end: Math.min(w.start + 1, w.end), word: w });
        }
        return out;
    }

    function countKeys(obj) {
        if (!obj) return 0;
        var count = 0;
        for (var key in obj) count += 1;
        return count;
    }

    function nowMs() {
        return Date.now();
    }
}
