hl.config({
    animations = {
        enabled = true,
        workspace_wraparound = false,
    },
})

hl.curve("easeInQuart", { type = "bezier", points = { { 0.5, 0 }, { 0.75, 0 } } })
hl.curve("easeOutQuart", { type = "bezier", points = { { 0.25, 1 }, { 0.5, 1 } } })
hl.curve("easeInOutQuart", { type = "bezier", points = { { 0.76, 0 }, { 0.24, 1 } } })

local animations = {
    { leaf = "global", enabled = true, speed = 4, bezier = "easeInOutQuart" },
    { leaf = "windowsOut", enabled = true, speed = 4, bezier = "easeInOutQuart", style = "slide left" },
    { leaf = "windowsIn", enabled = true, speed = 4, bezier = "easeInOutQuart", style = "slide right" },
    { leaf = "windowsMove", enabled = true, speed = 4, bezier = "easeInOutQuart" },
    { leaf = "layers", enabled = false },
    { leaf = "fade", enabled = false },
    { leaf = "border", enabled = false },
    { leaf = "borderangle", enabled = true, speed = 4, bezier = "easeInOutQuart", style = "once" },
    { leaf = "workspaces", enabled = true, speed = 4, bezier = "easeInOutQuart", style = "slidevert" },
    { leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "easeInOutQuart", style = "fade" },
    { leaf = "zoomFactor", enabled = true, speed = 4, bezier = "easeInOutQuart" },
    { leaf = "monitorAdded", enabled = true, speed = 4, bezier = "easeOutQuart" },
}

for _, animation in ipairs(animations) do
    hl.animation(animation)
end
