import QtQuick
import Quickshell

/**
 * Logging helper that only outputs when PHENIX_DEV environment is set.
 * 
 * Usage:
 *   DevLogger.log("message")
 *   DevLogger.log("value:", someValue)
 *   DevLogger.warn("warning message")
 *   DevLogger.error("error message")
 */
QtObject {
    id: root

    property bool isEnabled: Quickshell.env("PHENIX_DEV") === "1"

    function log() {
        if (!isEnabled) return
        var msg = Array.prototype.join.call(arguments, " ")
        console.log("[DEV] " + msg)
    }

    function warn() {
        if (!isEnabled) return
        var msg = Array.prototype.join.call(arguments, " ")
        console.warn("[DEV WARN] " + msg)
    }

    function error() {
        if (!isEnabled) return
        var msg = Array.prototype.join.call(arguments, " ")
        console.error("[DEV ERROR] " + msg)
    }
}
