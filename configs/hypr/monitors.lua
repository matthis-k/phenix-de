local ok, imported = pcall(require, "nix-import")

if not ok then
    print("Failed to load nix-import.lua: " .. tostring(imported))
    return false
end

for _, monitor in ipairs(imported.monitors or {}) do
    hl.monitor(monitor)
end

return true
