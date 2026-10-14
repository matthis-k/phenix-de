# Phenix Shell UI components

Use Qt Quick Controls for **behavior** and Phenix components for **composition**.
Do not build new keyboard/focus/menu/list models when Qt already supplies one.
Import the local component directory as `import qs.components as UI`.

## Shared building blocks

| Need | Component | Notes |
| --- | --- | --- |
| Actions, icon buttons, confirmations | `InteractiveButton`, `ActionButton`, `DashboardIconButton`, `ConfirmActionButton` | Keyboard/focus and pointer behavior already implemented |
| Expand/collapse only | `Expander` | Animated content height and clipping; used by dashboard sections |
| Labeled disclosure | `DisclosureSection` | Composes `ActionButton` and `Expander`; use `expanded` to drive state |
| Location navigation | `Breadcrumbs` | Array of strings or objects; `activated(index, item)` for ancestors |
| Native editor layout | `LabeledField` | Label, description, mandatory marker, validation text; accepts any control |
| Native search editor | `SearchField` | Extends the real TextField with search and clear actions |
| Form organization | `FormSection` | App settings grouping with title and optional header accessory |
| Inline feedback | `InlineNotice` | Info/success/warning/error; optional `action` component |
| Reusable app layouts | `qs.layouts` (`TabbedPane`, `SplitPane`, `SidebarPane`, `PageScaffold`) | Native Qt compositions; see `../layouts/README.md` |
| App/system status | `Badge`, `InfoRow`, `EmptyState` | Use semantic color roles |
| Dashboard layout | `DashboardPage`, `DashboardSection`, `DashboardListRow` | Keep dashboard-specific presentation separate |

All new content uses `Config.spacing`, `Config.typography`, `Config.styling`, `Config.iconSizes`, and Material Outlined through `Icon.qml`.

## Qt Quick Controls

Inside a Quickshell session launched through `phenix-shell`, ordinary
`import QtQuick.Controls` uses the `Phenix` style. Its selected controls
(`ApplicationWindow`, `Pane`, `Frame`, `ToolBar`, `Button`, `TabButton`,
`CheckBox`, `RadioButton`, `Switch`, `Slider`,
`TextField`, `TextArea`) use Qt's **real control templates**. Standard
controls that the style does not implement fall back to Qt's Basic style.

Keep `ComboBox`, `SpinBox`, `Menu`, `Dialog`, `ScrollView`, `SplitView`,
`StackView`, `TreeView`, `TableView`, `ListView`, `TabBar`, and
`Action` native. Favor delegates, layouts, and theme changes over
reimplementing selection, editing, validation, model virtualization, or
navigation.

Existing widgets importing `QtQuick.Controls.Basic` explicitly retain their
current behavior and visual appearance. To adopt the new default style, use
`import QtQuick.Controls` instead.

## Example

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.components as UI

ColumnLayout {
    width: 440
    spacing: 12

    UI.Breadcrumbs {
        items: [
            { label: "Apps", value: "apps" },
            { label: "Downloads", value: "downloads" },
            { label: "Settings", value: "settings" }
        ]
        onActivated: (index, item) => console.log("Navigate", index, item.value)
    }

    UI.DisclosureSection {
        title: "Advanced"
        description: "Application-specific settings"
        expanded: true

        UI.LabeledField {
            label: "Endpoint"
            description: "Connection URL"
            mandatory: true

            TextField {
                Layout.fillWidth: true
                placeholderText: "https://example.org"
                Accessible.name: "Endpoint"
            }
        }
    }

    UI.InlineNotice {
        severity: "info"
        title: "Changes are local"
        message: "Apply the configuration when ready."
    }
}
```

`LabeledField` deliberately does not wrap or intercept the editor. Give the
actual editor an accessible name, binding, and validation logic. The component
only arranges those elements.

## Standalone Qt Quick applications

The style is self-contained and can be reused independently of Quickshell.
Set `QT_QUICK_CONTROLS_STYLE=Phenix` and
`QML_IMPORT_PATH=<path-to-configs/phenix-shell/styles>` **before**
the QML engine loads. Existing `QtQuick.Controls.Basic` imports opt out.
The style's portable palette is in `styles/Phenix/Theme.qml`; shell-specific
live palette logic remains in `services/Config.qml`.

Use `tests/StyleSmoke.qml` for an offscreen style smoke check with Qt's QML
runtime. It covers native selection and fallback imports, not compositor visuals.

## Portability

The standalone `Phenix` Qt Quick Controls style is available as a Nix package (`phenix-qtquick-style`) and works without Quickshell. Compositional elements in this directory currently import `qs.services` and are intended for Quickshell-hosted panels and app surfaces. Keep these boundaries explicit; extract a standalone QML library only when an independent application requires it.
