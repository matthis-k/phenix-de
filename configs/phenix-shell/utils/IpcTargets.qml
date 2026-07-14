pragma Singleton
import QtQml
import Quickshell

Singleton {
    readonly property string namespace: Quickshell.env("NEWSHELL_IPC_NAMESPACE")

    function name(base) {
        const b = String(base || "");
        return namespace && namespace.length > 0 ? namespace + "." + b : b;
    }
}
