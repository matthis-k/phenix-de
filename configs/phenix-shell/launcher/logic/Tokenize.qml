pragma Singleton
import QtQml
import Quickshell
import qs.services

Singleton {
    id: root
    readonly property var tracer: Logger.scope("launcher.tokenize", { category: "launcher" })

    property TextMatchUtils matchUtils: TextMatchUtils {}
    property QueryTokenizer queryTokenizer: QueryTokenizer { textUtils: root.matchUtils }
    property DirectiveParser directiveParser: DirectiveParser {}
    property NodeFactory nodeFactory: NodeFactory {}

    function clamp(n, min, max) { return root.matchUtils.clamp(n, min, max); }
    function normalizeText(text) { return root.matchUtils.normalizeText(text); }
    function splitWordsWithRanges(text) { return root.matchUtils.splitWordsWithRanges(text); }
    function compactWithMap(text) { return root.matchUtils.compactWithMap(text); }
    function fuzzyMaxDistance(text) { return root.matchUtils.fuzzyMaxDistance(text); }
    function containsCharacterMultiset(haystack, needle) { return root.matchUtils.containsCharacterMultiset(haystack, needle); }
    function fuzzyDistanceLimit(a, b) { return root.matchUtils.fuzzyDistanceLimit(a, b); }
    function boundedDamerauLevenshtein(a, b, maxDistance) { return root.matchUtils.boundedDamerauLevenshtein(a, b, maxDistance); }
    function getAcronymRanges(text) { return root.matchUtils.getAcronymRanges(text); }
    function tokenize(rawQuery) {
        tracer.trace("tokenize", function() { return { rawLen: (rawQuery || "").length }; });
        return root.queryTokenizer.tokenize(rawQuery);
    }
    function parseDirective(rawQuery, backends) { return root.directiveParser.parseDirective(rawQuery, backends); }
    function makeAction(id, label, payload) { return root.nodeFactory.makeAction(id, label, payload); }
    function makeNode(props) { return root.nodeFactory.makeNode(props); }
    function countKeys(obj) { return root.matchUtils.countKeys(obj); }
    function nowMs() { return root.matchUtils.nowMs(); }
}
