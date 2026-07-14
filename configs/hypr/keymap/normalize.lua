local aliases = require("keymap.aliases")

local normalize = {}

normalize.defaults = {
    tap_ms = 250,
    hold_ms = 500,
    long_ms = 900,
    repeat_delay_ms = 500,
    repeat_ms = 40,
    consume = {
        held = "participate",
        trigger = "auto",
    },
    chord_lifetime = "trigger",
    held_release = "keep",
    held_required_until = "trigger_down",
    tap_requires = "free",
    ambiguous_press = "delay",
    duplicate_chords = "error",
    conflict_resolution = "most_specific_wins",
    unknown_chord_policy = "registered_only",
    long_policy = "after_hold",
}

local timing_fields = {
    "tap_ms",
    "hold_ms",
    "long_ms",
    "repeat_delay_ms",
    "repeat_ms",
}

local action_fields = {
    "press",
    "tap",
    "hold",
    "long",
    "repeat_",
    "release",
}

local function copy(value)
    if type(value) ~= "table" then
        return value
    end

    local out = {}

    for key, child in pairs(value) do
        out[key] = copy(child)
    end

    return out
end

local function merge(base, override)
    local out = copy(base or {})

    for key, value in pairs(override or {}) do
        if type(value) == "table" and type(out[key]) == "table" then
            out[key] = merge(out[key], value)
        else
            out[key] = copy(value)
        end
    end

    return out
end

local function list_copy(list)
    local out = {}

    for index, value in ipairs(list or {}) do
        out[index] = value
    end

    return out
end

local function action_count(actions)
    local total = 0

    for _, phase in ipairs(action_fields) do
        if actions[phase] ~= nil then
            total = total + 1
        end
    end

    return total
end

local function normalize_actions(raw)
    local actions = {}

    if raw.action ~= nil then
        actions.press = raw.action
    end

    for _, phase in ipairs(action_fields) do
        if raw[phase] ~= nil then
            actions[phase] = raw[phase]
        end
    end

    for phase, action in pairs(raw.actions or {}) do
        if phase == "repeat" then
            actions.repeat_ = action
        else
            actions[phase] = action
        end
    end

    return actions
end

local function apply_timing(base, raw)
    local timing = copy(base)

    for _, field in ipairs(timing_fields) do
        if raw[field] ~= nil then
            timing[field] = raw[field]
        end
    end

    return timing
end

local function default_hypr_name(name, raw_name)
    if #raw_name == 1 and raw_name:match("%a") then
        return raw_name:upper()
    end

    if name:match("^mouse:") or name:match("^code:") then
        return name
    end

    return raw_name
end

local function normalize_key_definition(name, raw, defaults)
    local raw_name = raw.raw_name or name
    local key = copy(raw)

    key.name = name
    key.raw_name = nil
    key.actions = normalize_actions(raw)
    key.defaults = apply_timing(defaults, raw)
    key.long_policy = raw.long_policy or defaults.long_policy
    key.description = raw.description

    if key.hypr == nil then
        key.hypr = key.modifier or default_hypr_name(name, raw_name)
    end

    if key.physical == nil then
        key.physical = { key.hypr or raw_name }
    else
        key.physical = list_copy(key.physical)
    end

    return key
end

local function ensure_key(keys, token, defaults)
    local token_text = tostring(token)
    local name = aliases.normalize_name(token_text)

    if keys[name] ~= nil then
        return name
    end

    keys[name] = normalize_key_definition(name, {
        raw_name = token_text,
        physical = { token_text },
        hypr = default_hypr_name(name, token_text),
    }, defaults)

    return name
end

local function build_keys(raw_config, defaults)
    local keys = {}

    for name, raw in pairs(aliases.builtins) do
        keys[name] = normalize_key_definition(name, raw, defaults)
    end

    for raw_name, raw in pairs(raw_config.keys or {}) do
        local name = aliases.normalize_name(raw_name)
        local merged = merge(keys[name] or {}, raw)
        merged.raw_name = raw_name
        keys[name] = normalize_key_definition(name, merged, defaults)
    end

    return keys
end

local function canonical_chord_id(layer, held, trigger)
    local held_id = table.concat(held, "+")
    return "layer:" .. layer .. "|held:" .. held_id .. "|trigger:" .. trigger
end

local function normalize_repeat(raw, actions, timing)
    local repeat_config = raw["repeat"]

    if repeat_config == nil and raw.repeat_ ~= nil then
        repeat_config = true
    end

    if repeat_config == nil and actions.repeat_ ~= nil and actions.tap ~= nil and actions.hold ~= nil then
        repeat_config = { phase = "hold" }
    end

    local repeat_out = {
        enabled = false,
        phase = "press",
        delay_ms = timing.repeat_delay_ms,
        every_ms = timing.repeat_ms,
    }

    if repeat_config == true then
        repeat_out.enabled = true
        if actions.press == nil and actions.hold ~= nil then
            repeat_out.phase = "hold"
        end
    elseif type(repeat_config) == "table" then
        repeat_out.enabled = repeat_config.enabled ~= false
        repeat_out.phase = repeat_config.phase or repeat_out.phase
        repeat_out.delay_ms = repeat_config.delay_ms or repeat_config.repeat_delay_ms or repeat_out.delay_ms
        repeat_out.every_ms = repeat_config.every_ms or repeat_config.repeat_ms or repeat_out.every_ms
    end

    if repeat_out.enabled and actions.repeat_ == nil then
        actions.repeat_ = actions[repeat_out.phase]
    end

    return repeat_out
