pragma Singleton
import QtQml
import Quickshell

Singleton {
    function empty() {
        return {
            warnings: [],
            errors: [],
            unresolved: [],
            legacyCount: 0,
            tupleCount: 0,
            objectCount: 0
        };
    }

    function toDebug(diag) {
        if (!diag) return empty();
        return {
            warnings: diag.warnings || [],
            errors: diag.errors || [],
            unresolved: diag.unresolved || [],
            legacyCount: diag.legacyCount || 0,
            tupleCount: diag.tupleCount || 0,
            objectCount: diag.objectCount || 0
        };
    }
}
