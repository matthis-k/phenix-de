import QtQml

QtObject {
    id: root

    required property var catalog

    function resolve(kind, spec) {
        if (!root.catalog || typeof root.catalog.resolve !== "function")
            throw new Error("Launcher PolicyResolver requires a catalog dependency");

        var name = typeof spec === "string" ? spec : spec && spec.name;
        if (!name)
            return null;
        return root.catalog.resolve(kind, name);
    }

    function list(kind) {
        return root.catalog && typeof root.catalog.list === "function"
            ? root.catalog.list(kind)
            : [];
    }

    function toDto() {
        return root.catalog && typeof root.catalog.toDto === "function"
            ? root.catalog.toDto()
            : { kinds: [], policies: {} };
    }
}
