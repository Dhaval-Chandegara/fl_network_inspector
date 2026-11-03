---
phase: 04-inspector-ui
plan: 02
subsystem: ui
tags: [flutter, material3, search, filter, sorting, debounce]

# Dependency graph
requires:
  - phase: 04-inspector-ui
    provides: 04-01-PLAN.md (NetworkInspectorScreen, InspectorViewModel, RequestTile)
provides:
  - SearchBarView with 300ms reactive debounce across URL, method, status code, payload
  - FilterChipsBar for 1-tap quick filtering (All, Errors Only, 2xx, 4xx/5xx, POST, GET)
  - FilterBottomSheet for multi-parameter criteria (methods, status code ranges, duration, date range)
  - SortMenuButton in AppBar supporting newest, oldest, fastest, slowest, status code
  - Empty state with "No Matching Requests" and "Reset Filters" action button
affects:
  - 04-03-PLAN.md (detail screen)
  - 04-04-PLAN.md (curl generator and export)

actuals:
  tokens: 22000
  tasks: 3
  commits: 1

tech-stack:
  added: []
  patterns:
    - 300ms Timer debounce on search input with explicit cancellation in dispose
    - Null-safe sentinel pattern in RecordFilter.copyWith for explicit field clearing
    - Modal bottom sheet with multi-parameter filter dispatch and Material surface wrapping
    - Material 3 PopupMenuButton<RecordSort> with active checkmark indicators

key-files:
  created:
    - lib/src/ui/components/search_bar_view.dart
    - lib/src/ui/components/filter_chips_bar.dart
    - lib/src/ui/components/filter_bottom_sheet.dart
    - lib/src/ui/components/sort_menu_button.dart
    - test/ui/search_test.dart
    - test/ui/filter_test.dart
    - test/ui/sorting_test.dart
  modified:
    - lib/src/models/record_filter.dart
    - lib/src/ui/controllers/inspector_view_model.dart
    - lib/src/ui/network_inspector_screen.dart

key-decisions:
  - "D-54: 300ms Timer debounce on SearchBar input avoids excessive SQLite query allocations during fast typing"
  - "D-55: Quick-filter chip presets provide 1-tap filtering for All, Errors Only, 2xx, 4xx/5xx, POST, and GET, complemented by modal bottom sheet"
  - "UI-05: AppBar sort menu provides instant reordering by newest, oldest, fastest, slowest, and status code with visual checkmarks"
  - "Fixed RecordFilter.copyWith to use a sentinel Object so passing null explicitly resets filter parameters"

patterns-established:
  - "FilterBottomSheet isolates advanced filter parameters in a local stateful sheet, dispatching only on Apply"
  - "SearchBarView provides clear button ('x') that immediately resets search query and restores unfiltered records"

requirements-completed:
  - UI-03
  - UI-04
  - UI-05

coverage:
  - id: D1
    description: "Developers can search network records in real time with 300ms debounce across URL, method, status, and payload"
    requirement: UI-03
    verification:
      - kind: automated_ui
        ref: "test/ui/search_test.dart#debounces search input by 300ms across records"
        status: pass
  - id: D2
    description: "Horizontal quick-filter chips bar and modal bottom sheet filter records by method, status, duration, and date"
    requirement: UI-04
    verification:
      - kind: automated_ui
        ref: "test/ui/filter_test.dart#FilterChipsBar toggles Errors Only and method filters"
        status: pass
  - id: D3
    description: "AppBar popup menu allows sorting by newest, oldest, fastest, slowest, and status code with checkmark indicators"
    requirement: UI-05
    verification:
      - kind: automated_ui
        ref: "test/ui/sorting_test.dart#AppBar SortMenuButton reorders records by duration and timestamp"
        status: pass
---

# Phase 04 Plan 02 Summary: Real-Time Search, Quick Filters & Multi-Criteria Sorting

Implemented real-time search, quick-filter chips, modal filter sheet, and sorting controls for the network inspector:

1. **Debounced Search**: Created `SearchBarView` implementing a Material 3 SearchBar with a 300ms reactive `Timer` debounce, clear button ('x'), and "No Matching Requests" empty state with a "Reset Filters" action.
2. **Filter Chips Bar & Sheet**: Built `FilterChipsBar` supporting 1-tap quick filtering (All, Errors Only, 2xx, 4xx/5xx, POST, GET) and `FilterBottomSheet` for multi-parameter filtering across HTTP methods, status code categories, error state, duration ranges, and date ranges.
3. **Sorting**: Built `SortMenuButton` in the AppBar supporting Newest First, Oldest First, Fastest First, Slowest First, and Status Code with visual checkmark indicators.
4. **Fixes**: Corrected `RecordFilter.copyWith` with a sentinel object pattern to support explicitly clearing fields to `null`.
5. **Automated Testing**: 5 new widget test suites verifying debounce timing, empty search states, chip toggling, bottom sheet filters, and sorting orders.
