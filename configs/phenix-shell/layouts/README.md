# Phenix Layout Composites

These files contain **no Quickshell imports** and compose native Qt Quick
Controls. They are presets, not new layout engines.

| Composite | Native building blocks | API |
| --- | --- | --- |
| `TabbedPane` | `TabBar` or vertical `TabButton` rail, `StackLayout`, `Frame`, `Loader` | `tabs`, `currentIndex`, `orientation`, `keepPagesAlive` |
| `SplitPane` | `SplitView` | Native children, `SplitView.*` attached constraints, `saveState`/`restoreState` |
| `SidebarPane` | `SplitPane` and two `Loader` slots | `sidebar`, `mainPane`, width limits, `sidebarVisible` |
| `PageScaffold` | `ColumnLayout`, `RowLayout`, `Label`, `Loader` | `title`, `description`, `breadcrumbs`, `headerActions`, `toolbar`, `footer` |

## Tab bar (horizontal and vertical)

Use the *same tab model* for both orientations. Each tab owns a native QML
`Component` which may be reused across multiple pages. `StackLayout` retains
page state when `keepPagesAlive` is true. Set it false for lazy pages.

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.layouts as Layouts

Layouts.TabbedPane {
    Layout.fillWidth: true
    Layout.fillHeight: true
    orientation: Qt.Vertical // Qt.Horizontal for top tabs
    currentIndex: 0
    tabs: [
        { label: "Overview", page: overview },
        { label: "Network", page: network },
        { label: "Advanced", page: advanced, enabled: true }
    ]
}

Component { id: overview; Pane { Label { text: "Overview" } } }
Component { id: network; Pane { Label { text: "Network" } } }
Component { id: advanced; Pane { Label { text: "Advanced" } } }
```

The horizontal variant uses Qt's `TabBar` and `TabButton`. Qt's TabBar is
horizontal-only; the vertical variant is a `ColumnLayout` of native
`TabButton` controls. Both share the same `StackLayout` and selection index.
No custom mouse, keyboard, or check state controllers are implemented.

## Split panes / sidebar

```qml
Layouts.SplitPane {
    orientation: Qt.Horizontal

    TreeView {
        SplitView.preferredWidth: 240
        SplitView.minimumWidth: 150
    }
    TableView {
        SplitView.fillWidth: true
    }
}

// Simpler master/detail case:
Layouts.SidebarPane {
    sidebar: sidebarContent
    mainPane: detailContent
    preferredSidebarWidth: 230
}
Component { id: sidebarContent; ListView { /* model/delegate */ } }
Component { id: detailContent; ScrollView { /* detail editor */ } }
```

`SplitPane` inherits `SplitView` so persist splitter sizes using Qt's
`saveState()` and `restoreState()`, not custom drag bookkeeping.
`SidebarPane.splitView` exposes the underlying view for persistence.

## Page shell

```qml
Layouts.PageScaffold {
    title: "Packages"
    description: "Manage installed packages"
    breadcrumbs: trail
    headerActions: tools

    TreeView { Layout.fillWidth: true; Layout.fillHeight: true }
}
Component { id: trail; /* Phenix Breadcrumbs or any Item */ }
Component { id: tools; ToolBar { /* app actions */ } }
```

`PageScaffold` deliberately does not own a `Flickable`, routing state, or
focus policy. Put native `ScrollView`, `StackView`, `TreeView`, `TableView`
and other complex controls inside its body. Existing `DashboardPage` remains
for the *dashboard product* and its overview/detailed mode.

## Runtime / portability

- Quickshell: `import qs.layouts as Layouts`
- Standalone Qt Quick: `import "/path/to/layouts" as Layouts`, or a local
  relative import such as `import "../layouts" as Layouts`.
- For the styled appearance, load the portable `Phenix` style as a Qt 6 QML
  module via `QML_IMPORT_PATH` and select it using
  `QT_QUICK_CONTROLS_STYLE=Phenix`.
- Tests: `tests/LayoutSmoke.qml` loads both tab orientations, resizable split
  panes, sidebar and scaffold using the native offscreen Qt runtime.
