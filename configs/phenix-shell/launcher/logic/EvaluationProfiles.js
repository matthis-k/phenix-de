// Centralized evaluation profile factories.
// Reduces duplicate inline profile objects in backend files.
// Backends import this instead of defining their own profile functions.
// JS module — no QML type registration, no circular dependency.

function withDefault(value, fallback) {
    return value !== undefined ? value : fallback;
}

function makeProfile(defaults, opts) {
    opts = opts || {};
    var profileKeys = [
        "fields", "evidence", "boost", "childVisible", "tokenFlow",
        "takeoverRequest", "takeoverAccept", "expand", "retainParent",
        "defaultAction", "riskGate"
    ];
    var profile = {};
    var pd = defaults.profile || {};
    for (var ki = 0; ki < profileKeys.length; ki += 1) {
        var key = profileKeys[ki];
        profile[key] = withDefault(opts[key], pd[key] !== undefined ? pd[key] : []);
    }
    return {
        mode: withDefault(opts.mode, defaults.mode || "generic+custom"),
        strategies: withDefault(opts.strategies, defaults.strategies || []),
        scorePolicy: withDefault(opts.scorePolicy, defaults.scorePolicy || "default"),
        profile: profile
    };
}

var GROUP = {
    mode: "generic+custom",
    strategies: ["exact", "prefix", "compact", "substring", "acronym", "fuzzy", "semantic"],
    scorePolicy: "default",
    profile: {
        fields: ["label", "aliases"],
        evidence: ["field-match", "switch-action", "semantic"],
        boost: ["descendant-boost"],
        childVisible: ["visible-flag"],
        tokenFlow: ["consume-namespace-pass-rest"],
        takeoverRequest: ["child-own-match-parent-no-own-match", "explicit-child-token", "child-covers-passed-tokens", "own-score-dominates-takeover"],
        takeoverAccept: ["accept-dominated-claims"],
        expand: ["expand-on-own-match-or-trailing-space"],
        retainParent: [{ name: "retain-parent-when", args: { condition: "own-match" } }],
        defaultAction: ["default-action-expand"],
        riskGate: ["risk-gate"]
    }
};

var SWITCH = {
    mode: "generic+custom",
    strategies: ["exact", "prefix", "compact", "substring", "acronym", "fuzzy", "semantic"],
    scorePolicy: "default",
    profile: {
        fields: ["label", "aliases"],
        evidence: ["field-match", ["field-match", { fields: ["breadcrumb"] }], "switch-action"],
        boost: ["descendant-boost", "switch-aliases"],
        childVisible: ["has-own-score"],
        tokenFlow: ["consume-switch-pass-rest"],
        takeoverRequest: [],
        takeoverAccept: [],
        expand: ["expand-on-own-match-or-trailing-space"],
        retainParent: ["retain-always"],
        defaultAction: ["default-action-owner"],
        riskGate: ["risk-gate"]
    }
};

var APP = {
    mode: "generic+custom",
    strategies: ["exact", "prefix", "compact", "substring", "acronym", "fuzzy", "semantic", "usage", "recency"],
    scorePolicy: "default",
    profile: {
        fields: ["label"],
        evidence: [["field-match", { fields: ["label"] }], "semantic", "usage", "recency"],
        boost: ["descendant-boost"],
        childVisible: ["visible-flag"],
        tokenFlow: ["consume-own-pass-rest"],
        takeoverRequest: ["child-own-match-parent-no-own-match", "explicit-child-token", "child-covers-passed-tokens", "own-score-dominates-takeover"],
        takeoverAccept: ["accept-dominated-claims"],
        expand: ["expand-on-trailing-space"],
        retainParent: [{ name: "retain-parent-when", args: { condition: "own-match" } }],
        defaultAction: ["default-action-owner"],
        riskGate: ["risk-gate"]
    }
};

var VISUAL_ROOT = {
    mode: "generic+custom",
    strategies: ["exact", "prefix", "compact", "substring", "acronym", "fuzzy", "semantic"],
    scorePolicy: "default",
    profile: {
        fields: ["label"],
        evidence: [["field-match", { fields: ["label"] }], "semantic"],
        boost: ["descendant-boost"],
        childVisible: ["visible-flag"],
        tokenFlow: ["pass-all"],
        takeoverRequest: ["child-own-match-parent-no-own-match", "explicit-child-token", "child-covers-passed-tokens", "own-score-dominates-takeover"],
        takeoverAccept: ["accept-dominated-claims"],
        expand: ["expand-on-own-match-or-trailing-space"],
        retainParent: [{ name: "retain-parent-when", args: { condition: "own-match" } }],
        defaultAction: ["default-action-expand"],
        riskGate: ["risk-gate"]
    }
};

