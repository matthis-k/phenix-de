pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property real mmPerInch: 25.4

    function mm(mmValue, screen) {
        if (!screen || !screen.logicalPixelDensity)
            return mmValue; // best-effort fallback
        return mmValue * screen.logicalPixelDensity;
    }

    function mmFromLogicalPx(pxValue, screen) {
        if (!screen || !screen.logicalPixelDensity)
            return pxValue;
        return pxValue / screen.logicalPixelDensity;
    }

    function mmPhysical(mmValue, screen) {
        if (!screen || !screen.physicalPixelDensity)
            return mmValue;
        return mmValue * screen.physicalPixelDensity;
    }

    function mmFromPhysicalPx(pxValue, screen) {
        if (!screen || !screen.physicalPixelDensity)
            return pxValue;
        return pxValue / screen.physicalPixelDensity;
    }

    function logicalToPhysical(pxValue, screen) {
        if (!screen || !screen.devicePixelRatio)
            return pxValue;
        return pxValue * screen.devicePixelRatio;
    }

    function physicalToLogical(pxValue, screen) {
        if (!screen || !screen.devicePixelRatio)
            return pxValue;
        return pxValue / screen.devicePixelRatio;
    }
}
