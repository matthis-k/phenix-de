package.path = table.concat({
    package.path,
    "./?.lua",
    "./?/init.lua",
    "./configs/hypr/?.lua",
    "./configs/hypr/?/init.lua",
}, ";")

local keymap = require("keymap")

local tests = {}

local function make_action(log, name)
    return function(context)
        log[#log + 1] = {
            name = name,
            at = context.now,
            phase = context.phase,
        }
    end
end

local function names(log)
    local out = {}

    for index, event in ipairs(log) do
        out[index] = event.name
    end

    return table.concat(out, ",")
end

local function count(log, name)
    local total = 0

    for _, event in ipairs(log) do
        if event.name == name then
            total = total + 1
        end
    end

    return total
end

local function assert_equal(actual, expected, label)
    if actual ~= expected then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function run(config, events)
    local log = config.log
    config.log = nil

    local engine = keymap.new_engine(config, {
        fire_action = function(action, context)
            action(context)
        end,
    })

    for _, event in ipairs(events) do
        if event[1] == "down" then
            engine:on_key_down(event[2], nil, event[3])
        elseif event[1] == "up" then
            engine:on_key_up(event[2], nil, event[3])
        elseif event[1] == "advance" then
            engine:advance_to(event[2])
        else
            error("unknown test event: " .. tostring(event[1]))
        end
    end

    return log
end

local function base_config(log)
    return {
        log = log,
        keys = {
            super = {
                tap = make_action(log, "launcher"),
            },
        },
    }
end

