# Phenix Qt Quick Controls style

`Phenix/` is a standard Qt Quick Controls style, not a Quickshell-only widget
collection. Its QML implementations inherit from `QtQuick.Templates` to
preserve Qt semantics and accessibility. `qmldir` imports the standard
`QtQuick.Controls.Basic` fallback for unimplemented types.

To use it with a Qt Quick application:

```sh
export QT_QUICK_CONTROLS_STYLE=Phenix
export QT_QUICK_CONTROLS_STYLE_PATH=/absolute/path/to/configs/phenix-shell/styles
qml main.qml
```

The `phenix-shell` executable sets these values for its own process only,
not for unrelated programs. Callers may override the style with
`QT_QUICK_CONTROLS_STYLE` before launching Phenix.

Custom templates: `ApplicationWindow`, `Pane`, `Frame`, `ToolBar`,
`Button`, `TabButton`, `TextField`, `TextArea`,
`CheckBox`, `RadioButton`, `Switch`, `Slider`. All other controls
inherit Qt's mature Basic implementations. Do not fork complex Qt controls
merely to paint them differently.

`Theme.qml` is a small, self-contained Catppuccin Mocha palette. The
standalone Qt style intentionally does not import `qs.services`, because
that module exists only in Quickshell. For shell-specific, live palette
binding, use existing `Config.styling` tokens on component instances.

See Qt's [custom style documentation](https://doc.qt.io/qt-6/qtquickcontrols-customize.html).
