---
phase: 04-inspector-ui
plan: 01
subsystem: ui
tags: [flutter, material3, pagination, theme, clear-all, request-tile]

# Dependency graph
requires:
  - phase: 02-sqlite-persistence
    provides: NetworkInspectorRepository and in-memory/sqlite implementations
  - phase: 03-network-capture-interceptors
    provides: captured NetworkRecord pipeline and manual logging facade
provides:
  - NetworkInspector.open(context) programmatic navigation API with reentrancy guard
  - Material 3 NetworkInspectorScreen listing feed with real-time badges
  - InspectorViewModel supporting threshold infinite scrolling (50 items/batch at 80% scroll depth)
  - ThemeController with local Material 3 theme mode toggling (System/Light/Dark)
  - ClearAllDialog for safe database record purging
affects:
  - 04-02-PLAN.md (search, filter chips, and sorting)
  - 04-03-PLAN.md (request details inspector)
  - 04-04-PLAN.md (curl generator and export sheet)

actuals:
  tokens: 18500
  tasks: 3
  commits: 1

tech-stack:
  added:
    - share_plus: ^13.3.1
    - intl: ^0.20.3
  patterns:
    - Reentrancy-guarded programmatic screen presentation (_isOpen flag in try-finally)
    - Threshold-based batch pagination (50 items/batch at 80% scroll depth)
    - Local Theme override without mutating host application root theme
    - Material 3 semantic method and status code badges

key-files:
  created:
    - lib/src/ui/components/status_badge.dart
    - lib/src/ui/components/request_tile.dart
    - lib/src/ui/components/clear_all_dialog.dart
    - lib/src/ui/controllers/theme_controller.dart
    - lib/src/ui/controllers/inspector_view_model.dart
    - lib/src/ui/network_inspector_screen.dart
    - test/ui/helpers/test_record_fixtures.dart
    - test/ui/network_inspector_screen_test.dart
    - test/ui/pagination_test.dart
    - test/ui/clear_all_test.dart
  modified:
    - pubspec.yaml
    - lib/src/config/network_inspector_config.dart
    - lib/src/core/network_inspector.dart
    - lib/src/models/network_record.dart

key-decisions:
  - "D-49/D-51/D-52: Implemented NetworkInspector.open(context) with _isOpen reentrancy guard to prevent duplicate modal routes on rapid shakes"
  - "D-50: ThemeController defaults to ThemeMode.system and overrides theme locally inside the inspector without modifying host app theme"
  - "D-56: Implemented threshold-based infinite scrolling (50 items/batch at 80% scroll depth) in InspectorViewModel to prevent UI isolate memory spikes"
  - "D-53: Two-line RequestTile cards with colored MethodBadge, StatusBadge, truncated endpoint path, duration, timestamp, and payload size"

patterns-established:
  - "InspectorViewModel extends ChangeNotifier coordinating paginated repository reads and search/sort queries"
  - "ClearAllDialog implements destructive confirmation contract before executing repository.clearAll()"

requirements-completed:
  - UI-01
  - UI-02
  - UI-06

coverage:
  - id: D1
    description: "Developers can open the inspector UI full-screen via NetworkInspector.open(context) with reentrancy protection"
    requirement: UI-01
    verification:
      - kind: automated_ui
        ref: "test/ui/network_inspector_screen_test.dart#open(context) pushes screen and guards against duplicate open"
        status: pass
  - id: D2
    description: "Listing screen renders request tiles with color-coded method, status, path, timestamp, duration, and payload size"
    requirement: UI-01
    verification:
      - kind: automated_ui
        ref: "test/ui/network_inspector_screen_test.dart#renders request tiles with method badges, status badges, and paths"
        status: pass
  - id: D3
    description: "Threshold batch pagination loads records in 50-item chunks at 80% scroll depth with pull-to-refresh"
    requirement: UI-02
    verification:
      - kind: automated_ui
        ref: "test/ui/pagination_test.dart#loads initial 50 records and auto-fetches next 50 on scroll"
        status: pass
  - id: D4
    description: "Clear-all action displays confirmation dialog before purging repository and transitioning to empty state"
    requirement: UI-06
    verification:
      - kind: automated_ui
        ref: "test/ui/clear_all_test.dart#confirming Clear All wipes repository and transitions to empty state"
        status: pass
---

# Phase 04 Plan 01 Summary: Inspector UI Scaffolding & Listing Feed

Established the foundational Material 3 UI scaffolding and paginated feed for the network inspector:

1. **Dependencies & Navigation**: Added `share_plus` and `intl`. Implemented `NetworkInspector.open(context)` with reentrancy guard (`_isOpen`), navigator key fallback, and fullscreen dialog route.
2. **Badges & Request Tile**: Created `MethodBadge` and `StatusBadge` mapping HTTP verbs and status codes to semantic colors (#0284C7 for GET, #16A34A for POST/2xx, #D97706 for 4xx, #DC2626 for 5xx/errors, #64748B for pending). Built two-line `RequestTile` cards.
3. **Pagination & View Model**: Created `InspectorViewModel` executing 50-record batch pagination triggered at 80% scroll depth with pull-to-refresh.
4. **Theme & Clear All**: Built `ThemeController` cycling System -> Light -> Dark locally, and `ClearAllDialog` safely purging repository records.
5. **Automated Testing**: 13 widget tests verifying presentation, pagination, navigation reentrancy, theme toggling, and dialog confirmation.
