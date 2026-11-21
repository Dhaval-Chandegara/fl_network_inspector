---
phase: 12-api-backward-compatibility-layer
plan: 02
subsystem: compat-tooling
tags: [media_query, lowest_bounds, downgrade, sqflite, ffi, verification]

# Dependency graph
requires:
  - phase: 12-01
    provides: Hardened runtime integrations for share_plus and sensors_plus
provides:
  - Resilient window metric queries in FilterBottomSheet via MediaQuery.maybeSizeOf/maybePaddingOf/maybeViewInsetsOf
  - Dependency floor alignment in pubspec.yaml for share_plus >=11.0.0 and dio >=5.2.0
  - Explicit sqflite top-level re-exports across SQLite FFI platform files and test harnesses
  - Automated lowest-bounds verification pipeline in tool/verify_lowest_bounds.sh with exit signal trap lockfile restoration
affects: [13-multi-version-resolution, 14-documentation-readiness]

# Actuals
actuals:
  tokens: 3100
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns: [defensive-media-query-inspection, lockfile-trap-restoration, targeted-dependency-downgrade]

key-files:
  created:
    - tool/verify_lowest_bounds.sh
  modified:
    - lib/src/ui/components/filter_bottom_sheet.dart
    - pubspec.yaml
    - lib/src/storage/platform/ffi_init_io.dart
    - test/storage/database_schema_test.dart
    - test/storage/database_harness_test.dart
    - test/integration/duplicate_api_calls_test.dart
    - test/integration/full_pipeline_test.dart
    - test/repository/sqlite_repository_test.dart

key-decisions:
  - "Query window dimensions via MediaQuery.maybeSizeOf, maybePaddingOf, and maybeViewInsetsOf with default fallbacks in FilterBottomSheet to eliminate unhandled missing ancestor exceptions"
  - "Align dependency floors in pubspec.yaml with share_plus >=11.0.0 (for SharePlus.instance and ShareParams) and dio >=5.2.0 (for DioException)"
  - "Add explicit import 'package:sqflite/sqflite.dart'; across FFI platform initialization and tests to ensure databaseFactory setter and inMemoryDatabasePath compile on sqflite: 2.2.0"
  - "Implement tool/verify_lowest_bounds.sh using targeted dart pub downgrade and trap cleanup EXIT INT TERM lockfile restoration"

patterns-established:
  - "Defensive MediaQuery inspection using maybe* methods with safe fallbacks"
  - "Automated dependency downgrade verification with zero permanent lockfile contamination"

requirements-completed:
  - API-03
  - API-04

coverage:
  - id: D1
    description: "FilterBottomSheet queries screen dimensions using MediaQuery.maybeSizeOf without throwing in unmounted or headless test contexts"
    requirement: API-03
    verification:
      - kind: unit
        ref: "test/ui/filter_test.dart"
        status: pass
    human_judgment: false
  - id: D2
    description: "pubspec.yaml specifies share_plus >=11.0.0 <14.0.0 and dio >=5.2.0 <6.0.0 matching Dart 3 and DioException compatibility"
    requirement: API-03
    verification:
      - kind: unit
        ref: "flutter analyze --no-fatal-infos"
        status: pass
    human_judgment: false
  - id: D3
    description: "SQLite FFI platform initialization and tests include explicit sqflite imports to support sqflite: 2.2.0 databaseFactory setter and inMemoryDatabasePath"
    requirement: API-04
    verification:
      - kind: unit
        ref: "test/storage/database_schema_test.dart"
        status: pass
      - kind: unit
        ref: "test/storage/database_harness_test.dart"
        status: pass
    human_judgment: false
  - id: D4
    description: "tool/verify_lowest_bounds.sh executes targeted downgrade of direct dependencies, runs all 214+ package tests, and restores pubspec.lock via exit traps"
    requirement: API-04
    verification:
      - kind: other
        ref: "bash tool/verify_lowest_bounds.sh"
        status: pass
    human_judgment: false

# Metrics
duration: 9min
completed: 2026-11-21
status: complete
---

# Phase 12 Plan 02: Window Metrics, Dependency Floor Alignment, and Lowest-Bounds Verification Pipeline Summary

**Standardized MediaQuery queries in FilterBottomSheet, aligned dependency floors in pubspec.yaml, hardened SQLite FFI imports, and an automated lowest-bounds verification pipeline in tool/verify_lowest_bounds.sh**

## Performance

