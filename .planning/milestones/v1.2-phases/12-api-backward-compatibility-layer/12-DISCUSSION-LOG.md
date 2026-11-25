# Phase 12: API & Backward Compatibility Layer - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-11-21
**Phase:** 12-API & Backward Compatibility Layer
**Areas discussed:** Share Adapter & API Fallbacks, Sensor Stream Resilience & Error Reporting, Flutter SDK Compatibility & API Shims, Lowest-Bounds Test Verification Pipeline

---

## Share Adapter & API Fallbacks

| Option | Description | Selected |
|--------|-------------|----------|
| Strict SharePlus.instance | Standardize strictly on SharePlus.instance.share(ShareParams(...)) since pubspec guarantees >=10.0.0 <14.0.0; avoids reflection and retains full compiler type safety | ✓ |
| Adaptive shim | Try SharePlus.instance first, but gracefully fall back to static Share.share() if NoSuchMethodError occurs in mixed environments | |
| You decide | | |

**User's choice:** Strict SharePlus.instance
**Notes:** Retains compile-time safety and relies on pub solver guarantees from Phase 11.

| Option | Description | Selected |
|--------|-------------|----------|
| Fallback to Clipboard with SnackBar | On platform/plugin failure, automatically copy text to Clipboard and show SnackBar ("Sharing unavailable — copied report to clipboard") | ✓ |
| Show Error SnackBar without Clipboard | Display an error SnackBar indicating native sharing is unsupported, letting the user explicitly copy manually | |
| Silent degradation | Log the exception in debug mode without showing UI notifications | |
| You decide | | |

**User's choice:** Fallback to Clipboard with SnackBar
**Notes:** Provides a seamless user experience on desktop/unsupported environments.

| Option | Description | Selected |
|--------|-------------|----------|
| Defensive Rect Sanity Guard | Guarantee origin is non-empty and finite (at least 1x1 rect at center or button origin) before invoking SharePlus to make NSGenericException crashes impossible on iPadOS/macOS | ✓ |
| Keep existing calculateAnchor | Current findRenderObject + MediaQuery fallback is already adequate | |
| You decide | | |

**User's choice:** Defensive Rect Sanity Guard
**Notes:** Prevents iPadOS NSGenericException popover crashes regardless of layout or split-screen state.

| Option | Description | Selected |
|--------|-------------|----------|
| Comprehensive Unit & Widget Test Suite | Cover all branches: valid origin, unmounted context, zero/negative rect expansion, and PlatformException clipboard fallback with SnackBar verification | ✓ |
| Basic UI integration test only | Test only the standard export action from the detail screen | |
| You decide | | |

**User's choice:** Comprehensive Unit & Widget Test Suite
**Notes:** Ensures 100% test coverage over all error and fallback branches.

---

## Sensor Stream Resilience & Error Reporting

| Option | Description | Selected |
|--------|-------------|----------|
| Validate Finite Values & Drop Corrupt Events | Check event.x.isFinite && event.y.isFinite && event.z.isFinite; silently discard NaN or infinite sensor readings to prevent math.sqrt NaN errors | ✓ |
| Raw Event Processing | Process event values directly as received from the plugin stream | |
| You decide | | |

**User's choice:** Validate Finite Values & Drop Corrupt Events
**Notes:** Protects against erratic hardware sensor glitches.

| Option | Description | Selected |
|--------|-------------|----------|
| No-arg default with optional configuration | Invoke userAccelerometerEventStream() with default parameters by default to maximize backward compatibility across 6.x-7.x, with optional samplingPeriod parameter in constructor | ✓ |
| Strict samplingPeriod required | Always pass SensorInterval.uiInterval (20-40ms) explicitly | |
| You decide | | |

**User's choice:** No-arg default with optional configuration
**Notes:** Maintains signature compatibility across sensor plugin versions.

| Option | Description | Selected |
|--------|-------------|----------|
| Expose isSensorAvailable & optional onSensorError callback | Keep graceful degradation as default, but expose isSensorAvailable (bool) and an optional onSensorError callback for host app diagnostics | ✓ |
| Keep strictly internal | Maintain current silent degradation and debugPrint only, with no public status fields | |
| You decide | | |

**User's choice:** Expose isSensorAvailable & optional onSensorError callback
**Notes:** Allows host apps and tests to query sensor health.

| Option | Description | Selected |
|--------|-------------|----------|
| Multi-scenario Sensor Test Suite | Add unit tests for NaN/Infinite events, stream error events, MissingPluginException on subscribe, isSensorAvailable status, and lifecycle transitions | ✓ |
| Minimal test coverage | Test standard shake threshold triggering only | |
| You decide | | |

