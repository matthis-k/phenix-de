import QtQml
import qs.services

QtObject {
    id: root

    readonly property var tracer: Logger.scope("backend.node", { category: "backend" })
    readonly property var prof: Profiler.scope("backend.node", { category: "backend" })

    default property list<QtObject> entries

    property string nodeId: ""
    property string name: ""
    property string template: ""
    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property var iconColor: null
    property var aliases: []
    property var keywords: []
    property var dynamicChildren: []
    property bool dangerous: false
    property var risk: null
    property var behavior: null
    property var _legacyGroupOptions: ({})
    property var tokenPolicy: null
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
        var id = root.nodeId || root.name || root.title;
        var out = {
            id: id,
            aliases: root.aliases || [],
            keywords: root.keywords || [],
            title: root.title || root.name || id,
            template: root.template,
            subtitle: root.subtitle || "",
            icon: root.icon || "",
            iconColor: root.iconColor,
            dangerous: root.dangerous,
            risk: root.risk,
            behavior: root.behavior,
            tokenPolicy: root.tokenPolicy,
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
