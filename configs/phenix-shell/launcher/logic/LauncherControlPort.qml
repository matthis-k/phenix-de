import QtQml

// Command-side capability for launcher controls. Domain services are injected at
// composition time and hidden from generic command execution.
QtObject {
    id: root

    required property var brightness
    required property var audio
    required property var power

    function adjust(control, delta) {
        if (!control || control.kind !== "slider")
            return false;

        var step = Number(control.step || 1);
        switch (control.target) {
        case "brightness": {
            var value = alignedValue(brightness.percent, delta, step, control.from || 0, control.to || 100);
            brightness.setPercent(value);
            return true;
        }
        case "pipewire":
        case "audio": {
            var current = audio.volumePercentById(control.nodeId);
            if (current === null || current === undefined)
                return false;
            var volume = alignedValue(current, delta, step, control.from || 0, control.to || 150);
            return audio.setVolumeById(control.nodeId, volume);
        }
        case "power-profile":
            power.cycleProfile(delta * step);
            return true;
        default:
            return false;
        }
    }

    function setValue(control, value) {
        if (!control)
            return false;

        switch (control.target) {
        case "brightness":
            brightness.setPercent(Number(value));
            return true;
        case "pipewire":
        case "audio":
            return audio.setVolumeById(control.nodeId, Number(value));
        case "power-profile":
            power.setProfile(power.profileFromIndex(Number(value)));
            return true;
        default:
            return false;
        }
    }

    function alignedValue(current, delta, step, from, to) {
        var base = delta < 0 ? Math.floor(current / step) * step : Math.ceil(current / step) * step;
        if (Math.abs(base - current) < 0.0001)
            base += delta * step;
        return Math.max(from, Math.min(to, base));
    }
}
