import QtQml
import qs.services
import "../logic/EntryData.js" as EntryData

QtObject {
    id: root

    readonly property var tracer: Logger.scope("backend.node", { category: "backend" })
    readonly property var prof: Profiler.scope("backend.node", { category: "backend" })

    default property list<QtObject> entries

    property string nodeId: ""
    property string name: ""
    property string template: ""

    // Canonical authored data layers. Visible text is matched by default;
    // `match` only supplies vocabulary and matching-policy overrides.
    property var display: ({})
    property var match: ({})

    // Compatibility authoring aliases. Normalization moves these values into
    // `display` and `match`; new entries should prefer the namespaced fields.
    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property var iconColor: null
    property var aliases: []
    property var keywords: []
    property var tokenPolicy: null
    property var evaluationProfile: null

    property var dynamicChildren: []
    property bool dangerous: false
    property var risk: null
    property var behavior: null
    property var _legacyGroupOptions: ({})
    property var action: null
    property var actionProps: ({})
    property string actionId: ""
    property var switchState: undefined
    property var replaceQuery: null

    function childNodes() {
        tracer.trace("childNodes", function() { return { nodeId: root.nodeId, entryCount: root.entries.length, dynamicCount: (root.dynamicChildren || []).length }; });
        var out = [];
        for (var ci = 0; ci < (root.dynamicChildren || []).length; ci += 1)
            out.push(materializeChild(root.dynamicChildren[ci]));
        for (var i = 0; i < root.entries.length; i += 1) {
            var entry = root.entries[i];
            var child = materializeChild(entry);
            if (child)
                out.push(child);
        }
        return out;
    }

    function materializeChild(entry) {
        if (entry && typeof entry.toTreeObject === "function")
            return entry.toTreeObject();
        return entry || null;
    }

    function ownAction() {
        tracer.trace("ownAction", function() { return { nodeId: root.nodeId, hasAction: !!root.action }; });
        var id = root.actionId || root.nodeId || root.name || "run";
        if (typeof root.action === "function") {
            var payload = Object.assign({ actionId: id }, root.actionProps || {});
            payload.execute = root.action;
            return payload;
        }
        if (root.action && typeof root.action === "object")
            return Object.assign({ actionId: id }, root.action);
        return null;
    }

    function toTreeObject() {
        tracer.trace("toTreeObject", function() { return { nodeId: root.nodeId, template: root.template, entryCount: root.entries.length }; });
        var id = root.nodeId || root.name || root.title || root.display.title;
        var displayData = EntryData.displayFor(root);
        var matchData = EntryData.matchFor(root);
        var out = {
            id: id,
            template: root.template,
            display: displayData,
            match: matchData,
            dangerous: root.dangerous,
            risk: root.risk,
            behavior: root.behavior,
            children: childNodes(),
            replaceQuery: root.replaceQuery
        };
        if (root.switchState !== undefined)
            out.switchState = root.switchState;

        var payload = ownAction();
        if (payload)
            out.action = payload;
        return out;
    }
}