**User's choice:** Multi-scenario Sensor Test Suite
**Notes:** Validates resilient sensor error handling and recovery.

---

## Flutter SDK Compatibility & API Shims

| Option | Description | Selected |
|--------|-------------|----------|
| Compatibility Shims & Universal Styling | Use styling approaches and compatibility typedefs that compile cleanly across both Flutter 3.10-3.19 and 3.22-3.50+ without compile-time breakage | ✓ |
| Bump minimum Flutter SDK to 3.22.0 | Avoid legacy MaterialStateProperty by raising minimum Flutter SDK to 3.22.0 | |
| You decide | | |

**User's choice:** Compatibility Shims & Universal Styling
**Notes:** Preserves broad compatibility with host apps on Flutter 3.10 through 3.50+.

| Option | Description | Selected |
|--------|-------------|----------|
| Safe MediaQuery.sizeOf & maybeSizeOf | Standardize on MediaQuery.maybeSizeOf / sizeOf with fallback guards to eliminate missing MediaQuery ancestor errors in tests and custom overlays | ✓ |
| Standard MediaQuery.of(context) | Rely on standard MediaQuery.of throughout all UI widgets | |
| You decide | | |

**User's choice:** Safe MediaQuery.sizeOf & maybeSizeOf
**Notes:** Avoids runtime exceptions in headless widget tests and custom overlay contexts.

| Option | Description | Selected |
|--------|-------------|----------|
| Modern APIs with localized polyfills | Maintain 0 warnings on flutter analyze by adopting modern stable APIs (e.g., PopScope) and using clean polyfills for transitional APIs | ✓ |
| Ignore deprecation lints | Suppress deprecated_member_use in analysis_options.yaml to permit legacy Flutter APIs | |
| You decide | | |

**User's choice:** Modern APIs with localized polyfills
**Notes:** Enforces 0 analyzer warnings for 140/140 pub.dev score.

| Option | Description | Selected |
|--------|-------------|----------|
| Standard Dart 3 Immutable Classes | Maintain standard immutable classes with fromMap/toMap and copyWith without sealed restriction on consumer extensions | ✓ |
| Sealed Class Hierarchies | Convert public model hierarchies to sealed classes for exhaustive pattern matching | |
| You decide | | |

**User's choice:** Standard Dart 3 Immutable Classes
**Notes:** Keeps public APIs ergonomic and backwards compatible.

---

## Lowest-Bounds Test Verification Pipeline

| Option | Description | Selected |
|--------|-------------|----------|
| Automated Downgrade Script | A script (tool/verify_lowest_bounds.sh) that backs up pubspec.lock, runs flutter pub downgrade, executes the full test suite, and restores pubspec.lock | ✓ |
| Committed Minimum Lockfile | Check in a permanent pubspec.lock.min fixture to test against without running downgrade dynamically | |
| You decide | | |

**User's choice:** Automated Downgrade Script
**Notes:** Provides a reusable verification workflow for both local development and CI.

| Option | Description | Selected |
|--------|-------------|----------|
| Resilient direct-bounds downgrade | Downgrade direct dependencies to their declared floors (share_plus 10.0.0, sensors_plus 6.0.0, sqflite 2.2.0, etc.), handling any unrelated transitive SDK bounds cleanly | ✓ |
| Strict full downgrade only | Run unguided flutter pub downgrade without any fallback adjustments | |
| You decide | | |

**User's choice:** Resilient direct-bounds downgrade
**Notes:** Protects against unrelated transitive SDK constraint breaks.

| Option | Description | Selected |
|--------|-------------|----------|
| Explicit SQLite Floor Regression Tests | Ensure automated test suite explicitly asserts schema migration, index usage, and batch pruning work identically on sqflite_common_ffi 2.2.0 | ✓ |
| Rely on standard test pass/fail | Run existing tests without adding dedicated database floor regression assertions | |
| You decide | | |

**User's choice:** Explicit SQLite Floor Regression Tests
**Notes:** Guarantees database stability across the full sqflite 2.x range.

| Option | Description | Selected |
|--------|-------------|----------|
| CI-Ready Script Design | Build tool/verify_lowest_bounds.sh with robust traps (guaranteeing pubspec.lock restoration on error), CI exit codes, and non-interactive output for direct use in Phase 13 CI | ✓ |
| Local developer script only | Simple shell commands intended solely for manual local execution | |
| You decide | | |

**User's choice:** CI-Ready Script Design
**Notes:** Directly reusable in Phase 13's GitHub Actions matrix.

---

## the agent's Discretion

- Script syntax, trap handling, and shell portability details in `tool/verify_lowest_bounds.sh` left to planner/executor.

## Deferred Ideas

None — discussion stayed strictly within the phase scope.
