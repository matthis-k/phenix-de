import "tree" as Tree

Node {
    template: "action-group"

    readonly property var _nodeDefaults: Tree.TreeNodeDefaults {
        defaultPriority: 0
    }

    function defaultGroupProfile() {
        tracer.trace("defaultGroupProfile", function() { return {}; });
        return _nodeDefaults.groupProfile({});
    }

    function toTreeObject() {
        tracer.trace("toTreeObject", function() { return {}; });
        var base = Node.prototype.toTreeObject.call(this);
        if (!base.evaluationProfile && !this.evaluationProfile)
            base.evaluationProfile = defaultGroupProfile();
        return base;
    }
}
