// Keybind presets for result rows by control type.
// Composable: switchPreset = normalPreset + switch keys,
//             sliderPreset = normalPreset + slider keys.

function compose(base, extension) {
    var result = {};
    for (var k in base) result[k] = base[k];
    for (var k in extension) result[k] = extension[k];
    return result;
}

var normalPreset = {
    activate: { key: Qt.Key_Return, modifiers: 0, action: "activate" },
    complete: { key: Qt.Key_Tab, modifiers: 0, action: "complete" }
};

var _switchKeys = {
    on: { key: Qt.Key_L, modifiers: Qt.AltModifier, action: "switch-on" },
    off: { key: Qt.Key_H, modifiers: Qt.AltModifier, action: "switch-off" },
    toggle: { key: Qt.Key_M, modifiers: Qt.AltModifier, action: "switch-toggle" }
};

var _sliderKeys = {
    increase: { key: Qt.Key_L, modifiers: Qt.AltModifier, action: "slider-inc" },
    decrease: { key: Qt.Key_H, modifiers: Qt.AltModifier, action: "slider-dec" }
};

var switchPreset = compose(normalPreset, _switchKeys);
var sliderPreset = compose(normalPreset, _sliderKeys);

function presetFor(row) {
    if (!row) return normalPreset;
    if (row.control && row.control.kind === "slider") return sliderPreset;
    if (row.switchActions) return switchPreset;
    return normalPreset;
}

// Returns the preset action name for an Alt+key combination on a given row.
function altActionForKey(row, key) {
    var preset = presetFor(row);
    for (var name in preset) {
        var b = preset[name];
        // Match only Alt-modifier entries
        if ((b.modifiers & Qt.AltModifier) && b.key === key)
            return b.action;
    }
    return "";
}
