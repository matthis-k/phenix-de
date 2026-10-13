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

    // Auto resolves known shell glyphs to Material Outlined. Full-color
    // desktop-entry icons still win when the caller sets source explicitly.
    property string iconSet: "auto"  // auto, material, lucide, system
    property string materialStyle: "outlined" // outlined or sharp
    property bool preferUiGlyph: true
    property bool filled: false
    property bool iconLoadFailed: false

    readonly property bool hasImplicitSize: implicitSize >= 0
    readonly property bool hasIconName: iconName !== "" || fallbackIconName !== ""
    readonly property bool prefixedMaterial: iconName.startsWith("material:")
    readonly property bool prefixedLucide: iconName.startsWith("lucide:")
    readonly property string requestedMaterial: prefixedMaterial
        ? iconName.slice(9)
        : iconSet === "material" ? iconName
        : iconSet === "auto" && preferUiGlyph && !prefixedLucide
            ? UiIcons.lookup(iconName)
            : ""
    readonly property string requestedLucide: prefixedLucide
        ? iconName.slice(7)
        : iconSet === "lucide" ? iconName
        : ""
    // Restrict filenames to a single known icon. Never allow path segments.
    readonly property string materialName: /^[a-z0-9_]+$/.test(requestedMaterial)
        ? requestedMaterial : ""
    readonly property string lucideName: /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(requestedLucide)
        ? requestedLucide : ""
    readonly property string materialDir: String(Quickshell.env("PHENIX_MATERIAL_ICON_DIR") || "")
    readonly property string resolvedMaterialStyle: root.materialStyle === "sharp" ? "sharp" : "outlined"
    readonly property string lucideDir: String(Quickshell.env("PHENIX_LUCIDE_ICON_DIR") || "")
    readonly property string selectedGlyphSet: root.source !== undefined
        || root.iconSet === "system" || root.iconLoadFailed
        ? ""
        : root.materialName !== "" && root.materialDir !== ""
            ? "material"
            : root.lucideName !== "" && root.lucideDir !== ""
                ? "lucide" : ""
    readonly property string glyphPath: root.selectedGlyphSet === "material"
        ? "file://" + root.materialDir + "/" + root.resolvedMaterialStyle + "/" + root.materialName
            + (root.filled ? "-fill" : "") + ".svg"
        : root.selectedGlyphSet === "lucide"
            ? "file://" + root.lucideDir + "/" + root.lucideName + ".svg"
            : ""
    readonly property string themeIconName: root.prefixedMaterial || root.prefixedLucide
        ? root.fallbackIconName : root.iconName
    readonly property var iconPath: hasIconName
        ? Quickshell.iconPath(themeIconName, fallbackIconName)
        : undefined
    readonly property var resolvedSource: root.source !== undefined
        ? root.source
        : root.glyphPath !== "" ? root.glyphPath : root.iconPath
    readonly property bool hasResolvedSource: root.resolvedSource !== undefined
        && root.resolvedSource !== null && root.resolvedSource !== ""

    onIconNameChanged: iconLoadFailed = false
    onIconSetChanged: iconLoadFailed = false
    onPreferUiGlyphChanged: iconLoadFailed = false
    onFilledChanged: iconLoadFailed = false
    onMaterialStyleChanged: iconLoadFailed = false

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
            if (status === Image.Error && root.selectedGlyphSet !== "")
                root.iconLoadFailed = true;
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
