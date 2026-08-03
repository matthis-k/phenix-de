import QtQml

// Explicit command port for non-control system capabilities used by launcher
// action payloads. The launcher executor only understands the port contract.
QtObject {
    id: root

    required property var brightness
    required property var audio
    required property var power
    required property var network
    required property var vpn
    required property var bluetooth
    required property var notifications
    required property var session

    function execute(payload) {
        if (!payload || !payload.service)
            return false;

        switch (String(payload.service)) {
        case "brightness":
            return brightness.executePayload ? brightness.executePayload(payload) : false;
        case "audio":
            return audio.executePayload(payload);
        case "power":
            return power.executePayload(payload);
        case "network":
            return network.executePayload(payload);
        case "vpn":
            return vpn.executePayload(payload);
        case "bluetooth":
            return bluetooth.executePayload(payload);
        case "notifications":
            return notifications.executePayload ? notifications.executePayload(payload) : false;
        case "session":
            return session.executePayload(payload);
        default:
            return false;
        }
    }
}
