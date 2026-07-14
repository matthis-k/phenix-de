.pragma library

function makeRegistry() {
    var _r = {};
    return {
        register: function(name, policy) {
            if (!name || typeof name !== "string")
                throw new Error("PolicyRegistry: name must be a non-empty string");
            if (_r[name])
                console.warn("PolicyRegistry: overwriting existing policy '" + name + "'");
            _r[name] = policy;
        },
        get: function(name) {
            return _r[name] || null;
        },
        list: function() {
            return Object.keys(_r);
        },
        "delete": function(name) {
            if (_r[name]) {
                delete _r[name];
            }
        },
        clear: function() {
            _r = {};
        }
    };
}

var evidence = makeRegistry();
var boost = makeRegistry();
var childVisible = makeRegistry();
var tokenFlow = makeRegistry();
var takeoverRequest = makeRegistry();
var takeoverAccept = makeRegistry();
var expand = makeRegistry();
var retainParent = makeRegistry();
var defaultAction = makeRegistry();
var riskGate = makeRegistry();
var nesting = makeRegistry();
var childBypass = makeRegistry();
