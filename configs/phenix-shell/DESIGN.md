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

- Known shell action and navigation icons use selected Lucide SVG glyphs.
- Desktop application icons retain their full-color source from their desktop
  entry. `Icon.source` always takes priority over the UI glyph mapping.
- Unknown icon names resolve through `Quickshell.iconPath` and the configured
  Freedesktop icon theme. Papirus-Dark remains a fallback and app icon source.
- Add new shell names to `utils/UiIcons.js`. Keep icon names meaningful.
- Use `Config.iconSizes`. Typical sizes are 16px inline, 18px for sections,
  20px for controls, and 22px for page icons.
- Lucide artwork is ISC-licensed. Keep its license beside the SVG assets.

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
