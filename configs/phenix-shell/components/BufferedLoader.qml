import QtQuick

Item {
    id: root

    property alias source: stagingLoader.source
    property alias sourceComponent: stagingLoader.sourceComponent
    property alias active: stagingLoader.active
    readonly property alias status: stagingLoader.status
    readonly property alias progress: stagingLoader.progress
    readonly property bool hasItem: item !== null

    property Item item: null

    property bool loading: stagingLoader.status === Loader.Loading
    property bool asynchronous: true

    implicitWidth: item ? (item.implicitWidth || item.width || 0) : 0
    implicitHeight: item ? (item.implicitHeight || item.height || 0) : 0

    property var _pendingProps: ({})

    Item {
        id: container
        anchors.fill: parent
    }

    Loader {
        id: stagingLoader
        asynchronous: root.asynchronous
        active: false
        visible: false

        onStatusChanged: {
            if (status === Loader.Error) {
                console.warn("ContinuousLoader: failed to load:", errorString);
            }
        }

        onLoaded: {
            if (!item)
                return;

            const keys = Object.keys(root._pendingProps);
            for (let i = 0; i < keys.length; i++) {
                const k = keys[i];
                try {
                    item[k] = root._pendingProps[k];
                } catch (e) {
                    console.warn("ContinuousLoader: can't set property", k, e);
                }
            }

            item.parent = container;
            item.anchors.fill = container;

            var old = root.item;
            if (old && old !== item) {
                old.destroy();
            }

            root.item = item;

            active = false;
            sourceComponent = null;
            source = "";
            root._pendingProps = ({});
        }
    }

    /// Replace current content with a new component once it's fully loaded.
    /// `component`: Component or null (null = clear)
    /// `props`: object with initial properties for the new item
    function set(component, props) {
        if (!component) {
            clear();
            return;
        }

        stagingLoader.active = false;
        stagingLoader.sourceComponent = null;
        stagingLoader.source = "";

        _pendingProps = props || {};

        stagingLoader.sourceComponent = component;
        stagingLoader.active = true;
    }

    /// Clear current content and cancel any pending load
    function clear() {
        stagingLoader.active = false;
        stagingLoader.sourceComponent = null;
        stagingLoader.source = "";
        _pendingProps = ({});

        if (item) {
            item.destroy();
            item = null;
        }
    }
}
