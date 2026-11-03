---
phase: 05-shake-developer-experience
plan: 01
subsystem: shake
tags: [sensors_plus, accelerometer, shake-detector, lifecycle, debounce, euclidean-norm]

# Dependency graph
requires:
  - phase: 01-foundation-models
    provides: NetworkInspectorConfig, NetworkInspectorConstants
provides:
  - ShakeDetector managing stream subscriptions and app lifecycle observation
  - Config parameters shakeThreshold and shakeDebounceMs
affects:
  - 05-02-PLAN.md (NetworkInspectorWrapper and facade integration)

actuals:
  tokens: 28000
  tasks: 2
  commits: 1

tech-stack:
  added:
    - sensors_plus: ^7.1.1
  patterns:
    - User accelerometer stream with gravity vector isolation (9.8 m/s² subtracted)
    - Euclidean norm vector magnitude calculation sqrt(x*x + y*y + z*z)
    - 1500ms debounce cooldown preventing repeat triggers from physical rebound oscillations
    - WidgetsBindingObserver pausing hardware stream sampling on paused/inactive/hidden states
    - Graceful error catch and stream cancellation for platforms without sensors

key-files:
  created:
    - lib/src/shake/shake_detector.dart
    - test/shake/shake_detector_test.dart
  modified:
    - pubspec.yaml
    - lib/src/core/constants.dart
    - lib/src/config/network_inspector_config.dart
    - test/config/network_inspector_config_test.dart

key-decisions:
  - "D-65: ShakeDetector uses userAccelerometerEventStream() to isolate dynamic user motion by subtracting static gravity at the platform layer (SHAKE-01)"
  - "D-66: Vector magnitude threshold defaults to 15.0 m/s² with configurable overrides in NetworkInspectorConfig (SHAKE-01, SHAKE-02)"
  - "D-67: ShakeDebounceMs defaults to 1500ms to eliminate rebound oscillation duplicate triggers (SHAKE-02)"
  - "D-68: WidgetsBindingObserver pauses sensor sampling when app is backgrounded, eliminating battery drain (SHAKE-03)"

requirements-completed:
  - SHAKE-01
  - SHAKE-02
  - SHAKE-03

verification:
  - "flutter test test/shake/shake_detector_test.dart test/config/network_inspector_config_test.dart passes"
---

# Plan 05-01 Summary: Shake Detection Engine & Lifecycle Sampling Manager

Implemented the hardware accelerometer shake detection engine and battery-conscious lifecycle manager using `sensors_plus: ^7.1.1`.

## What Was Done

1. **Package Dependencies & Constants:**
   - Added `sensors_plus: ^7.1.1` to `pubspec.yaml`.
   - Added `defaultShakeThreshold = 15.0` (m/s²) and `defaultShakeDebounceMs = 1500` (ms) to `NetworkInspectorConstants`.
   - Added `shakeThreshold` and `shakeDebounceMs` fields to `NetworkInspectorConfig` with full constructor and `copyWith` support.

2. **Shake Detection Engine (`lib/src/shake/shake_detector.dart`):**
   - Built `ShakeDetector` implementing `WidgetsBindingObserver`.
   - Listens to `userAccelerometerEventStream()`, which mathematically isolates dynamic movement by subtracting the constant 9.8 m/s² gravitational vector.
   - Computes Euclidean norm `math.sqrt(x*x + y*y + z*z)`.
   - Checks magnitude against `threshold` (default: 15.0 m/s²) and verifies `debounceMs` (default: 1500ms) cooldown elapsed before triggering `onShake()`.
   - Implements `didChangeAppLifecycleState`:
     - Calls `pause()` when app state transitions to `paused`, `inactive`, `detached`, or `hidden`.
     - Calls `resume()` when app state transitions to `resumed`.
   - Implements graceful stream error catching with debug logging and clean cancellation when accelerometer sensors are missing or throw errors.
   - Accepts an optional `customStream` parameter allowing deterministic unit testing with zero platform channel dependencies.

3. **Automated Testing:**
   - Added 8 unit tests in `test/shake/shake_detector_test.dart` verifying magnitude thresholding, debounce windowing, lifecycle pause/resume, and error handling.
   - Updated `test/config/network_inspector_config_test.dart` to verify default parameters and `copyWith` behavior.
