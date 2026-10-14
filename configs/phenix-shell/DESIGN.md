# Phenix Shell design rules

Phenix Shell is a terminal-inspired Qt Quick desktop. It uses precise layouts,
monospace text for labels and metrics, restrained colors, clear focus feedback,
and short animations.

## Geometry and spacing

- Containers, sections, windows, buttons, fields, and list rows use square corners.
- Small moving switch knobs and tooltips may use `Config.shape.small`.
- Compact badges may use `Config.shape.badge`. Circular gauge arcs, status
  dots, and slider handles keep their round shape.
- Use `Config.spacing` rather than new spacing literals in shared components.
- Organize information with alignment, negative space, and thin dividers.
  Reserve filled highlights for selected, hovered, or important content.

## Typography and color

- Use `Config.typography` for new shared components.
- Page titles use 22px, section titles 16px, body 14px, labels 13px,
  secondary text 12px, captions 11px, and small badges 10px.
- Use `Config.styling` and `Config.colors`. Avoid hardcoded palette values.
- Blue marks the primary interaction, green marks active or healthy state,
  yellow marks caution, and red marks errors or destructive actions.
- Distinguish selected, keyboard-focused, hovered, pressed, busy, and disabled.
  Color must not be the only status cue.

## Icons

- Use Material Symbols **Outlined, weight 400** for shell controls and navigation.
  Nix installs the complete Outlined and Sharp SVG sets, including filled
  and unfilled variants, from the pinned `@material-symbols/svg-400`
  0.48.0 release. Runtime use is offline.
- Choose `iconName: "material:local_fire_department"`, or set
  `iconSet: "material"` and pass a native Material name such as `"settings"`.
- Use `filled: true` to select the filled variant, such as an active tab.
  `materialStyle: "sharp"` is an explicit per-icon alternative to the
  default `materialStyle: "outlined"`. Style and fill are independent.
- Existing Freedesktop symbolic names map to Material via `utils/UiIcons.js`.
  Unmapped names continue to use `Quickshell.iconPath`.
- Lucide remains fully installed and opt-in through `iconName: "lucide:flame"`
  or `iconSet: "lucide"`. Set `iconSet: "system"` for theme-only resolution.
- Desktop application icons retain their full-color source from the desktop
  entry. `Icon.source` takes priority over all icon set choices.
- A missing SVG falls back to the Freedesktop theme; Papirus-Dark remains the
  configured theme for application icons and fallback device glyphs.
- Use `Config.iconSizes`. Typical sizes are 16px inline, 18px for sections,
  20px for controls, and 22px for page icons.
- Material Symbols are Apache-2.0 licensed. Lucide uses ISC and includes the
  Feather-derived MIT notice. Nix keeps both licenses beside the SVG assets.

## Reusable UI and Qt Quick Controls

- Prefer the existing `components/` controls for shell-specific composition.
  New reusable primitives include `Breadcrumbs`, `DisclosureSection`,
  `LabeledField`, and `InlineNotice`. See `components/README.md`.
- Use standard `import QtQuick.Controls` for native controls in new app pages.
  The `Phenix` style provides square-first appearance for basic form controls;
  unimplemented templates fall back to Qt's Basic style.
- Do not reimplement complex Qt controls. Prefer their existing models,
  selection, keyboard handling, scroll behavior, drag handles, accessibility,
  and editable delegates. Use `TreeView`, `TableView`, `SplitView`,
  `StackView`, `ComboBox`, and `Menu` directly.
- Existing `QtQuick.Controls.Basic` imports remain unchanged and opt out
  of the new style. The style is process-scoped and can also be reused by
  standalone Qt Quick apps via standard environment variables.
- Complex app layout presets in `layouts/` compose native `TabBar`, 
  `TabButton`, `StackLayout`, `SplitView`, and `ColumnLayout` without
  replacing their behavior. See `layouts/README.md`.
- Qt 6 discovers the Phenix style through `QML_IMPORT_PATH`, not the
  removed `QT_QUICK_CONTROLS_STYLE_PATH`.
- Keep standalone style tokens portable. Quickshell-specific live tokens
  remain owned by `Config.qml`.

## Motion

- Use the existing `Config.motion` timings of 100, 160, 220, and 320ms.
- Apply 100ms to hover and press feedback, 160ms to selection and toggles,
  220ms to content disclosure and panel transitions.
- Prefer opacity, color, or small translations. Avoid decorative bounce.
- Use Qt Quick `Behavior`, `Transition`, and list transitions. Keep custom
  reconciliation only for requirements that native views cannot preserve.
- A disabled motion setting should produce immediate settled states.
- Focus, model state, and commands must remain correct when animations stop,
  reverse, or are skipped.

## Components and layout

- Keep `InteractiveButton` as the base for button focus and accessible labels.
  Build specialized buttons by changing content, not by copying interactions.
- Keep the existing `DashboardPage`, `DashboardSection`, and
  `DashboardListRow` layout contracts. Share their tokens and icon roles.
- Use `RowLayout`, `ColumnLayout`, and implicit size contracts.
- Preserve the seven dashboard pages, overview and detailed modes, and
  launcher keyboard navigation. UI styling must not remove their controls.
- Preserve accessible names and focus visibility. Keep click targets usable
  even when the visible mark is small.

## Review checklist

A UI change is ready when keyboard focus is visible, states use shared tokens,
icons resolve without broken images, animations can be interrupted, widgets
work without motion, and app icons retain their original artwork.
