local normalize = require("keymap.normalize")
local Engine = require("keymap.engine")
local hyprland_backend = require("keymap.hyprland_backend")

local keymap = {}

function keymap.normalize(config)
    return normalize.map(config)
end

function keymap.new_engine(config, opts)
    return Engine.new(normalize.map(config), opts)
end

function keymap.map(config, opts)
    opts = opts or {}

    local compiled = normalize.map(config)

    if opts.backend == false then
        return compiled
    end

    local backend = opts.backend or hyprland_backend
    return backend.register(compiled, opts)
end

return keymap
