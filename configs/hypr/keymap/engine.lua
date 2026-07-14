local normalize = require("keymap.normalize")
local Timers = require("keymap.timers")

local Engine = {}
Engine.__index = Engine

local function set_count(values)
    local total = 0

    for _ in pairs(values or {}) do
        total = total + 1
    end

    return total
end

local function first_action_phase(instance)
    if instance.press_fired then
        return "press"
    end

    if instance.tap_fired then
        return "tap"
    end

    if instance.hold_fired then
        return "hold"
    end

    if instance.long_fired then
        return "long"
    end

    return nil
end

local function default_fire(action, context)
    if type(action) == "function" then
        action(context)
    end
end

function Engine.new(config, opts)
    opts = opts or {}

    return setmetatable({
        config = config,
        now = opts.now or 0,
        active_layer = opts.layer or "global",
        fire_action = opts.fire_action or default_fire,
        next_cycle_id = 1,
        next_instance_id = 1,
        cycles = {},
        active_by_physical = {},
        active_by_key = {},
        instances = {},
        timers = Timers.new(),
    }, Engine)
end

function Engine:set_layer(layer)
    self.active_layer = layer or "global"
end

function Engine:resolve_physical(physical)
    local text = tostring(physical)
    return self.config.physical_to_key[text] or self.config.physical_to_key[text:lower()] or text:lower()
end

function Engine:active_cycle_for_key(key)
    local cycle = self.active_by_key[key]

    if cycle ~= nil and cycle.down then
        return cycle
    end

    return nil
end

function Engine:create_cycle(physical, device)
    local key = self:resolve_physical(physical)
    local cycle = {
        id = self.next_cycle_id,
        key = key,
        physical = physical,
        device = device,
        down = true,
        down_at = self.now,
        up_at = nil,
        participants = {},
        reservations = {},
        full_consumer = nil,
        tap_blocked = false,
        hold_blocked = false,
        long_blocked = false,
        release_blocked = false,
        press_fired = false,
        tap_fired = false,
        hold_fired = false,
        long_fired = false,
        release_fired = false,
        repeat_owner = nil,
        timers = {},
        standalone_active = false,
        standalone_owner = nil,
    }

    self.next_cycle_id = self.next_cycle_id + 1
    self.cycles[cycle.id] = cycle
    self.active_by_physical[tostring(physical)] = cycle
    self.active_by_key[key] = cycle

    return cycle
end

function Engine:create_virtual_cycle(key)
    local cycle = {
        id = self.next_cycle_id,
        key = key,
        physical = key,
        device = nil,
        down = true,
        down_at = self.now,
        up_at = nil,
        participants = {},
        reservations = {},
        full_consumer = nil,
        tap_blocked = false,
        hold_blocked = false,
        long_blocked = false,
        release_blocked = false,
        press_fired = false,
        tap_fired = false,
        hold_fired = false,
        long_fired = false,
        release_fired = false,
        repeat_owner = nil,
        timers = {},
        standalone_active = false,
        standalone_owner = nil,
        virtual = true,
    }

    self.next_cycle_id = self.next_cycle_id + 1
    self.cycles[cycle.id] = cycle

    return cycle
end

function Engine:emit(action, context)
    if action == nil then
        return
    end

    context = context or {}
    context.now = self.now
    self.fire_action(action, context)
end

function Engine:key_is_free_for_tap(cycle)
    return cycle.down == false
        and not cycle.tap_blocked
        and set_count(cycle.participants) == 0
        and cycle.full_consumer == nil
        and not cycle.hold_fired
        and not cycle.long_fired
end

