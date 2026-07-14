local keymap = require("keymap")

local function bind(held, trigger, action, description, layer)
    return {
        layer = layer,
        chord = {
            held = held or {},
            trigger = trigger,
        },
        action = action,
        description = description,
    }
end

local binds = {
    bind({ "super" }, "return", hl.dsp.exec_cmd("kitty"), "Terminal"),
    bind({ "super" }, "d", hl.dsp.exec_cmd("newshell ipc call launcher toggle"), "App launcher"),
    bind({ "ctrl", "alt" }, "w", hl.dsp.exec_cmd("zen-beta"), "Browser"),
    bind({}, "Print", hl.dsp.exec_cmd("screen-shot region"), "Screenshot region"),
    bind({ "super", "shift" }, "s", hl.dsp.exec_cmd("screen-shot region-direct"), "Screenshot region direct"),
    bind({ "super", "shift" }, "e", hl.dsp.exec_cmd("screen-edit-clipboard"), "Edit screenshot clipboard"),
    bind({ "shift" }, "Print", hl.dsp.exec_cmd("screen-shot output"), "Screenshot output"),
    bind({ "ctrl" }, "Print", hl.dsp.exec_cmd("screen-shot window"), "Screenshot window"),
    bind({ "super" }, "Print", hl.dsp.exec_cmd("screen-read-region"), "Read screen region"),
    bind({ "super" }, "q", hl.dsp.window.close(), "Close window"),
    bind({ "super" }, "m", hl.dsp.submap("window_manipulation"), "Window manipulation submap"),
    bind({ "super" }, "h", hl.dsp.focus({ direction = "left" }), "Focus left"),
    bind({ "super" }, "l", hl.dsp.focus({ direction = "right" }), "Focus right"),
    bind({ "super" }, "up", hl.dsp.focus({ direction = "up" }), "Focus up"),
    bind({ "super" }, "down", hl.dsp.focus({ direction = "down" }), "Focus down"),
    bind({ "super" }, "j", hl.dsp.focus({ workspace = "+1" }), "Next workspace"),
    bind({ "super" }, "k", hl.dsp.focus({ workspace = "-1" }), "Previous workspace"),
    bind({ "super" }, "mouse_down", hl.dsp.focus({ workspace = "+1" }), "Next workspace"),
    bind({ "super" }, "mouse_up", hl.dsp.focus({ workspace = "-1" }), "Previous workspace"),
    bind({ "super", "shift" }, "h", hl.dsp.layout("swapcol l"), "Swap column left"),
    bind({ "super", "shift" }, "j", hl.dsp.window.move({ workspace = "+1" }), "Move to next workspace"),
    bind({ "super", "shift" }, "k", hl.dsp.window.move({ workspace = "-1" }), "Move to previous workspace"),
    bind({ "super", "shift" }, "l", hl.dsp.layout("swapcol r"), "Swap column right"),
    bind({}, "XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), "Mute audio"),
    bind({}, "XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), "Lower volume"),
    bind({}, "XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), "Raise volume"),
    bind({}, "XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), "Previous media"),
    bind({}, "XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), "Play/pause media"),
    bind({}, "XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), "Next media"),
    bind(
        {},
        "XF86KbdBrightnessDown",
        hl.dsp.exec_cmd("brightnessctl -e4 -n2 -c leds set 50%-"),
        "Keyboard brightness down"
    ),
    bind(
        {},
        "XF86KbdBrightnessUp",
        hl.dsp.exec_cmd("brightnessctl -e4 -n2 -c leds set 50%+"),
        "Keyboard brightness up"
    ),
    bind({}, "XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 -c backlight set 5%-"), "Brightness down"),
    bind({}, "XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 -c backlight set 5%+"), "Brightness up"),
    bind({}, "h", hl.dsp.layout("swapcol l"), "Swap column left", "window_manipulation"),
    bind(
        {},
        "j",
        hl.dsp.window.move({ workspace = "+1", follow = true }),
        "Move to next workspace",
        "window_manipulation"
    ),
    bind(
        {},
        "k",
        hl.dsp.window.move({ workspace = "-1", follow = true }),
        "Move to previous workspace",
        "window_manipulation"
    ),
    bind({}, "l", hl.dsp.layout("swapcol r"), "Swap column right", "window_manipulation"),
    bind({}, "p", hl.dsp.layout("promote"), "Promote window", "window_manipulation"),
    bind({ "shift" }, "h", hl.dsp.window.move({ direction = "left" }), "Move left", "window_manipulation"),
    bind({ "shift" }, "j", hl.dsp.window.move({ direction = "down" }), "Move down", "window_manipulation"),
    bind({ "shift" }, "k", hl.dsp.window.move({ direction = "up" }), "Move up", "window_manipulation"),
    bind({ "shift" }, "l", hl.dsp.window.move({ direction = "right" }), "Move right", "window_manipulation"),
    bind({}, "minus", hl.dsp.layout("colresize -conf"), "Shrink column", "window_manipulation"),
    bind({}, "plus", hl.dsp.layout("colresize +conf"), "Grow column", "window_manipulation"),
    bind({}, "escape", hl.dsp.submap("reset"), "Exit submap", "window_manipulation"),
    bind({}, "return", hl.dsp.submap("reset"), "Exit submap", "window_manipulation"),
}

for workspace = 1, 9 do
    binds[#binds + 1] =
        bind({ "super" }, tostring(workspace), hl.dsp.focus({ workspace = workspace }), "Focus workspace " .. workspace)
    binds[#binds + 1] = bind(
        { "super", "shift" },
        tostring(workspace),
        hl.dsp.window.move({ workspace = workspace }),
        "Move to workspace " .. workspace
    )
end

keymap.map({
    keys = {
        super = {
            preset = "chainable",
            tap = hl.dsp.exec_cmd("newshell ipc call launcher toggle"),
            description = "Launcher",
        },
    },
    binds = binds,
})
