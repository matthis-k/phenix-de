# Dashboard composition and interaction specification

This document is the task contract for the dashboard refinement following the
composition work in `docs/ui-design.md`. It turns the current visual and runtime
issues into testable behavior and keeps the Overview and dedicated pages from
drifting back into competing hierarchies.

## Information architecture

The dashboard has two disclosure levels:

1. **Overview** presents one shallow snapshot of each domain: its primary state,
   its primary control when useful, and one navigation action to its dedicated
   page.
2. **Dedicated pages** own management, history, diagnostics, object lists, and
   per-object detail.

Overview sections must not embed a second section hierarchy. A domain snapshot
may contain multiple peer rows, such as Wi-Fi and VPN, but not nested headers or
another informational disclosure level. More information is reached through the
domain navigation action.

Local detail remains a per-component concern. The dashboard-wide detail shortcut
sets every participating component to detailed presentation without replacing
their stored local choices. Dedicated pages may expose component detail toggles;
Overview does not duplicate those toggles beside a navigation action.

## Action icon semantics

Icon meaning is strict across every page:

- `+` expands hidden information in place.
- `−` collapses information in place.
- a directional arrow navigates to another page or object destination.
- switches change boolean state and never also navigate.

The same affordance cannot change meaning between Overview and a dedicated page.
Every icon-only action has an accessible name that describes the resulting
action, not the icon.

## Cross-section alignment

Peer Overview rows share four horizontal lanes:

1. leading status icon;
2. label and secondary state;
3. primary control or metric;
4. trailing navigation action.

The leading icon slot, text start, switch slot, and navigation slot use shared
widths. A missing optional action reserves no phantom nested column, while rows
with the same action type align exactly. Section content has explicit margins on
all four sides; no chart, legend, or trailing action touches a card edge.

## Battery semantics

Battery estimates describe the current direction:

- charging: `Full in …`;
- discharging: `Empty in …`;
- fully charged, pending, or unavailable estimate: omit the estimate rather than
  showing the opposite direction.

Overview keeps charge, estimate, and compact power-profile controls on one row.
Battery history and diagnostics remain on the Power & Display page.

## System statistics

Overview contains one row of compact RAM, CPU, and Storage gauges. The dedicated
System Stats page owns larger history and per-core controls.

Per-core controls follow these rules:

- delegates have stable identity across value updates;
- labels are one-based (`Core 1`, `Core 2`, …);
- each control includes a small arc gauge as well as its rough percentage;
- the percentage is centered inside the arc, uses smaller text, and the arc uses
  a comparatively thick stroke;
- a series keeps the same semantic color when disabled; disabling adds a subtle,
  non-opaque dark overlay and reduced emphasis instead of replacing the color;
- values are intentionally rounded because fast recognition matters more than
  exact sampling precision;
- the legend grid has balanced outer margins and internal gaps.

## Notifications

The Notifications page always shows the feed and its actions. Global or local
detail presentation must not hide clear, dismiss, inspect, or other available
notification actions.

Notification media is presented when the source supplies it:

- image paths and image URLs are normalized into a renderable source;
- screenshot notifications show an inline aspect-preserving preview;
- previews are bounded in height and clipped to the card radius;
- missing, invalid, or unsupported media falls back to the text-only card without
  changing card geometry unexpectedly;
- accessible text identifies the preview when meaningful source text exists.

## Opening, scrolling, and input containment

Opening the dashboard starts at the selected page's intended scroll position
without visibly scrolling through intermediate content. The initial positioning
is immediate. Scroll animation is allowed only after the dashboard is already
open and the user changes selection or requests navigation.

While the dashboard is visible, its input surface consumes pointer presses,
releases, taps, touch events, and wheel events within its bounds. An event handled
by dashboard chrome or a page must not reach the compositor surface behind it,
change the underlying workspace layout, focus an underlying window, or activate a
top-level at the same screen coordinate. Closing on an outside click, if enabled,
consumes that click as well.

## Acceptance stories

1. Open the dashboard on a long page. The target page appears at its initial
   position without a visible animated traversal.
2. With the dashboard still open, navigate between pages. Intended page movement
   may animate, but never exposes unrelated page content.
3. Click and scroll repeatedly on sidebar items, card margins, switches, and
   navigation icons. Only dashboard state changes; the underlying Hyprland layout
   and focused top-level remain unchanged.
4. Expand and collapse a component. The action uses `+` and `−`. Navigate to a
   dedicated page. The action uses an arrow.
5. Compare Overview sections at the same width. Peer icons, labels, switches, and
   navigation actions occupy the same horizontal lanes.
6. Observe CPU cores for at least ten updates, including toggling a series off and
   on. Buttons do not blink or move, colors remain identifiable, disabled state is
   a translucent overlay, and every button contains a readable arc gauge.
7. Test battery state while charging and discharging. Only the directionally
   correct estimate appears.
8. Open Notifications in overview and global detailed modes. The feed and all
   actions remain visible in both.
9. Generate a screenshot notification. Its preview appears inside the card,
   remains bounded, and does not displace the notification actions.

## Delivery slices

1. **Specification:** this contract and its acceptance stories.
2. **Composition and visuals:** icon semantics, shared alignment lanes, battery
   estimate semantics, flat Overview composition, and CPU core gauges.
3. **Notification media:** always-visible feed/actions and bounded image previews.
4. **Interaction lifecycle:** immediate initial positioning and complete pointer,
   touch, and wheel containment.

Each implementation slice must preserve a valid `main`, pass repository
maintenance, and be merged before its dependent slice.