function Engine:find_matching_rule(trigger_key, physical)
    local candidates = {}

    for _, rule in ipairs(self.config.rules_by_trigger[trigger_key] or {}) do
        if rule.layer == "global" or rule.layer == self.active_layer then
            local held_cycles = {}
            local matches = true

            for _, held in ipairs(rule.chord.held) do
                local held_cycle = self:active_cycle_for_key(held)

                if held_cycle == nil then
                    matches = false
                    break
                end

                held_cycles[held] = held_cycle
            end

            if matches then
                candidates[#candidates + 1] = {
                    rule = rule,
                    held_cycles = held_cycles,
                    layer_score = rule.layer == self.active_layer and rule.layer ~= "global" and 1 or 0,
                    held_score = #rule.chord.held,
                    exact_score = tostring(physical) == (self.config.keys[trigger_key] or {}).hypr and 1 or 0,
                }
            end
        end
    end

    table.sort(candidates, function(left, right)
        if left.layer_score ~= right.layer_score then
            return left.layer_score > right.layer_score
        end

        if left.held_score ~= right.held_score then
            return left.held_score > right.held_score
        end

        if left.exact_score ~= right.exact_score then
            return left.exact_score > right.exact_score
        end

        return left.rule.id < right.rule.id
    end)

    if #candidates > 1 then
        local best = candidates[1]
        local next_best = candidates[2]

        if
            best.layer_score == next_best.layer_score
            and best.held_score == next_best.held_score
            and best.exact_score == next_best.exact_score
        then
            error("ambiguous keymap chord match: " .. best.rule.id .. " and " .. next_best.rule.id)
        end
    end

    return candidates[1]
end

function Engine:apply_held_consumption(rule, cycle)
    if rule.consume.held == "observe" then
        return
    end

    cycle.participants[rule.id] = true
    cycle.tap_blocked = true

    if not cycle.hold_fired then
        cycle.hold_blocked = true
    end

    if not cycle.long_fired then
        cycle.long_blocked = true
    end

    if rule.consume.held == "full" then
        cycle.full_consumer = cycle.full_consumer or rule.id
        cycle.release_blocked = true
    end
end

function Engine:apply_trigger_consumption(rule, cycle)
    local consumption = rule.resolved_trigger_consume or rule.consume.trigger

    if consumption == "observe" then
        return
    end

    if consumption == "reserve" then
        cycle.reservations[rule.id] = true
    elseif consumption == "full" then
        cycle.full_consumer = rule.id
    end
end

function Engine:create_instance(rule, trigger_cycle, held_cycles)
    local instance = {
        id = self.next_instance_id,
        rule_id = rule.id,
        rule = rule,
        trigger_cycle = trigger_cycle,
        held_cycles = held_cycles,
        captured_at = self.now,
        held_released = {},
        active = true,
        cancelled = false,
        phase = "waiting",
        press_fired = false,
        tap_fired = false,
        hold_fired = false,
        long_fired = false,
        release_fired = false,
        timers = {},
    }

    self.next_instance_id = self.next_instance_id + 1
    self.instances[instance.id] = instance

    for held in pairs(held_cycles) do
        instance.held_released[held] = false
    end

    return instance
end

function Engine:held_still_required(instance)
    for _, cycle in pairs(instance.held_cycles) do
        if not cycle.down then
            return false
        end
    end

    return true
end

function Engine:schedule_instance_timers(instance)
    local rule = instance.rule

    if rule.actions.hold ~= nil and not (rule.long_policy == "replace_hold" and rule.actions.long ~= nil) then
        instance.timers.hold =
            self.timers:schedule(instance.captured_at + rule.timing.hold_ms, "hold", "instance", instance.id)
    end

    if rule.actions.long ~= nil then
        instance.timers.long =
            self.timers:schedule(instance.captured_at + rule.timing.long_ms, "long", "instance", instance.id)
    end
end

function Engine:schedule_cycle_timers(cycle, key)
    if key.actions.hold ~= nil and not (key.long_policy == "replace_hold" and key.actions.long ~= nil) then
        cycle.timers.hold = self.timers:schedule(cycle.down_at + key.defaults.hold_ms, "hold", "cycle", cycle.id)
    end

    if key.actions.long ~= nil then
        cycle.timers.long = self.timers:schedule(cycle.down_at + key.defaults.long_ms, "long", "cycle", cycle.id)
    end
end

function Engine:start_repeat(owner_type, owner_id, delay_ms, every_ms, phase)
    local at = self.now + delay_ms
    self.timers:schedule(at, "repeat", owner_type, owner_id, {
        every_ms = every_ms,
        phase = phase,
    })
