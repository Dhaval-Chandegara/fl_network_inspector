---
phase: 12-api-backward-compatibility-layer
plan: 01
subsystem: ui-sensors
tags: [share_plus, sensors_plus, error_handling, fallback, defensive_programming]

# Dependency graph
requires:
  - phase: 11-dependency-bounds-widening
    provides: Widened semver dependency bounds for share_plus and sensors_plus
provides:
  - Defensive popover origin sanitization for share_exporter against iPadOS/macOS crashes
  - Clipboard fallback with SnackBar notification when native sharing fails
  - Accelerometer coordinate vector validation filtering NaN/infinite readings
  - Sensor hardware availability observation and onSensorError handler
affects: [12-02, 13-multi-version-resolution]

# Actuals
actuals:
  tokens: 2800
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns: [defensive-popover-geometry, native-share-clipboard-fallback, accelerometer-finite-vector-guard, sensor-error-observer]

key-files:
  created: []
  modified:
    - lib/src/ui/utils/share_exporter.dart
    - test/ui/share_exporter_test.dart
    - lib/src/shake/shake_detector.dart
    - test/shake/shake_detector_test.dart

key-decisions:
  - "Sanitize popover origins in ShareExporter.sanitizeOrigin to enforce finite, positive width/height Rects centered on screen to eliminate iPadOS NSGenericException crashes"
  - "Provide automated fallback in ShareExporter.shareRecord to Clipboard.setData with a SnackBar notification on platform sharing errors"
  - "Silently discard NaN and non-finite UserAccelerometerEvent coordinates before magnitude calculation in ShakeDetector._handleEvent"
  - "Track _isSensorAvailable and notify optional onSensorError callback when accelerometer stream throws errors or fails subscription"

patterns-established:
  - "Defensive anchor sanitization before native platform sheet dispatch"
  - "Graceful degradation from native platform channels to Flutter framework services (Clipboard + SnackBar)"
  - "Robust floating-point sensor coordinate validation against hardware/simulator edge cases"

requirements-completed:
  - API-01
  - API-02

coverage:
  - id: D1
    description: "ShareExporter.sanitizeOrigin returns finite, positive-dimension Rect centered on screen if origin has zero size or unmounted context"
    requirement: API-01
    verification:
      - kind: unit
        ref: "test/ui/share_exporter_test.dart#ShareExporter sanitizeOrigin"
        status: pass
    human_judgment: false
  - id: D2
    description: "ShareExporter.shareRecord catches platform share exceptions and copies the formatted report to system clipboard with a SnackBar"
    requirement: API-01
    verification:
      - kind: unit
        ref: "test/ui/share_exporter_test.dart#ShareExporter shareRecord Fallback"
        status: pass
    human_judgment: false
  - id: D3
    description: "ShakeDetector._handleEvent silently discards events with NaN or infinite coordinate readings without throwing math exceptions"
    requirement: API-02
    verification:
      - kind: unit
        ref: "test/shake/shake_detector_test.dart#discards NaN and infinite sensor readings without throwing or firing onShake"
        status: pass
    human_judgment: false
  - id: D4
    description: "ShakeDetector reports isSensorAvailable == false and invokes onSensorError when sensor streams emit errors"
    requirement: API-02
    verification:
      - kind: unit
        ref: "test/shake/shake_detector_test.dart#tracks isSensorAvailable and invokes onSensorError callback on stream error"
        status: pass
    human_judgment: false

# Metrics
duration: 7min
completed: 2026-11-21
status: complete
---

# Phase 12 Plan 01: Runtime Hardening for Share & Sensor Integrations Summary

**Defensive popover origin sanitization and clipboard fallback for ShareExporter alongside NaN vector guards and sensor error observers for ShakeDetector**

## Performance

- **Duration:** 7 min
- **Started:** 2026-11-21T15:45:00Z
- **Completed:** 2026-11-21T15:52:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Implemented `ShareExporter.sanitizeOrigin` to sanitize popover bounds against zero/negative dimensions or detached contexts, preventing iPadOS crashes (`API-01`, `D-03`).
- Added automatic fallback to `Clipboard.setData` with user-facing SnackBar in `ShareExporter.shareRecord` when native sharing is unavailable or fails (`API-01`, `D-02`).
- Hardened `ShakeDetector._handleEvent` with finite float verification (`!event.x.isFinite || !event.y.isFinite || !event.z.isFinite`) to discard NaN/Inf vectors cleanly (`API-02`, `D-05`).
- Added `isSensorAvailable` state tracking and `onSensorError` observer callback in `ShakeDetector` for graceful degradation when sensor hardware fails (`API-02`, `D-07`).
- Supported optional `samplingPeriod` parameter in `ShakeDetector` (`D-06`).
- Expanded test suites in `test/ui/share_exporter_test.dart` and `test/shake/shake_detector_test.dart` with 100% pass rate.

## Task Commits

1. **Task 1: End-to-end resilient ShareExporter with popover origin sanitization and clipboard fallback** - `2c25175` (feat)
2. **Task 2: Harden ShakeDetector with NaN coordinate filtering, sensor availability state, and error observer** - `f936896` (feat)

## Files Created/Modified
- `lib/src/ui/utils/share_exporter.dart` - Added `sanitizeOrigin`, updated `calculateAnchor`, and added clipboard + SnackBar fallback in `shareRecord`.
- `test/ui/share_exporter_test.dart` - Added tests for origin sanitization and platform exception clipboard fallback.
- `lib/src/shake/shake_detector.dart` - Added `samplingPeriod`, `onSensorError`, `isSensorAvailable`, and NaN/Inf guards.
- `test/shake/shake_detector_test.dart` - Added tests for NaN handling, sensor availability tracking, error callbacks, and sampling period.

## Decisions Made
- Sanitize popover origins in `ShareExporter.sanitizeOrigin` by validating `isFinite`, `!isEmpty`, and positive width/height, defaulting to screen center from `MediaQuery.maybeSizeOf(context) ?? const Size(800, 600)`.
- If native sharing throws any exception (such as `PlatformException` or `MissingPluginException`), write report text to system clipboard via `Clipboard.setData` and show a 3-second SnackBar if context is mounted.
- Drop NaN and non-finite accelerometer coordinate vectors prior to Euclidean norm math calculation in `ShakeDetector`.
- Unsubscribe and set `_isSensorAvailable = false` upon stream error, reporting to `onSensorError` observer.

## Deviations from Plan
None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None.

## Next Phase Readiness
- Plan 12-01 completed and verified.
- Plan 12-02 is unblocked and ready to execute in Wave 2.

---
## Self-Check: PASSED
- `lib/src/ui/utils/share_exporter.dart` exists and tested
- `lib/src/shake/shake_detector.dart` exists and tested
- Commit `2c25175` exists in git history
- Commit `f936896` exists in git history
