pragma Singleton
import Quickshell
import qs.services

// Transitional call-site adapter. The former node-id/property-name registry had
// no producers and has been removed; delegates now keep their explicit QML
// bindings until they are moved onto LauncherControlReadPort.
Singleton {
    readonly property var tracer: Logger.scope("launcher.bindingAdapter", { category: "launcher" })

    function applyBindings(delegate, nodeId) {
        tracer.trace("applyBindings", function() {
            return { nodeId: nodeId || "", explicitBindings: true };
        });
    }
}