- **Duration:** 9 min
- **Started:** 2026-11-21T15:52:00Z
- **Completed:** 2026-11-21T16:01:00Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- Replaced raw `MediaQuery.of(context)` with `MediaQuery.maybeSizeOf(context) ?? const Size(800, 600)`, `maybePaddingOf(context)`, and `maybeViewInsetsOf(context)` in `FilterBottomSheet` (`API-03`, `D-10`).
- Aligned `pubspec.yaml` dependency floors for `share_plus: ">=11.0.0 <14.0.0"` and `dio: ">=5.2.0 <6.0.0"` to ensure full compatibility with `SharePlus.instance` and `DioException` across all allowed versions (`API-03`, `D-01`, `D-14`).
- Added explicit `import 'package:sqflite/sqflite.dart';` across `lib/src/storage/platform/ffi_init_io.dart` and database test harnesses to support `sqflite: 2.2.0` where `sqflite_common_ffi` does not re-export `databaseFactory` and `inMemoryDatabasePath` (`API-04`, `D-15`).
- Built executable script `tool/verify_lowest_bounds.sh` with `trap cleanup EXIT INT TERM` signal traps that backs up `pubspec.lock`, downgrades direct dependencies to lowest floors, executes all tests, and restores `pubspec.lock` with exit code 0 (`API-04`, `D-13`, `D-14`, `D-16`).

## Task Commits

1. **Task 1: Standardize window metric queries, align dependency floors in pubspec.yaml, and fix SQLite FFI re-exports** - `5879ce9` (feat)
2. **Task 2: Implement automated lowest-bounds verification pipeline tool/verify_lowest_bounds.sh with trap restoration** - `0b41f0b` (feat)

## Files Created/Modified
- `lib/src/ui/components/filter_bottom_sheet.dart` - Standardized window metric queries with defensive `maybe*` accessors.
- `pubspec.yaml` - Aligned dependency floors for `share_plus` (11.0.0) and `dio` (5.2.0).
- `lib/src/storage/platform/ffi_init_io.dart` - Added sqflite import for databaseFactory top-level setter compatibility.
- `test/storage/database_schema_test.dart` - Added sqflite import for `inMemoryDatabasePath`.
- `test/storage/database_harness_test.dart` - Added sqflite import for `inMemoryDatabasePath`.
- `test/integration/duplicate_api_calls_test.dart` - Added sqflite import for `databaseFactory` and `inMemoryDatabasePath`.
- `test/integration/full_pipeline_test.dart` - Added sqflite import for `databaseFactory` and `inMemoryDatabasePath`.
- `test/repository/sqlite_repository_test.dart` - Added sqflite import for `inMemoryDatabasePath`.
- `tool/verify_lowest_bounds.sh` - Automated downgrade verification script with exit traps.

## Decisions Made
- Use `MediaQuery.maybeSizeOf` and insets with fallback values in `FilterBottomSheet` to prevent missing ancestor crashes in custom host overlays.
- Set `share_plus` floor to `11.0.0` and `dio` floor to `5.2.0` per research findings on API compatibility.
- Import `package:sqflite/sqflite.dart` in all test files using `inMemoryDatabasePath` and `databaseFactory` so they pass under `sqflite: 2.2.0`.
- Execute targeted `dart pub downgrade` on direct dependencies only in `tool/verify_lowest_bounds.sh` to avoid pulling in ancient transitive pre-Dart-3 packages.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Added missing sqflite imports to integration and repository tests**
- **Found during:** Task 2 (`tool/verify_lowest_bounds.sh` execution)
- **Issue:** Under `sqflite: 2.2.0`, `sqflite_common_ffi` does not re-export top-level `databaseFactory` and `inMemoryDatabasePath`, causing `test/integration/duplicate_api_calls_test.dart`, `test/integration/full_pipeline_test.dart`, and `test/repository/sqlite_repository_test.dart` to fail compilation.
- **Fix:** Added `import 'package:sqflite/sqflite.dart';` to all three test files.
- **Files modified:** `test/integration/duplicate_api_calls_test.dart`, `test/integration/full_pipeline_test.dart`, `test/repository/sqlite_repository_test.dart`
- **Verification:** `bash tool/verify_lowest_bounds.sh` passed 100% of tests.
- **Committed in:** `0b41f0b` (Task 2 commit)

---
**Total deviations:** 1 auto-fixed (Rule 1)
**Impact on plan:** Essential for test suite compilation under minimum allowable dependency bounds.

## Issues Encountered
None.

## User Setup Required
None.

## Next Phase Readiness
- Phase 12 completed and verified.
- Ready for Phase 13 Multi-Version Resolution & CI Test Matrix.

---
## Self-Check: PASSED
- `tool/verify_lowest_bounds.sh` exists and is executable
- Commit `5879ce9` exists in git history
- Commit `0b41f0b` exists in git history
- `bash tool/verify_lowest_bounds.sh` executed cleanly with exit code 0
