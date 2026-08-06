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
            return adjustment(false, null);

        var direction = Number(delta || 0);
        if (direction === 0)
            return adjustment(false, null);
        direction = direction < 0 ? -1 : 1;

        var step = Number(control.step || 1);
        switch (control.target) {
        case "brightness": {
            var value = alignedValue(brightness.percent, direction, step, control.from || 0, control.to || 100);
            brightness.setPercent(value);
            return adjustment(true, value);
        }
        case "pipewire":
        case "audio": {
            var current = audio.volumePercentById(control.nodeId);
            if (current === null || current === undefined)
                return adjustment(false, null);
            var volume = alignedValue(current, direction, step, control.from || 0, control.to || 150);
            var success = audio.setVolumeById(control.nodeId, volume);
            return adjustment(success, success ? volume : null);
        }
        case "power-profile": {
            var currentProfile = Number(control.value);
            if (!isFinite(currentProfile))
                currentProfile = power.profileIndex(power.profile);
            var profile = alignedValue(currentProfile, direction, step, control.from || 0, control.to || 2);
            power.setProfile(power.profileFromIndex(profile));
            return adjustment(true, profile);
        }
        default:
            return adjustment(false, null);
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

    function adjustment(success, value) {
        return {
            success: success === true,
            value: value === null || value === undefined ? null : Number(value)
        };
    }
}
