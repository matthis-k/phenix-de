local function require_module(name)
    local ok, err = pcall(require, name)

    if not ok then
        print("Failed to load " .. name .. ".lua: " .. tostring(err))
    end
end

for _, module in ipairs({
    "variables",
    "monitors",
    "workspace-rules",
    "window-rules",
    "animations",
    "gestures",
    "keybinds",
}) do
    require_module(module)
end
