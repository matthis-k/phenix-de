# Phenix shell UI composition contract

This document is the implementation contract for the Quickshell dashboard. It combines the source audit with the composition review.

## Scope

Controls belong to exactly one scope:

1. Dashboard-wide controls live in persistent dashboard chrome.
2. Page controls live in the page header.
3. Section controls live in the section header.
4. Object controls live in the object row.
5. Temporary interaction controls live in an inline interaction tray.

A control must not look local while changing a broader scope.

## Disclosure

A detail arrow always means **show more information about this object**.

- Global detail forces informational detail open.
- A section arrow is used only when the section represents one object.
- Lists of independent objects use row arrows, not another list-level arrow.
- Connection, pairing, password, and confirmation trays are operational state rather than informational detail.
- Local detail state remains stored while global detail is active.

## Composition

Overview exposes primary controls and exceptional state. Dedicated pages own management, history, and diagnostics.

- Quick controls: output, brightness, and an exceptional or expanded microphone.
- Connectivity: current Wi-Fi or wired state and Bluetooth state.
- Power: charge, time estimate, and power profile; history stays on Power & Display.
- Notifications: state and count; the full feed stays on Notifications.
- System health: CPU, RAM, root storage, available GPU, and promoted exceptions.
- Session actions remain last and visually separate destructive actions.

Active objects are not repeated in multiple competing cards. Device pages use one principal scrolling surface.

## Interaction states

Reusable controls provide enabled, hover, focus-visible, pressed, active, disabled, busy, and error states when applicable. Pressed is visually distinct from hover, and focus remains visible on active controls.

Minimum targets:

- 24 × 24 absolute minimum;
- 32 × 32 compact icon action;
- 36 px ordinary row or control;
- 40 px high-consequence action where space permits.

Every pointer action has a keyboard path and an accessible name. Custom content does not remove that requirement.

## Destructive actions

Clear, forget, logout, reboot, shutdown, and comparable actions require a second activation or reliable undo. Confirmation:

- retains focus on the same control;
- times out;
- is cancelled by Escape or focus loss;
- exposes its confirmation state to accessibility.

## Motion

Canonical durations are:

- micro: 100 ms;
- short: 160 ms;
- medium: 220 ms;
- long: 320 ms.

Feature modules do not invent raw transition durations or easings. Enter uses `OutCubic`, exit uses `InCubic`, and layout movement uses `InOutCubic`. Fast-input mode may shorten a transition but cannot reverse its semantic easing.

Motion is interruptible, reversible, and safe at a zero animation multiplier.

## Lifecycle

Signal connections, timers, queued callbacks, and render requests must not survive their visual owner. Dynamic connections are disconnected before destruction, queued rendering is cancelled, and callbacks become harmless while teardown is active.

## Catppuccin depth

Depth remains flat and opaque:

- crust: lowest underlay;
- mantle: persistent chrome;
- base: page canvas;
- surface0: cards;
- surface1: nested or hover state;
- surface2: pressed or strong selection.

Accent colors are semantic rather than decorative. Warning, critical, connected, Bluetooth, and special-mode colors mean the same thing on Overview and dedicated pages.
