pragma Singleton
import QtQml
import Quickshell
import qs.services

Singleton {
    readonly property var tracer: Logger.scope("service.testMode", { category: "service" })
    readonly property var prof: Profiler.scope("service.testMode", { category: "service" })
    readonly property bool isActive: Quickshell.env("NEWSHELL_TEST_MODE") === "1"

    function fixturePath(key) {
        return Quickshell.env("NEWSHELL_" + key + "_FIXTURE") || "";
    }

    function loadFixtureSync(path) {
        if (!path) return null;
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "file://" + path, false);
        xhr.send();
        if (xhr.status === 0 || xhr.status === 200) {
            try { return JSON.parse(xhr.responseText); } catch (e) { return null; }
        }
        return null;
    }

    function loadFixtureAsync(path, callback) {
        if (!path) { callback(null); return; }
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "file://" + path, true);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (xhr.status === 0 || xhr.status === 200) {
                    try { callback(JSON.parse(xhr.responseText)); } catch (e) { callback(null); }
                } else {
                    callback(null);
                }
            }
        };
        xhr.send();
    }
}