var BACKEND_ROOT = {
    mode: "generic",
    strategies: ["exact", "prefix", "compact", "substring", "acronym", "fuzzy"],
    scorePolicy: "backend",
    profile: {
        fields: ["label", "aliases"],
        evidence: ["field-match"],
        boost: [],
        childVisible: ["visible-flag"],
        tokenFlow: ["pass-all"],
        takeoverRequest: [],
        takeoverAccept: [],
        expand: [],
        retainParent: [],
        defaultAction: [],
        riskGate: []
    }
};

var DEFAULT_NODE = {
    mode: "generic+custom",
    strategies: ["exact", "prefix", "compact", "substring", "acronym", "fuzzy", "semantic", "usage", "recency"],
    scorePolicy: "default",
    profile: {
        fields: ["label", "aliases"],
        evidence: ["field-match", "switch-action", "semantic", "token-claim", "usage", "recency"],
        boost: ["descendant-boost"],
        childVisible: ["visible-flag"],
        tokenFlow: ["pass-all"],
        takeoverRequest: [],
        takeoverAccept: [],
        expand: [],
        retainParent: [],
        defaultAction: ["default-action-owner"],
        riskGate: ["risk-gate"]
    }
};

var LEAF = {
    mode: "generic+custom",
    strategies: ["exact", "prefix", "compact", "substring", "acronym", "fuzzy", "semantic", "usage", "recency"],
    scorePolicy: "default",
    profile: {
        fields: ["label", "aliases"],
        evidence: ["field-match", "semantic", "token-claim", "usage", "recency"],
        boost: [],
        childVisible: ["visible-flag"],
        tokenFlow: ["pass-all"],
        takeoverRequest: [],
        takeoverAccept: [],
        expand: [],
        retainParent: [],
        defaultAction: ["default-action-owner"],
        riskGate: ["risk-gate"]
    }
};

var CALCULATOR = {
    mode: "generic+custom",
    strategies: ["exact", "prefix", "compact", "substring", "acronym", "semantic"],
    scorePolicy: "semantic-result",
    profile: {
        fields: ["label", "aliases"],
        evidence: ["field-match", "semantic"],
        boost: [],
        childVisible: ["visible-flag", ["above-min-score", { threshold: 0.25 }]],
        tokenFlow: ["pass-all"],
        takeoverRequest: [],
        takeoverAccept: [],
        expand: ["expand-none"],
        retainParent: ["retain-always"],
        defaultAction: ["default-action-owner"],
        riskGate: ["risk-gate"]
    }
};

var FILE = {
    mode: "generic",
    strategies: ["exact", "prefix", "compact", "substring", "acronym"],
    scorePolicy: "backend",
    profile: {
        fields: ["label", "aliases", "path"],
        evidence: ["field-match", "usage", "recency"],
        boost: ["descendant-boost"],
        childVisible: ["visible-flag", ["above-min-score", { threshold: 0.25 }]],
        tokenFlow: ["consume-path-segment"],
        takeoverRequest: ["explicit-child-token", "child-covers-passed-tokens", "own-score-dominates-takeover"],
        takeoverAccept: ["accept-dominated-claims"],
        expand: ["expand-when"],
        retainParent: ["retain-always"],
        defaultAction: ["default-action-owner"],
        riskGate: ["risk-gate"]
    }
};

function groupProfile(opts) { return makeProfile(GROUP, opts); }
function switchProfile(opts) { return makeProfile(SWITCH, opts); }
function appProfile(opts) { return makeProfile(APP, opts); }
function visualRootProfile(opts) { return makeProfile(VISUAL_ROOT, opts); }
function backendRootProfile(opts) { return makeProfile(BACKEND_ROOT, opts); }
function defaultNodeProfile(opts) { return makeProfile(DEFAULT_NODE, opts); }
function leafProfile(opts) { return makeProfile(LEAF, opts); }
function calculatorProfile(opts) { return makeProfile(CALCULATOR, opts); }
function fileProfile(opts) { return makeProfile(FILE, opts); }