tests[#tests + 1] = function()
    local log = {}
    local config = base_config(log)

    run(config, {
        { "down", "super", 0 },
        { "up", "super", 100 },
    })

    assert_equal(names(log), "launcher", "super tap")
end

tests[#tests + 1] = function()
    local log = {}
    local config = base_config(log)

    run(config, {
        { "down", "super", 0 },
        { "up", "super", 700 },
    })

    assert_equal(names(log), "", "super hold without hold action")
end

tests[#tests + 1] = function()
    local log = {}
    local config = base_config(log)
    config.binds = {
        {
            chord = { held = { "super" }, trigger = "l" },
            action = make_action(log, "lock"),
        },
    }

    run(config, {
        { "down", "super", 0 },
        { "down", "l", 10 },
        { "up", "l", 30 },
        { "up", "super", 50 },
    })

    assert_equal(names(log), "lock", "super+l normal nesting")
end

tests[#tests + 1] = function()
    local log = {}
    local config = base_config(log)
    config.binds = {
        {
            chord = { held = { "super" }, trigger = "l" },
            action = make_action(log, "lock"),
        },
    }

    run(config, {
        { "down", "super", 0 },
        { "down", "l", 10 },
        { "up", "super", 20 },
        { "up", "l", 30 },
    })

    assert_equal(names(log), "lock", "super+l non-perfect nesting")
end

tests[#tests + 1] = function()
    local log = {}
    local config = base_config(log)
    config.binds = {}

    for _, key in ipairs({ "h", "j", "k", "l" }) do
        config.binds[#config.binds + 1] = {
            chord = { held = { "super" }, trigger = key },
            action = make_action(log, key),
        }
    end

    run(config, {
        { "down", "super", 0 },
        { "down", "h", 10 },
        { "up", "h", 20 },
        { "down", "j", 30 },
        { "up", "j", 40 },
        { "down", "k", 50 },
        { "up", "k", 60 },
        { "down", "l", 70 },
        { "up", "l", 80 },
        { "up", "super", 90 },
    })

    assert_equal(names(log), "h,j,k,l", "super+hjkl chain")
end

tests[#tests + 1] = function()
    local log = {}
    local config = base_config(log)
    config.binds = {
        {
            chord = { held = { "super" }, trigger = "h" },
            actions = {
                tap = make_action(log, "focus_left"),
                hold = make_action(log, "move_left"),
                repeat_ = make_action(log, "move_left"),
            },
            defaults = nil,
            repeat_ = true,
            ["repeat"] = { phase = "hold", delay_ms = 50, every_ms = 50 },
        },
    }

    run(config, {
        { "down", "super", 0 },
        { "down", "h", 10 },
        { "up", "h", 120 },
        { "up", "super", 140 },
    })

    assert_equal(names(log), "focus_left", "super+h tap branch")

    log = {}
    config = base_config(log)
    config.binds = {
        {
            chord = { held = { "super" }, trigger = "h" },
            actions = {
                tap = make_action(log, "focus_left"),
                hold = make_action(log, "move_left"),
                repeat_ = make_action(log, "move_left"),
            },
            ["repeat"] = { phase = "hold", delay_ms = 50, every_ms = 50 },
        },
    }

    run(config, {
        { "down", "super", 0 },
        { "down", "h", 10 },
        { "advance", 610 },
        { "up", "h", 620 },
        { "up", "super", 640 },
    })

    assert_equal(count(log, "focus_left"), 0, "super+h hold skips tap")

    if count(log, "move_left") < 2 then
        error("super+h hold repeat: expected hold plus repeat")
    end
end

tests[#tests + 1] = function()
    local log = {}
    local config = base_config(log)
    config.binds = {
        {
            chord = { held = { "super" }, trigger = "h" },
            action = make_action(log, "focus_left"),
        },
        {
            chord = { held = { "super", "shift" }, trigger = "h" },
            action = make_action(log, "move_left"),
        },
    }

    run(config, {
        { "down", "super", 0 },
        { "down", "shift", 10 },
        { "down", "h", 20 },
        { "up", "h", 30 },
        { "up", "shift", 40 },
        { "up", "super", 50 },
    })

    assert_equal(names(log), "move_left", "more specific chord wins")
end

tests[#tests + 1] = function()
    local log = {}
    local ok = pcall(function()
        keymap.new_engine({
            keys = {
                super = { tap = make_action(log, "launcher") },
            },
            binds = {
                {
                    chord = { held = { "super", "shift" }, trigger = "h" },
                    action = make_action(log, "first"),
                },
                {
                    chord = { held = { "shift", "super" }, trigger = "h" },
                    action = make_action(log, "second"),
                },
            },
        })
    end)

    if ok then
        error("duplicate normalized chord: expected configuration error")
    end
end

tests[#tests + 1] = function()
    local log = {}
    local config = base_config(log)
    config.keys.h = {
        tap = make_action(log, "h_tap"),
    }
    config.binds = {
        {
            chord = { held = { "super" }, trigger = "h" },
            action = make_action(log, "combo"),
        },
    }

    run(config, {
        { "down", "super", 0 },
        { "down", "h", 10 },
        { "up", "h", 50 },
        { "up", "super", 80 },
    })

    assert_equal(names(log), "combo", "trigger fully consumed")
end

tests[#tests + 1] = function()
    local log = {}
    local config = base_config(log)
    config.binds = {
        {
            chord = { held = { "super" }, trigger = "mouse:272" },
            actions = {
                press = make_action(log, "begin_drag"),
                release = make_action(log, "end_drag"),
            },
            held_release = "cancel",
        },
    }

    run(config, {
        { "down", "super", 0 },
        { "down", "mouse:272", 10 },
        { "up", "super", 20 },
        { "up", "mouse:272", 30 },
    })

    assert_equal(names(log), "begin_drag,end_drag", "held release cancel")
end

tests[#tests + 1] = function()
    local log = {}
    local config = {
        log = log,
        keys = {
            caps = {
                tap = make_action(log, "escape"),
                hold = make_action(log, "enter_nav"),
            },
        },
    }

    run(config, {
        { "down", "caps", 0 },
        { "up", "caps", 300 },
    })

    assert_equal(names(log), "", "tap gap behavior")
end

tests[#tests + 1] = function()
    local log = {}
    local config = {
        log = log,
        keys = {
            caps = {
                hold = make_action(log, "enter_nav"),
            },
        },
    }

    run(config, {
        { "down", "caps", 0 },
        { "advance", 500 },
        { "up", "caps", 600 },
    })

    assert_equal(names(log), "enter_nav", "hold fires on timer")
    assert_equal(log[1].at, 500, "hold timer timestamp")
end

tests[#tests + 1] = function()
    local log = {}
    local config = base_config(log)
    config.binds = {
        {
            chord = { held = { "super" }, trigger = "h" },
            action = make_action(log, "focus_left"),
            ["repeat"] = true,
        },
    }

    run(config, {
        { "down", "super", 0 },
        { "down", "h", 10 },
        { "advance", 610 },
        { "up", "h", 620 },
        { "up", "super", 640 },
    })

    if count(log, "focus_left") < 3 then
        error("press repeat: expected press plus repeat events")
    end

    assert_equal(count(log, "launcher"), 0, "press repeat suppresses held tap")
end

tests[#tests + 1] = function()
    local log = {}
    local config = base_config(log)
    config.binds = {
        {
            chord = { held = { "super" }, trigger = "l" },
            actions = {
                tap = make_action(log, "lock"),
                hold = make_action(log, "lock_hold"),
            },
        },
    }

    run(config, {
        { "down", "super", 0 },
        { "down", "l", 10 },
        { "up", "l", 120 },
        { "up", "super", 140 },
    })

    assert_equal(names(log), "lock", "tap+hold tap branch delays until release")

    log = {}
    config = base_config(log)
    config.binds = {
        {
            chord = { held = { "super" }, trigger = "l" },
            actions = {
                tap = make_action(log, "lock"),
                hold = make_action(log, "lock_hold"),
            },
        },
    }

    run(config, {
        { "down", "super", 0 },
        { "down", "l", 10 },
        { "advance", 510 },
        { "up", "l", 520 },
        { "up", "super", 540 },
    })

    assert_equal(names(log), "lock_hold", "tap+hold hold branch excludes tap")
end

local passed = 0

for index, test in ipairs(tests) do
    local ok, err = pcall(test)

    if not ok then
        error("keymap test #" .. index .. " failed: " .. tostring(err), 0)
    end

    passed = passed + 1
end

print("keymap tests passed: " .. passed)
