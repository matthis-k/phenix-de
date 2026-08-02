.pragma library

var KINDS = [
    "evidence",
    "boost",
    "childVisible",
    "tokenFlow",
    "takeoverRequest",
    "takeoverAccept",
    "expand",
    "retainParent",
    "defaultAction",
    "riskGate",
    "nesting",
    "childBypass"
];

var _entries = {};
for (var i = 0; i < KINDS.length; i += 1)
    _entries[KINDS[i]] = {};

function requireKind(kind) {
    var entries = _entries[kind];
    if (!entries)
        throw new Error("Unknown launcher policy kind: " + kind);
    return entries;
}

function register(kind, name, policy) {
    if (!name || typeof name !== "string")
        throw new Error("Launcher policy name must be a non-empty string");

    var entries = requireKind(kind);
    if (entries[name])
        console.warn("PolicyCatalog: overwriting existing policy '" + name + "' in " + kind);
    entries[name] = policy;
}

function resolve(kind, name) {
    if (!name)
        return null;
    return requireKind(kind)[name] || null;
}

function list(kind) {
    return Object.keys(requireKind(kind));
}

function remove(kind, name) {
    delete requireKind(kind)[name];
}

function clear(kind) {
    if (kind) {
        _entries[kind] = {};
        return;
    }
    for (var i = 0; i < KINDS.length; i += 1)
        _entries[KINDS[i]] = {};
}

function toDto() {
    var policies = {};
    for (var i = 0; i < KINDS.length; i += 1) {
        var kind = KINDS[i];
        var entries = requireKind(kind);
        policies[kind] = Object.keys(entries).map(function(name) {
            var policy = entries[name] || {};
            return {
                name: name,
                phase: policy.phase || kind,
                group: policy.group || null
            };
        });
    }
    return {
        kinds: KINDS.slice(),
        policies: policies
    };
}
