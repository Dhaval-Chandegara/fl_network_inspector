# Phase 12: API & Backward Compatibility Layer - Context

**Gathered:** 2026-11-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Implement resilient adapters, shims, sensor stream error guards, and test verification pipelines ensuring zero compilation breaks or runtime exceptions across the widened dependency versions (`share_plus`, `sensors_plus`, `intl`, `sqflite`, `dio`, `http`, `uuid`) and older Flutter SDKs (from Flutter 3.35/3.40 through latest 3.50+), satisfying requirements API-01, API-02, API-03, and API-04.

</domain>

<decisions>
## Implementation Decisions

### Share Adapter & API Fallbacks (`share_plus`)
- **D-01:** Standardize strictly on `SharePlus.instance.share(ShareParams(...))` across `ShareExporter`. Since `pubspec.yaml` specifies `share_plus: ">=10.0.0 <14.0.0"`, `SharePlus.instance` and `ShareParams` are guaranteed by the pub solver, maintaining full compile-time type safety without brittle reflection or dynamic shims. — **Reversibility:** costly — Published dependency contracts dictate consumer pub resolution and sharing signatures.
- **D-02:** Implement native platform failure fallback to Clipboard: if native sharing throws an exception (`PlatformException`, `MissingPluginException`, or desktop environment without sharing handler), `ShareExporter` catches the exception, copies the formatted export to the system clipboard via `Clipboard.setData()`, and displays a user-friendly SnackBar notifying the user that the report was copied to the clipboard.
- **D-03:** Add defensive `sharePositionOrigin` geometry sanitization before invoking `SharePlus.instance.share`: verify `origin.isFinite && !origin.isEmpty`; if invalid (zero width/height or unmounted layout), expand to a safe 1x1 point rect at the screen center (`MediaQuery.maybeSizeOf` fallback) to guarantee zero `NSGenericException` crashes on iPadOS / macOS.
- **D-04:** Provide comprehensive unit and widget tests covering all `ShareExporter` branches: normal share dispatch with valid origin, unmounted context fallback, detached render box fallback, zero/negative rect expansion, and simulated `PlatformException` triggering clipboard copy + SnackBar verification.

### Sensor Stream Resilience & Error Reporting (`sensors_plus`)
- **D-05:** Guard `_handleEvent` in `ShakeDetector` to verify `event.x.isFinite && event.y.isFinite && event.z.isFinite`. Silently discard any NaN or infinite sensor readings to prevent `math.sqrt` NaN calculation errors or erratic shake triggers.
- **D-06:** Invoke `userAccelerometerEventStream()` with default parameters (no-arg) by default for maximum backwards compatibility across `sensors_plus` 6.x and 7.x, with an optional `samplingPeriod` parameter in the `ShakeDetector` constructor for custom intervals.
- **D-07:** Expose `bool get isSensorAvailable` and an optional `void Function(Object error)? onSensorError` callback on `ShakeDetector`. Maintain silent, graceful degradation by default (printing debug logs and unlistening on failure), while enabling host apps or tests to observe sensor health.
- **D-08:** Add a multi-scenario sensor test suite covering: valid shake events, NaN/infinite coordinates discarding, stream emission errors (`onError`), `MissingPluginException` handling on `start()`, `isSensorAvailable` state transitions, and lifecycle pause/resume behavior.

### Flutter SDK Compatibility & API Shims
- **D-09:** Maintain clean cross-version compatibility across Flutter 3.10 through Flutter 3.50+ using styling approaches and localized compatibility shims/typedefs (e.g. for `MaterialStateProperty` vs `WidgetStateProperty`) so host apps on older or newer Flutter toolchains compile without errors.
- **D-10:** Standardize UI window metric queries on `MediaQuery.maybeSizeOf(context)` / `MediaQuery.sizeOf(context)` with fallback guards to eliminate missing `MediaQuery` ancestor exceptions in headless widget tests and custom overlay hosts.
- **D-11:** Maintain 0 warnings on `flutter analyze` on current stable Flutter toolchains by adopting modern stable APIs (e.g. `PopScope`, modern theme tokens) with localized fallback shims for transitional APIs.
- **D-12:** Maintain standard Dart 3 immutable classes (`fromMap`/`toMap`, `copyWith`) for public models (`NetworkRecord`, payloads) without restrictive sealed class hierarchies, preserving frictionless consumer subclassing and extensions.

