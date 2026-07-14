local function maybe_style_bitwarden_popup(win)
    if win.class ~= "zen-beta" or win.title == nil then
        return
    end

    if not win.title:match("^Extension: %(Bitwarden Password Manager%) %- Bitwarden") then
        return
    end

    local mon = win.monitor

    if mon == nil then
        return
    end

    hl.dispatch(hl.dsp.window.float({ action = "enable", window = win }))
    hl.dispatch(hl.dsp.window.resize({
        x = math.floor(mon.width * 0.5),
        y = math.floor(mon.height * 0.5),
        relative = false,
        window = win,
    }))
    hl.dispatch(hl.dsp.window.center({ window = win }))
end

hl.on("window.open", maybe_style_bitwarden_popup)
hl.on("window.title", maybe_style_bitwarden_popup)
