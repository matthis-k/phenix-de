import QtQuick
import Qt5Compat.GraphicalEffects
import "../utils/UiIcons.js" as UiIcons
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    property string iconName: "dialog-warning"
    property string fallbackIconName: "dialog-warning"
    // Must be `var` with `undefined` sentinel — typed `color`/`url` can't be
    // undefined, breaking the presence check for ColorOverlay visibility
    property var color: undefined
    property real implicitSize: -1
    property var source: undefined

    // auto: map legacy shell names to Lucide; system: desktop theme only;
    // lucide: use the full Lucide set. "lucide:flame" also opts in directly.
    property string iconSet: "auto"
    property bool preferUiGlyph: true
    property bool lucideLoadFailed: false

    readonly property bool hasImplicitSize: implicitSize >= 0
    readonly property bool hasIconName: iconName !== "" || fallbackIconName !== ""
    readonly property bool prefixedLucide: iconName.startsWith("lucide:")
    readonly property string requestedLucide: prefixedLucide
        ? iconName.slice(7)
        : iconSet === "lucide" ? iconName
        : iconSet === "auto" && preferUiGlyph ? UiIcons.lookup(iconName)
        : ""
    // Prevent file path injection when a name comes from a launcher backend.
    readonly property string lucideName: /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(requestedLucide)
        ? requestedLucide
        : ""
    readonly property string lucideDir: String(Quickshell.env("PHENIX_LUCIDE_ICON_DIR") || "")
    readonly property bool usingLucide: root.source === undefined
        && root.iconSet !== "system"
        && root.lucideName !== ""
        && root.lucideDir !== ""
        && !root.lucideLoadFailed
    readonly property string themeIconName: prefixedLucide ? fallbackIconName : iconName
    readonly property var iconPath: hasIconName
        ? Quickshell.iconPath(themeIconName, fallbackIconName)
        : undefined
    // Explicit sources, including application DesktopEntry icons, win.
    readonly property var resolvedSource: root.source !== undefined
        ? root.source
        : root.usingLucide
            ? "file://" + root.lucideDir + "/" + root.lucideName + ".svg"
            : root.iconPath
    readonly property bool hasResolvedSource: root.resolvedSource !== undefined
        && root.resolvedSource !== null
        && root.resolvedSource !== ""

    onIconNameChanged: lucideLoadFailed = false
    onIconSetChanged: lucideLoadFailed = false
    onPreferUiGlyphChanged: lucideLoadFailed = false

    property alias smooth: icon.smooth
    property alias mipmap: icon.mipmap

    implicitWidth: hasImplicitSize ? implicitSize : Math.max(16, parent ? parent.height : icon.implicitWidth)
    implicitHeight: hasImplicitSize ? implicitSize : Math.max(16, parent ? parent.height : icon.implicitHeight)

    IconImage {
        id: icon
        anchors.fill: parent
        visible: root.hasResolvedSource
        source: root.hasResolvedSource ? root.resolvedSource : ""
        onStatusChanged: {
            if (status === Image.Error && root.usingLucide)
                root.lucideLoadFailed = true;
        }
        scale: root.hasImplicitSize ? root.implicitSize / Math.max(parent.width, parent.height, 1) : 1.0
    }

    ColorOverlay {
        visible: root.color !== undefined && root.color !== null
        anchors.fill: icon
        color: root.color !== undefined && root.color !== null ? root.color : "transparent"
        source: icon
        scale: icon.scale
    }
}