### Lowest-Bounds Test Verification Pipeline
- **D-13:** Build an automated downgrade verification shell script (`tool/verify_lowest_bounds.sh`) that backs up `pubspec.lock`, executes `flutter pub downgrade` (or targeted direct dependency downgrade), runs `flutter test`, and reliably restores `pubspec.lock` upon completion or exit trap.
- **D-14:** Make the downgrade pipeline resilient against unrelated transitive SDK bounds by prioritizing direct dependency floors (`share_plus: 10.0.0`, `sensors_plus: 6.0.0`, `sqflite: 2.2.0`, `intl: 0.18.0`, `uuid: 4.0.0`, `path: 1.8.0`, `dio: 5.0.0`, `http: 1.0.0`).
- **D-15:** Implement explicit SQLite floor regression assertions verifying that schema migrations, indices, batch inserts, and auto-retention cleanup behave identically on `sqflite_common_ffi: 2.2.0` as on later releases.
- **D-16:** Design `tool/verify_lowest_bounds.sh` with CI exit codes, non-interactive logging, and error traps for seamless integration into Phase 13's automated GitHub Actions CI matrix.

### the agent's Discretion
- Planner and researcher may determine the exact script syntax and trap handling in `tool/verify_lowest_bounds.sh` to ensure compatibility across macOS and Linux CI environments.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Package Manifest & Roadmap
- [pubspec.yaml](file:///Users/dhavalchandegara/projects/fl_network_inspector/pubspec.yaml) — Widened dependency ranges and SDK environment declarations.
- [.planning/ROADMAP.md](file:///Users/dhavalchandegara/projects/fl_network_inspector/.planning/ROADMAP.md#L61-L71) §Phase 12 — Goals, dependencies, and success criteria for API & Backward Compatibility Layer.
- [.planning/REQUIREMENTS.md](file:///Users/dhavalchandegara/projects/fl_network_inspector/.planning/REQUIREMENTS.md#L18-L25) §API-01..04 — Functional requirements for API backward compatibility and testing.
- [.planning/phases/11-dependency-bounds-widening/11-CONTEXT.md](file:///Users/dhavalchandegara/projects/fl_network_inspector/.planning/phases/11-dependency-bounds-widening/11-CONTEXT.md) — Upstream dependency widening decisions and constraints.

### Core Implementation Files
- [lib/src/ui/utils/share_exporter.dart](file:///Users/dhavalchandegara/projects/fl_network_inspector/lib/src/ui/utils/share_exporter.dart) — Native OS share export logic, iPadOS anchor calculations, and clipboard fallback target.
- [lib/src/shake/shake_detector.dart](file:///Users/dhavalchandegara/projects/fl_network_inspector/lib/src/shake/shake_detector.dart) — Accelerometer sensor stream listener, error handling, and lifecycle observer.
- [lib/src/database/network_database_helper.dart](file:///Users/dhavalchandegara/projects/fl_network_inspector/lib/src/database/network_database_helper.dart) — SQLite database schema, indices, migrations, and pruning operations.

### Existing Test Suites
- [test/ui/utils/share_exporter_test.dart](file:///Users/dhavalchandegara/projects/fl_network_inspector/test/ui/utils/share_exporter_test.dart) — Unit tests for markdown, curl, json formatting and share delegate mocking.
- [test/shake/shake_detector_test.dart](file:///Users/dhavalchandegara/projects/fl_network_inspector/test/shake/shake_detector_test.dart) — Unit tests for shake magnitude thresholds, debounce, and lifecycle transitions.
- [test/database/network_database_helper_test.dart](file:///Users/dhavalchandegara/projects/fl_network_inspector/test/database/network_database_helper_test.dart) — In-memory SQLite FFI persistence and migration tests.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ShareExporter`: Existing static utility with `calculateAnchor(context)` and `mockShareDelegate` hook. Ready to be enhanced with defensive rect expansion and clipboard fallback.
- `ShakeDetector`: Existing lifecycle-aware accelerometer listener with `mockStream` injection. Ready to be enhanced with NaN checks, `isSensorAvailable` getter, and `onSensorError` callback.
- `NetworkDatabaseHelper`: Pure abstracted SQLite database helper operating against `sqflite` / `sqflite_common_ffi`.

### Established Patterns
- All external third-party plugin interactions are isolated behind helper classes with mock hooks for headless unit testing without platform channels.
- In-memory database testing using `sqflite_common_ffi` and `databaseFactoryFfi` enables headless SQL verification without device dependencies.

### Integration Points
- `tool/verify_lowest_bounds.sh`: New automated verification tool script for local and CI regression runs.
- `lib/src/ui/utils/share_exporter.dart`: Integration point for `SharePlus.instance.share` and `Clipboard.setData`.
- `lib/src/shake/shake_detector.dart`: Integration point for `sensors_plus` stream handling.

</code_context>

<specifics>
## Specific Ideas

- Standardize strictly on `SharePlus.instance.share(ShareParams(...))` with safe defensive origin bounds checking.
- When sharing throws `PlatformException` or `MissingPluginException`, copy to `Clipboard` and show a `SnackBar`.
- Verify `isFinite` on accelerometer readings before calculating magnitude to prevent NaN issues.
- Build `tool/verify_lowest_bounds.sh` with signal traps to always restore `pubspec.lock`.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed strictly within the phase scope.

</deferred>

---

*Phase: 12-API & Backward Compatibility Layer*
*Context gathered: 2026-11-21*
