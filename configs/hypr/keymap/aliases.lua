local aliases = {}

aliases.builtins = {
    super = {
        physical = { "SUPER_L", "SUPER_R" },
        modifier = "SUPER",
        preset = "chainable",
    },
    shift = {
        physical = { "SHIFT_L", "SHIFT_R" },
        modifier = "SHIFT",
    },
    ctrl = {
        physical = { "CTRL_L", "CTRL_R" },
        modifier = "CTRL",
    },
    alt = {
        physical = { "ALT_L", "ALT_R" },
        modifier = "ALT",
    },
    caps = {
        physical = { "Caps_Lock" },
        hypr = "Caps_Lock",
    },
    ["return"] = {
        physical = { "Return" },
        hypr = "Return",
    },
    escape = {
        physical = { "Escape" },
        hypr = "Escape",
    },
    space = {
        physical = { "Space" },
        hypr = "Space",
    },
}

aliases.synonyms = {
    control = "ctrl",
    ctl = "ctrl",
    enter = "return",
    esc = "escape",
    win = "super",
    meta = "super",
}

local function trim(value)
    return (tostring(value):gsub("^%s+", ""):gsub("%s+$", ""))
end

function aliases.normalize_name(value)
    local normalized = trim(value):lower()
    return aliases.synonyms[normalized] or normalized
end

function aliases.display_for_token(value)
    local token = trim(value)

    if #token == 1 and token:match("%a") then
        return token:upper()
    end

    return token
end

return aliases
