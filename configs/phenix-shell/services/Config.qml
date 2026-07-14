pragma Singleton
import QtQml
import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    readonly property var tracer: Logger.scope("service.config", { category: "service" })
    readonly property var prof: Profiler.scope("service.config", { category: "service" })
    id: root

    function colorWithOpacity(colorValue, alpha) {
        const hex = (colorValue && colorValue.toString) ? colorValue.toString() : "#000000";
        if (!hex || hex[0] !== "#")
            return Qt.rgba(0, 0, 0, alpha);

        let channelString = hex.slice(1);
        if (channelString.length === 3) {
            channelString = channelString.split("").map(function(part) { return part + part; }).join("");
        } else if (channelString.length === 8) {
            channelString = channelString.slice(2);
        }

        if (channelString.length !== 6)
            return Qt.rgba(0, 0, 0, alpha);

        const r = parseInt(channelString.slice(0, 2), 16) / 255;
        const g = parseInt(channelString.slice(2, 4), 16) / 255;
        const b = parseInt(channelString.slice(4, 6), 16) / 255;

        if ([r, g, b].some(component => isNaN(component)))
            return Qt.rgba(0, 0, 0, alpha);

        return Qt.rgba(r, g, b, alpha);
    }

    FileView {
        id: paletteFile
        path: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/quickshell/catppuccin-palette.json"
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            property string rosewater: "#f5e0dc"
            property string flamingo: "#f2cdcd"
            property string pink: "#f5c2e7"
            property string mauve: "#cba6f7"
            property string red: "#f38ba8"
            property string maroon: "#eba0ac"
            property string peach: "#fab387"
            property string yellow: "#f9e2af"
            property string green: "#a6e3a1"
            property string teal: "#94e2d5"
            property string sky: "#89dceb"
            property string sapphire: "#74c7ec"
            property string blue: "#89b4fa"
            property string lavender: "#b4befe"
            property string text: "#cdd6f4"
            property string subtext1: "#bac2de"
            property string subtext0: "#a6adc8"
            property string overlay2: "#9399b2"
            property string overlay1: "#7f849c"
            property string overlay0: "#6c7086"
            property string surface2: "#585b70"
            property string surface1: "#45475a"
            property string surface0: "#313244"
            property string base: "#1e1e2e"
            property string mantle: "#181825"
            property string crust: "#11111b"
        }
    }

    readonly property var paletteColors: {
        const adapter = paletteFile.adapter;
        if (!adapter) return {};
        return {
            "rosewater": adapter.rosewater,
            "flamingo": adapter.flamingo,
            "pink": adapter.pink,
            "mauve": adapter.mauve,
            "red": adapter.red,
            "maroon": adapter.maroon,
            "peach": adapter.peach,
            "yellow": adapter.yellow,
            "green": adapter.green,
            "teal": adapter.teal,
            "sky": adapter.sky,
            "sapphire": adapter.sapphire,
            "blue": adapter.blue,
            "lavender": adapter.lavender,
            "text": adapter.text,
            "subtext1": adapter.subtext1,
            "subtext0": adapter.subtext0,
            "overlay2": adapter.overlay2,
            "overlay1": adapter.overlay1,
            "overlay0": adapter.overlay0,
            "surface2": adapter.surface2,
            "surface1": adapter.surface1,
            "surface0": adapter.surface0,
            "base": adapter.base,
            "mantle": adapter.mantle,
            "crust": adapter.crust,
        };
    }

    readonly property QtObject spacing: QtObject {
        readonly property int unit: 4
        readonly property int xxs: unit        // 4px - tight inline
        readonly property int xs: unit * 2     // 8px - default padding
        readonly property int sm: unit * 3     // 12px - medium component gap
        readonly property int md: unit * 4     // 16px - standard section
        readonly property int lg: unit * 6     // 24px - large section break
        readonly property int xl: unit * 8     // 32px - panel margin
        readonly property int xxl: unit * 12   // 48px - page-level gap
        readonly property int xxxl: unit * 16  // 64px - layout boundary
    }

    PersistentProperties {
        id: colorsObj
        reloadableId: "persistentColors"

        property color rosewater: root.paletteColors.rosewater || "#f5e0dc"
        property color flamingo: root.paletteColors.flamingo || "#f2cdcd"
        property color pink: root.paletteColors.pink || "#f5c2e7"
        property color mauve: root.paletteColors.mauve || "#cba6f7"
        property color red: root.paletteColors.red || "#f38ba8"
        property color maroon: root.paletteColors.maroon || "#eba0ac"
        property color peach: root.paletteColors.peach || "#fab387"
        property color yellow: root.paletteColors.yellow || "#f9e2af"
        property color green: root.paletteColors.green || "#a6e3a1"
        property color teal: root.paletteColors.teal || "#94e2d5"
        property color sky: root.paletteColors.sky || "#89dceb"
        property color sapphire: root.paletteColors.sapphire || "#74c7ec"
        property color blue: root.paletteColors.blue || "#89b4fa"
        property color lavender: root.paletteColors.lavender || "#b4befe"

        property color text: root.paletteColors.text || "#cdd6f4"
        property color subtext1: root.paletteColors.subtext1 || "#bac2de"
        property color subtext0: root.paletteColors.subtext0 || "#a6adc8"
        property color overlay2: root.paletteColors.overlay2 || "#9399b2"
        property color overlay1: root.paletteColors.overlay1 || "#7f849c"
        property color overlay0: root.paletteColors.overlay0 || "#6c7086"
        property color surface2: root.paletteColors.surface2 || "#585b70"
        property color surface1: root.paletteColors.surface1 || "#45475a"
        property color surface0: root.paletteColors.surface0 || "#313244"
        property color base: root.paletteColors.base || "#1e1e2e"
        property color mantle: root.paletteColors.mantle || "#181825"
        property color crust: root.paletteColors.crust || "#11111b"
    }

    PersistentProperties {
        id: styleState
        reloadableId: "persistentStyling"

        property color bg0: colorsObj.crust
        property color bg1: colorsObj.mantle
        property color bg2: colorsObj.base
        property color bg3: colorsObj.surface0
        property color bg4: colorsObj.surface1
        property color bg5: colorsObj.surface2
        property color bg6: colorsObj.overlay0
        property color bg7: colorsObj.overlay1
        property color bg8: colorsObj.overlay2

        property color text0: colorsObj.text
        property color text1: colorsObj.subtext0
        property color text2: colorsObj.subtext1

        property color primaryAccent: colorsObj.blue
        property color secondaryAccent: colorsObj.sky

        property color good: colorsObj.green
        property color normal: colorsObj.text
        property color warning: colorsObj.yellow
        property color urgent: colorsObj.peach
        property color critical: colorsObj.red
        property color close: colorsObj.red

        property color bluetooth: colorsObj.blue
        property color activeIndicator: colorsObj.green

        property color cursor: colorsObj.rosewater
        property color cursorText: colorsObj.crust

        property color link: colorsObj.blue
        property color linkHover: colorsObj.sky
        property color linkVisited: colorsObj.lavender

        property color selectionBackground: colorWithOpacity(colorsObj.overlay2, 0.24)
        property color selectionBackgroundActive: colorWithOpacity(colorsObj.overlay2, 0.3)
        property color selectionText: colorsObj.text

        property color placeholderText: colorsObj.overlay1
        property color textOnAccent: colorsObj.base
        property color info: colorsObj.teal

        property bool rounded: false
        property int radius: 8 * rounded
        property int margin: radius

        property url wallpaper: Qt.resolvedUrl("../assets/wallpaper.jpg")

        property double statusIconScaler: 0.55
    }

    PersistentProperties {
        id: barObj
        reloadableId: "persistentBar"
    }

    PersistentProperties {
        id: behaviourObj
        reloadableId: "persistentBehaviour"

        property int peekCloseDelay: 250
        property double hoverBgOpacity: 0.2
        property bool devMode: false

        property bool profilerInstalled: false
        property string profilerMode: "off"
        property int profilerMaxEvents: 50000
        property int profilerMaxSamplesPerName: 512

        property int loggerMaxEvents: 20000
        property int loggerMaxPayloads: 10000

        property bool loggerInstalled: false
        property int loggerInstalledMaxLevel: -1
        property int loggerRuntimeMaxLevel: -1

        readonly property QtObject animation: QtObject {
            property double duration_multiplier: 1.0
            readonly property bool enabled: duration_multiplier !== 0
            function calc(baseDurationSeconds) {
                return baseDurationSeconds * 1000 * (duration_multiplier || 0);
            }
            readonly property int micro: enabled ? calc(0.10) : 0
            readonly property int short: enabled ? calc(0.16) : 0
            readonly property int medium: enabled ? calc(0.22) : 0
            readonly property int long: enabled ? calc(0.32) : 0
        }
    }

    readonly property Palette styling: Palette {
        accent: styleState.primaryAccent
        alternateBase: styleState.bg4
        base: styleState.bg0
        brightText: styleState.textOnAccent
        button: styleState.bg3
        buttonText: styleState.text0
        dark: styleState.bg2
        highlight: styleState.selectionBackgroundActive
        highlightedText: styleState.selectionText
        light: styleState.bg5
        link: styleState.link
        linkVisited: styleState.linkVisited
        mid: styleState.bg4
        midlight: styleState.bg5
        placeholderText: styleState.placeholderText
        shadow: colorWithOpacity(styleState.bg2, 0.85)
        text: styleState.text0
        toolTipBase: styleState.bg4
        toolTipText: styleState.text0
        window: styleState.bg0
        windowText: styleState.text0

        disabled: ColorGroup {
            text: styleState.bg7
            buttonText: styleState.bg7
            windowText: styleState.bg7
            highlight: colorWithOpacity(styleState.bg8, 0.15)
            highlightedText: styleState.selectionText
            link: styleState.link
            linkVisited: styleState.linkVisited
            base: styleState.bg0
            button: styleState.bg3
        }

        inactive: ColorGroup {
            text: styleState.text1
            buttonText: styleState.text1
            windowText: styleState.text1
            highlight: styleState.selectionBackground
            highlightedText: styleState.selectionText
            link: styleState.link
            linkVisited: styleState.linkVisited
            base: styleState.bg0
            button: styleState.bg3
        }

        property color bg0: styleState.bg0
        property color bg1: styleState.bg1
        property color bg2: styleState.bg2
        property color bg3: styleState.bg3
        property color bg4: styleState.bg4
        property color bg5: styleState.bg5
        property color bg6: styleState.bg6
        property color bg7: styleState.bg7
        property color bg8: styleState.bg8

        property color text0: styleState.text0
        property color text1: styleState.text1
        property color text2: styleState.text2

        property color primaryAccent: styleState.primaryAccent
        property color secondaryAccent: styleState.secondaryAccent

        property color good: styleState.good
        property color normal: styleState.normal
        property color warning: styleState.warning
        property color urgent: styleState.urgent
        property color critical: styleState.critical
        property color close: styleState.close

        property color bluetooth: styleState.bluetooth
        property color activeIndicator: styleState.activeIndicator

        property color cursor: styleState.cursor
        property color cursorText: styleState.cursorText

        property color linkHover: styleState.linkHover

        property color selectionBackground: styleState.selectionBackground
        property color selectionBackgroundActive: styleState.selectionBackgroundActive
        property color selectionText: styleState.selectionText

        property color textOnAccent: styleState.textOnAccent
        property color placeholderTextColor: styleState.placeholderText
        property color info: styleState.info

        property bool rounded: styleState.rounded
        property int radius: styleState.radius
        property int margin: styleState.margin

        property double statusIconScaler: styleState.statusIconScaler
    }

    readonly property Palette palette: styling

    readonly property QtObject motion: QtObject {
        readonly property int micro: behaviour.animation.micro
        readonly property int short: behaviour.animation.short
        readonly property int medium: behaviour.animation.medium
        readonly property int long: behaviour.animation.long
    }

    readonly property alias colors: colorsObj
    readonly property alias wallpaper: styleState.wallpaper
    readonly property alias bar: barObj
    readonly property alias behaviour: behaviourObj
}