end

function Engine:fire_instance_phase(instance, phase)
    local rule = instance.rule
    local action = phase == "repeat" and rule.actions.repeat_ or rule.actions[phase]

    if action == nil then
        return
    end

    self:emit(action, {
        type = "chord",
        phase = phase,
        rule = rule,
        instance = instance,
        trigger_cycle = instance.trigger_cycle,
        held_cycles = instance.held_cycles,
    })

    if phase == "press" then
        instance.press_fired = true
        instance.trigger_cycle.press_fired = true
        instance.phase = "pressed"
    elseif phase == "tap" then
        instance.tap_fired = true
        instance.trigger_cycle.tap_fired = true
        instance.phase = "released"
    elseif phase == "hold" then
        instance.hold_fired = true
        instance.trigger_cycle.hold_fired = true
        instance.trigger_cycle.tap_blocked = true
        instance.trigger_cycle.full_consumer = instance.trigger_cycle.full_consumer or rule.id
        instance.phase = "held"
    elseif phase == "long" then
        instance.long_fired = true
        instance.trigger_cycle.long_fired = true
        instance.trigger_cycle.tap_blocked = true
        instance.trigger_cycle.full_consumer = instance.trigger_cycle.full_consumer or rule.id
        instance.phase = "long"
    elseif phase == "release" then
        instance.release_fired = true
        instance.trigger_cycle.release_fired = true
        instance.phase = "released"
    end
end

function Engine:fire_cycle_phase(cycle, phase)
    local key = self.config.keys[cycle.key]

    if key == nil then
        return
    end

    local action = phase == "repeat" and key.actions.repeat_ or key.actions[phase]

    if action == nil then
        return
    end

    self:emit(action, {
        type = "key",
        phase = phase,
        key = key,
        cycle = cycle,
    })

    if phase == "press" then
        cycle.press_fired = true
    elseif phase == "tap" then
        cycle.tap_fired = true
    elseif phase == "hold" then
        cycle.hold_fired = true
        cycle.tap_blocked = true
    elseif phase == "long" then
        cycle.long_fired = true
        cycle.tap_blocked = true
    elseif phase == "release" then
        cycle.release_fired = true
    end
end

function Engine:capture_chord(match, trigger_cycle)
    local rule = match.rule
    local instance = self:create_instance(rule, trigger_cycle, match.held_cycles)

    for _, cycle in pairs(match.held_cycles) do
        self:apply_held_consumption(rule, cycle)
    end

    self:apply_trigger_consumption(rule, trigger_cycle)

    if rule.actions.press ~= nil then
        self:fire_instance_phase(instance, "press")

        if rule.resolved_trigger_consume == "full" then
            trigger_cycle.full_consumer = rule.id
        end
    end

    self:schedule_instance_timers(instance)

    if rule.repeat_.enabled and rule.repeat_.phase == "press" and rule.actions.press ~= nil then
        self:start_repeat("instance", instance.id, rule.repeat_.delay_ms, rule.repeat_.every_ms, "press")
    end

    return instance
end

function Engine:start_standalone(cycle)
    local key = self.config.keys[cycle.key]

    if key == nil then
        return
    end

    local actions = key.actions or {}
    local has_waiting = actions.tap ~= nil or actions.hold ~= nil or actions.long ~= nil or actions.release ~= nil

    if actions.press ~= nil then
        self:fire_cycle_phase(cycle, "press")
    end

    if has_waiting then
        cycle.standalone_active = true
        cycle.standalone_owner = "key:" .. key.name
        self:schedule_cycle_timers(cycle, key)
    elseif actions.press ~= nil then
        cycle.full_consumer = cycle.standalone_owner or ("key:" .. key.name)
    end
end

function Engine:on_key_down(physical, device, at)
    if at ~= nil then
        self:advance_to(at)
    end

    local cycle = self:create_cycle(physical, device)
    local match = self:find_matching_rule(cycle.key, physical)

    if match ~= nil then
        self:capture_chord(match, cycle)
        return cycle
    end

    self:start_standalone(cycle)
    return cycle