end

local function rule_has_waiting_phase(rule)
    return rule.actions.tap ~= nil
        or rule.actions.hold ~= nil
        or rule.actions.long ~= nil
        or rule.actions.release ~= nil
end

local function normalize_rule(raw, index, keys, defaults)
    if raw.chord == nil then
        error("keymap bind #" .. index .. " is missing chord")
    end

    if raw.chord.trigger == nil then
        error("keymap bind #" .. index .. " is missing chord.trigger")
    end

    local layer = raw.layer or "global"
    local held = {}

    for _, token in ipairs(raw.chord.held or {}) do
        held[#held + 1] = ensure_key(keys, token, defaults)
    end

    table.sort(held)

    local trigger = ensure_key(keys, raw.chord.trigger, defaults)
    local trigger_key = keys[trigger]
    local timing = apply_timing(trigger_key.defaults or defaults, raw)
    local actions = normalize_actions(raw)
    local preset = raw.preset

    if preset == nil then
        if actions.tap ~= nil and actions.hold ~= nil and actions.press == nil then
            preset = "dual"
        else
            preset = "normal"
        end
    end

    if action_count(actions) == 0 then
        error("keymap bind #" .. index .. " has no actions")
    end

    local consume = merge(defaults.consume, raw.consume or {})

    if raw.consume == nil or raw.consume.held == nil then
        for _, held_key in ipairs(held) do
            if keys[held_key] ~= nil and keys[held_key].preset == "leader" then
                consume.held = "full"
                break
            end
        end
    end

    if preset == "dual" then
        consume.trigger = raw.consume and raw.consume.trigger or "reserve"
    elseif preset == "leader" then
        consume.held = raw.consume and raw.consume.held or "full"
    end

    local rule = {
        id = canonical_chord_id(layer, held, trigger),
        index = index,
        layer = layer,
        preset = preset,
        chord = {
            held = held,
            trigger = trigger,
        },
        actions = actions,
        timing = timing,
        consume = consume,
        lifetime = raw.lifetime or defaults.chord_lifetime,
        held_release = raw.held_release or defaults.held_release,
        held_required_until = raw.held_required_until or defaults.held_required_until,
        ambiguous_press = raw.ambiguous_press or defaults.ambiguous_press,
        long_policy = raw.long_policy or defaults.long_policy,
        description = raw.description,
        trigger_exact = tostring(raw.chord.trigger) == keys[trigger].hypr,
    }

    rule.repeat_ = normalize_repeat(raw, actions, timing)
    rule.has_waiting_phase = rule_has_waiting_phase(rule)

    if rule.consume.trigger == "auto" then
        if rule.has_waiting_phase then
            rule.resolved_trigger_consume = "reserve"
        else
            rule.resolved_trigger_consume = "full"
        end
    else
        rule.resolved_trigger_consume = rule.consume.trigger
    end

    return rule
end

local function build_physical_lookup(keys)
    local lookup = {}

    for name, key in pairs(keys) do
        lookup[name] = name

        if key.hypr ~= nil then
            lookup[key.hypr] = name
            lookup[key.hypr:lower()] = name
        end

        for _, physical in ipairs(key.physical or {}) do
            lookup[physical] = name
            lookup[tostring(physical):lower()] = name
        end
    end

    return lookup
end

local function build_rules(raw_config, keys, defaults)
    local rules = {}
    local rules_by_id = {}
    local rules_by_trigger = {}
    local layers = { global = {} }

    for index, raw in ipairs(raw_config.binds or {}) do
        local rule = normalize_rule(raw, index, keys, defaults)

        if rules_by_id[rule.id] ~= nil then
            error("duplicate keymap chord: " .. rule.id)
        end

        rules[#rules + 1] = rule
        rules_by_id[rule.id] = rule
        rules_by_trigger[rule.chord.trigger] = rules_by_trigger[rule.chord.trigger] or {}
        rules_by_trigger[rule.chord.trigger][#rules_by_trigger[rule.chord.trigger] + 1] = rule
        layers[rule.layer] = layers[rule.layer] or {}
        layers[rule.layer][#layers[rule.layer] + 1] = rule
    end

    return rules, rules_by_id, rules_by_trigger, layers
end

function normalize.hypr_key(key)
    if key.modifier ~= nil then
        return key.modifier
    end

    return key.hypr or aliases.display_for_token(key.name)
end

function normalize.hypr_chord(rule, keys)
    local parts = {}

    for _, held in ipairs(rule.chord.held) do
        parts[#parts + 1] = normalize.hypr_key(keys[held])
    end

    parts[#parts + 1] = normalize.hypr_key(keys[rule.chord.trigger])

    return table.concat(parts, " + ")
end

function normalize.map(raw_config)
    local defaults = merge(normalize.defaults, raw_config.defaults or {})
    local keys = build_keys(raw_config, defaults)
    local rules, rules_by_id, rules_by_trigger, layers = build_rules(raw_config, keys, defaults)

    return {
        defaults = defaults,
        keys = keys,
        rules = rules,
        rules_by_id = rules_by_id,
        rules_by_trigger = rules_by_trigger,
        layers = layers,
        physical_to_key = build_physical_lookup(keys),
        unknown_chord_policy = defaults.unknown_chord_policy,
    }
end

return normalize
