// Canonical launcher entry data normalization.
//
// Authored entries own two distinct data layers:
//   - display: visible representation
//   - match: supplemental vocabulary and matching policy
//
// Display text is matchable by default. Match configuration may adjust weights
// or exclude individual display fields without duplicating their values.

function isObject(value) {
    return value !== null && value !== undefined && typeof value === "object" && !Array.isArray(value);
}

function hasOwn(object, key) {
    return isObject(object) && Object.prototype.hasOwnProperty.call(object, key);
}

function objectValue(value) {
    return isObject(value) ? value : {};
}

function arrayValue(value) {
    if (Array.isArray(value))
        return value.slice();
    if (value === null || value === undefined || value === "")
        return [];
    return [value];
}

function mergeObjects(base, overrides) {
    var out = {};
    var left = objectValue(base);
    var right = objectValue(overrides);
    var key;
    for (key in left) {
        if (hasOwn(left, key))
            out[key] = left[key];
    }
    for (key in right) {
        if (hasOwn(right, key))
            out[key] = right[key];
    }
    return out;
}

function firstDefined(values, fallback) {
    for (var i = 0; i < values.length; i += 1) {
        if (values[i] !== undefined && values[i] !== null)
            return values[i];
    }
    return fallback;
}

function displayFor(source) {
    source = source || {};

    // `presentation` was the previous extension point. Preserve it as display
    // metadata while allowing the explicit `display` object to override it.
    var legacyPresentation = objectValue(source.presentation);
    var explicit = objectValue(source.display);
    var display = mergeObjects(legacyPresentation, explicit);

    var title = hasOwn(explicit, "title")
        ? explicit.title
        : firstDefined([source.title, source.label, source.name, source.id], "");
    var subtitle = hasOwn(explicit, "subtitle")
        ? explicit.subtitle
        : firstDefined([source.subtitle], "");
    var icon = hasOwn(explicit, "icon")
        ? explicit.icon
        : firstDefined([source.icon], null);
    var iconColor = hasOwn(explicit, "iconColor")
        ? explicit.iconColor
        : firstDefined([source.iconColor], null);

    display.title = String(title === undefined || title === null ? "" : title);
    display.subtitle = String(subtitle === undefined || subtitle === null ? "" : subtitle);
    display.icon = icon === undefined ? null : icon;
    display.iconColor = iconColor === undefined ? null : iconColor;

    return display;
}

function matchFor(source) {
    source = source || {};
    var explicit = objectValue(source.match);
    var match = mergeObjects({}, explicit);

    match.aliases = hasOwn(explicit, "aliases")
        ? arrayValue(explicit.aliases)
        : arrayValue(source.aliases);
    match.keywords = hasOwn(explicit, "keywords")
        ? arrayValue(explicit.keywords)
        : arrayValue(source.keywords);
    match.tags = hasOwn(explicit, "tags")
        ? arrayValue(explicit.tags)
        : arrayValue(source.tags);
    match.semanticTerms = hasOwn(explicit, "semanticTerms")
        ? arrayValue(explicit.semanticTerms)
        : arrayValue(source.semanticTerms);
    match.semanticBoostRequiresAny = hasOwn(explicit, "semanticBoostRequiresAny")
        ? arrayValue(explicit.semanticBoostRequiresAny)
        : arrayValue(source.semanticBoostRequiresAny);

    match.fields = mergeObjects({}, explicit.fields);
    match.fieldWeights = mergeObjects(source.fieldWeights, explicit.fieldWeights);

    if (!hasOwn(explicit, "tokenPolicy") && source.tokenPolicy !== undefined)
        match.tokenPolicy = source.tokenPolicy;
    if (!hasOwn(explicit, "evaluationProfile") && source.evaluationProfile !== undefined)
        match.evaluationProfile = source.evaluationProfile;
    if (!hasOwn(explicit, "command") && source.command !== undefined)
        match.command = source.command;
    if (!hasOwn(explicit, "path") && source.path !== undefined)
        match.path = source.path;
    if (!hasOwn(explicit, "usageCount") && source.usageCount !== undefined)
        match.usageCount = source.usageCount;
    if (!hasOwn(explicit, "lastUsedDaysAgo") && source.lastUsedDaysAgo !== undefined)
        match.lastUsedDaysAgo = source.lastUsedDaysAgo;

    return match;
}

function fieldRule(match, fieldName, defaultWeight, defaultEnabled) {
    match = objectValue(match);
    var configuredWeights = objectValue(match.fieldWeights);
    var weight = hasOwn(configuredWeights, fieldName)
        ? Number(configuredWeights[fieldName])
        : Number(defaultWeight);
    var enabled = defaultEnabled !== false;

    var fields = objectValue(match.fields);
    if (hasOwn(fields, fieldName)) {
        var rule = fields[fieldName];
        if (rule === false) {
            enabled = false;
        } else if (rule === true) {
            enabled = true;
        } else if (typeof rule === "number") {
            enabled = true;
            weight = Number(rule);
        } else if (isObject(rule)) {
            if (hasOwn(rule, "enabled"))
                enabled = rule.enabled !== false;
            if (hasOwn(rule, "weight"))
                weight = Number(rule.weight);
        }
    }

    if (!isFinite(weight))
        weight = Number(defaultWeight);

    return {
        enabled: enabled,
        weight: weight
    };
}