end

function Engine:backend_capture_rule_down(rule_id, physical, device, at)
    if at ~= nil then
        self:advance_to(at)
    end

    local rule = self.config.rules_by_id[rule_id]

    if rule == nil then
        error("unknown keymap rule: " .. tostring(rule_id))
    end

    local trigger_key = self.config.keys[rule.chord.trigger]
    local trigger_physical = physical or (trigger_key and (trigger_key.hypr or trigger_key.name)) or rule.chord.trigger
    local trigger_cycle = self:create_cycle(trigger_physical, device)
    local held_cycles = {}

    for _, held in ipairs(rule.chord.held) do
        held_cycles[held] = self:active_cycle_for_key(held) or self:create_virtual_cycle(held)
    end

    return self:capture_chord({
        rule = rule,
        held_cycles = held_cycles,
    }, trigger_cycle)
end

function Engine:finish_instance(instance)
    if not instance.active then
        return
    end

    instance.active = false
    self.timers:cancel_owner("instance", instance.id)
    instance.trigger_cycle.reservations[instance.rule.id] = nil
end

function Engine:cancel_instance(instance, fire_release)
    if not instance.active then
        return
    end

    instance.cancelled = true

    if fire_release and instance.rule.actions.release ~= nil and not instance.release_fired then
        self:fire_instance_phase(instance, "release")
    end

    self:finish_instance(instance)
end

function Engine:resolve_instance_release(instance)
    if not instance.active or instance.cancelled then
        return
    end

    local rule = instance.rule
    local duration = (instance.trigger_cycle.up_at or self.now) - instance.captured_at

    if
        rule.actions.tap ~= nil
        and not instance.tap_fired
        and not instance.hold_fired
        and not instance.long_fired
        and not instance.press_fired
        and duration <= rule.timing.tap_ms
    then
        self:fire_instance_phase(instance, "tap")
        instance.trigger_cycle.full_consumer = instance.trigger_cycle.full_consumer or rule.id
    end

    if rule.actions.release ~= nil and not instance.release_fired then
        self:fire_instance_phase(instance, "release")
    end

    if first_action_phase(instance) ~= nil then
        instance.trigger_cycle.full_consumer = instance.trigger_cycle.full_consumer or rule.id
    end

    self:finish_instance(instance)
end

function Engine:update_held_releases(cycle)
    for _, instance in pairs(self.instances) do
        if instance.active and instance.held_cycles[cycle.key] == cycle then
            instance.held_released[cycle.key] = true

            if instance.rule.held_release == "cancel" then
                self:cancel_instance(instance, true)
            elseif instance.rule.held_release == "finish" then
                self:resolve_instance_release(instance)
            end
        end
    end
end

function Engine:update_trigger_release(cycle)
    for _, instance in pairs(self.instances) do
        if instance.trigger_cycle == cycle and instance.active then
            self:resolve_instance_release(instance)
        end
    end
end

function Engine:resolve_standalone_release(cycle)
    if not cycle.standalone_active then
        return
    end

    local key = self.config.keys[cycle.key]

    if key == nil then
        return
    end

    local duration = (cycle.up_at or self.now) - cycle.down_at

    if key.actions.tap ~= nil and self:key_is_free_for_tap(cycle) and duration <= key.defaults.tap_ms then
        self:fire_cycle_phase(cycle, "tap")
    elseif key.actions.release ~= nil and not cycle.release_fired and not cycle.release_blocked then
        local untouched = set_count(cycle.participants) == 0 and cycle.full_consumer == nil
        local owned_phase_fired = cycle.press_fired or cycle.hold_fired or cycle.long_fired

        if untouched or owned_phase_fired then
            self:fire_cycle_phase(cycle, "release")
        end
    end

    cycle.standalone_active = false
    self.timers:cancel_owner("cycle", cycle.id)
end

