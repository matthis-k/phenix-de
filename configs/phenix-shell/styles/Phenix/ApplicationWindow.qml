import QtQuick
import QtQuick.Templates as T
import "." as Ph

// A palette on the root is inherited by the standard Basic fallback controls.
T.ApplicationWindow {
    palette.window: Ph.Theme.background
    palette.windowText: Ph.Theme.text
    palette.base: Ph.Theme.surface
    palette.alternateBase: Ph.Theme.raised
    palette.text: Ph.Theme.text
    palette.button: Ph.Theme.raised
    palette.buttonText: Ph.Theme.text
    palette.highlight: Ph.Theme.accent
    palette.highlightedText: Ph.Theme.onAccent
    palette.placeholderText: Ph.Theme.placeholder
    palette.mid: Ph.Theme.border
    palette.light: Ph.Theme.hover
    palette.dark: Ph.Theme.background
    palette.link: Ph.Theme.accent

    background: Rectangle {
        color: Ph.Theme.background
    }
}
