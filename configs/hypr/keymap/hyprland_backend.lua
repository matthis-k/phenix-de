local Engine = require("keymap.engine")
local normalize = require("keymap.normalize")

local backend = {}

local function max(left, right)
    if left > right then
        return left
    end

    return right
end

local function dispatch_action(action)
    if action ~= nil and hl ~= nil and hl.dispatch ~= nil then
        hl.dispatch(action)
    elseif type(action) == "function" then
        action()
    end
end

local function can_compile_native(rule)
    return rule.actions.press ~= nil
        and rule.actions.tap == nil
        and rule.actions.hold == nil
        and rule.actions.long == nil
        and rule.actions.release == nil
end

local function needs_resolver(rule)
    return rule.actions.tap ~= nil
        or rule.actions.hold ~= nil
        or rule.actions.long ~= nil
        or rule.actions.release ~= nil
end

local function key_needs_cycle(key)
    return key.actions.tap ~= nil or key.actions.hold ~= nil or key.actions.long ~= nil or key.actions.release ~= nil
end

local function physical_bind_chords(key)
    local chords = {}

    for _, physical in ipairs(key.physical or {}) do
        if key.modifier ~= nil then
            chords[#chords + 1] = key.modifier .. " + " .. physical
        else
            chords[#chords + 1] = physical
        end
    end

    if #chords == 0 then
        chords[1] = normalize.hypr_key(key)
    end

    return chords
end

local function bind_opts(rule_or_key, extra)
    local opts = extra or {}

    if rule_or_key.description ~= nil then
        opts.description = rule_or_key.description
    end

    return opts
end

local function create_runtime(engine)
    local runtime = {
        timer = nil,
        armed_at = nil,
    }

    local arm

    arm = function()
        local next_at = engine:next_timer_at()

        if next_at == nil then
            if runtime.timer ~= nil then
                runtime.timer:set_enabled(false)
            end

            runtime.timer = nil
            runtime.armed_at = nil
            return
        end

        if runtime.armed_at == next_at then
            return
        end

        if runtime.timer ~= nil then
            runtime.timer:set_enabled(false)
        end

        runtime.armed_at = next_at
        runtime.timer = hl.timer(function()
            local due = runtime.armed_at
            runtime.timer = nil
            runtime.armed_at = nil

            if due ~= nil then
                engine:advance_to(due)
            end

            arm()
        end, {
            timeout = max(1, next_at - engine.now),
            type = "oneshot",
        })
    end

    runtime.arm = arm
    return runtime
end

local function bind_rule(engine, runtime, config, rule)
    local chord = normalize.hypr_chord(rule, config.keys)

    hl.bind(
        chord,
        function()
            engine:capture_and_fire(rule.id)
            runtime.arm()
        end,
        bind_opts(rule, {
            repeating = rule.repeat_.enabled and rule.repeat_.phase == "press" or false,
        })
    )
end

local function bind_key_press(config, key)
    hl.bind(normalize.hypr_key(key), function()
        dispatch_action(key.actions.press)
    end, bind_opts(key))
end

local function bind_key_cycle(engine, runtime, key, physical, chord, active_cycles, consume_release)
    local active_key = tostring(physical)
    local tap_timer = nil
    local ignore_mods = key.modifier ~= nil

    hl.bind(
        chord,
        function()
            local cycle = engine:on_key_down(physical)
            local state = {
                cycle = cycle,
                tap_expired = false,
            }

            active_cycles[active_key] = state

            if key.actions.tap ~= nil then
                tap_timer = hl.timer(function()
                    if active_cycles[active_key] == state then
                        state.tap_expired = true
                    end
                end, {
                    timeout = key.defaults.tap_ms,
                    type = "oneshot",
                })
            end

            runtime.arm()
        end,
        bind_opts(key, {
            non_consuming = true,
            ignore_mods = ignore_mods,
            transparent = true,
        })
    )

    hl.bind(
        chord,
        function()
            local state = active_cycles[active_key]

            if state == nil then
                return
            end

            if tap_timer ~= nil then
                tap_timer:set_enabled(false)
                tap_timer = nil
            end

            local release_at = state.cycle.down_at + 1

            if state.tap_expired then
                release_at = state.cycle.down_at + key.defaults.tap_ms + 1
            end

            engine:on_key_up(physical, nil, max(engine.now, release_at))
            active_cycles[active_key] = nil
            runtime.arm()
        end,
        bind_opts(key, {
            release = true,
            ignore_mods = ignore_mods,
            non_consuming = not consume_release,
            transparent = true,
        })
    )
end

local function bind_resolver_chord(engine, runtime, config, rule, active_cycles)
    local trigger_key = config.keys[rule.chord.trigger]
    local trigger_physical = trigger_key.hypr or trigger_key.name
    local active_key = "rule:" .. rule.id
    local tap_timer = nil
    local chord = normalize.hypr_chord(rule, config.keys)

    hl.bind(
        chord,
        function()
            local instance = engine:backend_capture_rule_down(rule.id, trigger_physical)
            local state = {
                cycle = instance.trigger_cycle,
                tap_expired = false,
            }

            active_cycles[active_key] = state

            if rule.actions.tap ~= nil then
                tap_timer = hl.timer(function()
                    if active_cycles[active_key] == state then
                        state.tap_expired = true
                    end
                end, {
                    timeout = rule.timing.tap_ms,
                    type = "oneshot",
                })
            end

            runtime.arm()
        end,
        bind_opts(rule, {
            transparent = true,
        })
    )

    hl.bind(
        chord,
        function()
            local state = active_cycles[active_key]

            if state == nil then
                return
            end

            if tap_timer ~= nil then
                tap_timer:set_enabled(false)
                tap_timer = nil
            end

            local release_at = state.cycle.down_at + 1

            if state.tap_expired then
                release_at = state.cycle.down_at + rule.timing.tap_ms + 1
            end

            engine:on_key_up(trigger_physical, nil, max(engine.now, release_at))
            active_cycles[active_key] = nil
            runtime.arm()
        end,
        bind_opts(rule, {
            release = true,
            transparent = true,
        })
    )
end

local function register_layer(engine, runtime, config, layer, rules, active_cycles)
    local function register_rules()
        for _, rule in ipairs(rules) do
            if can_compile_native(rule) then
                bind_rule(engine, runtime, config, rule)
            elseif needs_resolver(rule) then
                bind_resolver_chord(engine, runtime, config, rule, active_cycles)
            end
        end
    end

    if layer == "global" then
        register_rules()
    else
        hl.define_submap(layer, register_rules)
    end
end

function backend.register(config, opts)
    opts = opts or {}

    local warnings = {}
    local engine = Engine.new(config, {
        fire_action = function(action)
            dispatch_action(action)
        end,
    })
    local active_cycles = {}

    if hl == nil then
        warnings[#warnings + 1] = "Hyprland hl API is unavailable; keymap was normalized but not registered."
        return {
            config = config,
            engine = engine,
            warnings = warnings,
        }
    end

    local runtime = create_runtime(engine)
    local tracked_held_keys = {}

    for _, rule in ipairs(config.rules) do
        if needs_resolver(rule) or rule.held_release ~= "keep" then
            for _, held in ipairs(rule.chord.held) do
                tracked_held_keys[held] = true
            end
        end
    end

    for name, key in pairs(config.keys) do
        if key.actions.press ~= nil and not key_needs_cycle(key) then
            bind_key_press(config, key)
        elseif key_needs_cycle(key) or tracked_held_keys[name] then
            for _, chord in ipairs(physical_bind_chords(key)) do
                local physical = chord

                if key.modifier ~= nil then
                    physical = chord:match("%+%s*(.+)$") or chord
                end

                bind_key_cycle(engine, runtime, key, physical, chord, active_cycles, key_needs_cycle(key))
            end
        end
    end

    for layer, rules in pairs(config.layers) do
        register_layer(engine, runtime, config, layer, rules, active_cycles)
    end

    for _, rule in ipairs(config.rules) do
        if needs_resolver(rule) then
            warnings[#warnings + 1] = "Chord '"
                .. rule.id
                .. "' uses resolver timing through registered hl.bind press/release sentinels. Releasing a non-trigger participant is tracked only for keys with a native cycle sentinel."
        elseif not can_compile_native(rule) then
            warnings[#warnings + 1] = "Chord '" .. rule.id .. "' cannot be compiled by the native Hyprland backend."
        end
    end

    if opts.print_warnings == true then
        for _, warning in ipairs(warnings) do
            print("keymap: " .. warning)
        end
    end

    return {
        config = config,
        engine = engine,
        warnings = warnings,
    }
end

return backend