function Engine:on_key_up(physical, device, at)
    if at ~= nil then
        self:advance_to(at)
    end

    local cycle = self.active_by_physical[tostring(physical)] or self.active_by_physical[tostring(physical):lower()]

    if cycle == nil then
        return nil
    end

    cycle.down = false
    cycle.up_at = self.now

    self:update_held_releases(cycle)
    self:update_trigger_release(cycle)
    self:resolve_standalone_release(cycle)

    self.active_by_physical[tostring(cycle.physical)] = nil

    if self.active_by_key[cycle.key] == cycle then
        self.active_by_key[cycle.key] = nil
    end

    return cycle
end

function Engine:handle_cycle_timer(timer)
    local cycle = self.cycles[timer.owner_id]

    if cycle == nil or not cycle.down or not cycle.standalone_active then
        return
    end

    local key = self.config.keys[cycle.key]

    if key == nil then
        return
    end

    if timer.kind == "hold" and not cycle.hold_fired and not cycle.hold_blocked then
        self:fire_cycle_phase(cycle, "hold")
    elseif timer.kind == "long" and not cycle.long_fired and not cycle.long_blocked then
        self:fire_cycle_phase(cycle, "long")
    elseif timer.kind == "repeat" then
        self:fire_cycle_phase(cycle, "repeat")
        self.timers:schedule(self.now + timer.data.every_ms, "repeat", "cycle", cycle.id, timer.data)
    end
end

function Engine:handle_instance_timer(timer)
    local instance = self.instances[timer.owner_id]

    if instance == nil or not instance.active or instance.cancelled or not instance.trigger_cycle.down then
        return
    end

    local rule = instance.rule

    if rule.held_required_until ~= "trigger_down" and not self:held_still_required(instance) then
        self:cancel_instance(instance, rule.held_release == "cancel")
        return
    end

    if timer.kind == "hold" and not instance.hold_fired then
        self:fire_instance_phase(instance, "hold")

        if rule.repeat_.enabled and rule.repeat_.phase == "hold" then
            self:start_repeat("instance", instance.id, rule.repeat_.delay_ms, rule.repeat_.every_ms, "hold")
        end
    elseif timer.kind == "long" and not instance.long_fired then
        self:fire_instance_phase(instance, "long")

        if rule.repeat_.enabled and rule.repeat_.phase == "long" then
            self:start_repeat("instance", instance.id, rule.repeat_.delay_ms, rule.repeat_.every_ms, "long")
        end
    elseif timer.kind == "repeat" then
        self:fire_instance_phase(instance, "repeat")
        self.timers:schedule(self.now + timer.data.every_ms, "repeat", "instance", instance.id, timer.data)
    end
end

function Engine:advance_to(target)
    if target < self.now then
        error("cannot move keymap time backwards")
    end

    while true do
        local timer = self.timers:next_due(target)

        if timer == nil then
            break
        end

        self.now = timer.at

        if timer.owner_type == "cycle" then
            self:handle_cycle_timer(timer)
        elseif timer.owner_type == "instance" then
            self:handle_instance_timer(timer)
        end
    end

    self.now = target
end

function Engine:capture_and_fire(rule_id)
    local rule = self.config.rules_by_id[rule_id]

    if rule == nil then
        error("unknown keymap rule: " .. tostring(rule_id))
    end

    for _, held in ipairs(rule.chord.held) do
        local cycle = self:active_cycle_for_key(held)

        if cycle ~= nil then
            self:apply_held_consumption(rule, cycle)
        end
    end

    local trigger_cycle = self:active_cycle_for_key(rule.chord.trigger)

    if trigger_cycle ~= nil then
        trigger_cycle.full_consumer = trigger_cycle.full_consumer or rule.id
        trigger_cycle.tap_blocked = true
    end

    if rule.actions.press ~= nil then
        self:emit(rule.actions.press, {
            type = "backend_chord",
            phase = "press",
            rule = rule,
            trigger_cycle = trigger_cycle,
        })
    end
end

function Engine:next_timer_at()
    return self.timers:next_at()
end

function Engine.hypr_chord(rule, keys)
    return normalize.hypr_chord(rule, keys)
end

return Engine
