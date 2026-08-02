pragma Singleton
import Quickshell
import qs.services

// Parses the flexible DTO recipe syntax once at the launcher boundary and
// produces the finite command algebra consumed by CommandExecutor.
Singleton {
    readonly property var tracer: Logger.scope("launcher.commandSpec", { category: "launcher" })
    readonly property var prof: Profiler.scope("launcher.commandSpec", { category: "launcher" })

    readonly property var knownKinds: ({
        "activate": true,
        "close": true,
        "edit-query": true,
        "adjust-control": true,
        "set-control": true,
        "toggle-control": true,
        "noop": true
    })

    function normalize(raw) {
        if (raw === null || raw === undefined)
            return command("noop", {});

        var name = "";
        var args = {};

        if (typeof raw === "string") {
            name = raw;
        } else if (Array.isArray(raw)) {
            if (raw.length === 0)
                return command("noop", {});
            name = String(raw[0]);
            args = objectArgs(raw.length > 1 ? raw[1] : null);
        } else if (typeof raw === "object") {
            name = String(raw.kind || raw.name || "noop");
            args = objectArgs(raw.args);
        } else {
            throw new Error("Unsupported launcher command value: " + typeof raw);
        }

        return command(canonicalKind(name), args);
    }

    function normalizeRecipe(recipe) {
        if (!recipe || !Array.isArray(recipe))
            return [];
        return recipe.map(normalize);
    }

    function command(kind, args) {
        if (!knownKinds[kind])
            throw new Error("Unknown launcher command kind: " + kind);
        return {
            kind: kind,
            args: objectArgs(args)
        };
    }

    function canonicalKind(name) {
        switch (String(name || "")) {
        case "run-action": return "activate";
        case "toggle": return "toggle-control";
        case "activate":
        case "close":
        case "edit-query":
        case "adjust-control":
        case "set-control":
        case "toggle-control":
        case "noop":
            return String(name);
        default:
            throw new Error("Unknown launcher recipe command: " + name);
        }
    }

    function objectArgs(value) {
        if (!value || typeof value !== "object" || Array.isArray(value))
            return {};
        var out = {};
        for (var key in value) {
            if (Object.prototype.hasOwnProperty.call(value, key))
                out[key] = value[key];
        }
        return out;
    }
}
