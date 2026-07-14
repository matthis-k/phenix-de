import QtQml
import qs.services

QtObject {
    id: root

    readonly property var tracer: Logger.scope("backend.tree.switchActionInferer", { category: "backend" })
    readonly property var prof: Profiler.scope("backend.tree.switchActionInferer", { category: "backend" })

    property var nodeFactory: null

    function switchActionMap(node, children) {
        tracer.trace("switchActionMap", function() { return { nodeId: node?.id, childCount: (children || []).length }; });
        const byState = {};
        for (const child of children || []) {
            const leafAction = child.actionList && child.actionList[0];
            const payload = leafAction && leafAction.payload || {};
            const id = String(child.label || child.id || "").toLowerCase();
            if (!leafAction)
                continue;
            if (!byState.toggle && (payload.state === null || id.indexOf("toggle") >= 0))
                byState.toggle = root._makeActionDto("toggle", qsTr("Toggle"), leafAction.payload || leafAction);
            else if (!byState.off && (payload.state === false || payload.state === "disconnect" || id.indexOf("off") >= 0 || id.indexOf("disable") >= 0 || id.indexOf("disconnect") >= 0))
                byState.off = root._makeActionDto("off", qsTr("Off"), leafAction.payload || leafAction);
            else if (!byState.on && (payload.state === true || payload.state === "connect" || id.indexOf("on") >= 0 || id.indexOf("enable") >= 0 || id.indexOf("connect") >= 0))
                byState.on = root._makeActionDto("on", qsTr("On"), leafAction.payload || leafAction);
        }
        return byState.on && byState.off && byState.toggle ? byState : null;
    }

    function actionDtosForSwitchActions(switchActions) {
        if (!switchActions) {
            tracer.trace("actionDtosForSwitchActions", function() { return { result: "null" }; });
            return null;
        }
        var out = {};
        for (var key in switchActions) {
            var action = switchActions[key];
            if (!action)
                continue;
            var extra = {};
            if (action.state !== undefined) extra.state = action.state;
            out[key] = root._makeActionDto(action.id || key, action.title || action.label || key, action.payload || action, extra);
        }
        return out;
    }

    function _makeActionDto(id, label, payload, extraProps) {
        tracer.trace("_makeActionDto", function() { return { id: id, label: label, hasPayload: !!payload, hasExtra: !!extraProps }; });
        var dto;
        if (root.nodeFactory) {
            dto = root.nodeFactory.actionDto(id, label, payload);
        } else {
            dto = { id: id, label: label || id, icon: null, default: false, payload: payload || null };
        }
        if (extraProps) {
            for (var k in extraProps) {
                if (extraProps.hasOwnProperty(k))
                    dto[k] = extraProps[k];
            }
        }
        return dto;
    }
}
