# Phase 5: Shake & Developer Experience - Context

**Gathered:** 2026-11-02
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase delivers frictionless invocation triggers and ergonomic developer setup for the inspector package:
- Hardware accelerometer shake detection using `sensors_plus` gravity-subtracted motion stream (`userAccelerometerEventStream()`).
- Configurable acceleration threshold (default `15.0 m/s²`) and debounce cooldown window (`1500 ms`) to prevent false positives and route stacking.
- Lifecycle-aware sensor listener (`WidgetsBindingObserver`) that pauses hardware sampling when the host app transitions to the background (`paused`, `inactive`, `hidden`) and resumes on `resumed`, eliminating battery drain.
- `NetworkInspectorWrapper` root widget that encapsulates lifecycle observation and shake detection around the host app with zero manual boilerplate.
- Contextless programmatic opening via `NetworkInspector.open([BuildContext? context])` leveraging `navigatorKey`.
- Graceful degradation on Desktop and Web platforms where accelerometer hardware is unavailable, with zero exceptions thrown.
- Complete zero-overhead compile/runtime no-op when `config.enabled` is false (default in release builds).

</domain>

<decisions>
## Implementation Decisions

### Shake Detection Engine & Gesture Mathematics (SHAKE-01, SHAKE-02)
- Motion stream: Use `userAccelerometerEventStream()` from `sensors_plus` which subtracts 9.8 m/s² gravity vector directly in platform channels, isolating dynamic user shake motion without spurious tilt triggers.
- Vector magnitude: Calculate Euclidean norm `sqrt(x*x + y*y + z*z)` exceeding threshold `shakeThreshold` (default: 15.0 m/s²).
- Debounce window: Enforce 1.5s cooldown (`shakeDebounceMs: 1500`) to prevent duplicate triggers from physical phone rebound oscillations.
- Platform safety: Gracefully no-op on Desktop (macOS, Windows, Linux) and Web (`kIsWeb`) without throwing `MissingPluginException`.

### App Lifecycle & Battery Optimization (SHAKE-03)
- Lifecycle management: Implement `WidgetsBindingObserver` to pause sensor event subscriptions when app is `paused`, `inactive`, or `hidden`, and resume when `resumed`.
- Encapsulated controller: Dedicated `ShakeDetector` class with clean `start()`, `stop()`, `pause()`, `resume()`, and `dispose()` methods.
- Hardware error handling: Catch stream errors (`onError`) gracefully if accelerometer hardware is absent, log a single debug notice, and cancel subscription without retrying.
- Release mode safety: In release builds where `config.enabled` is false, `ShakeDetector` completely no-ops and allocates zero sensor listeners.

### Root Wrapper & Developer Experience (DEV-01, DEV-02)
- Root wrapper: `NetworkInspectorWrapper` `StatefulWidget` wrapping root application widget, managing `ShakeDetector` and lifecycle subscriptions automatically.
- Programmatic opening: Enhance `NetworkInspector.open([BuildContext? context])` allowing `context` to be optional if `config.navigatorKey` is supplied or registered by `NetworkInspectorWrapper`.
- Visual overlay: Pure shake gesture and programmatic trigger only; no persistent floating buttons cluttering the host app UI.
- Route presentation: Fullscreen `MaterialPageRoute(fullscreenDialog: true)` guarded by `NetworkInspector.isOpen` reentrancy check, resetting to `false` when route pops.

### the agent's Discretion
- Exact internal class structure for `ShakeDetector` (e.g., event stream listener vs periodic tick accumulator).
- Method signature for setting up navigator key fallback inside `NetworkInspectorWrapper`.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `NetworkInspector.open(BuildContext context)`: Already has reentrancy guard (`_isOpen`), `MaterialPageRoute` push, and `_currentConfig.navigatorKey` support.
- `NetworkInspectorConfig`: Already contains `navigatorKey` and `enableShakeDetection` flag; ready to accept `shakeThreshold` and `shakeDebounceMs`.
- `NetworkInspectorScreen`: Inspector root UI already implemented, verified, and exported.

### Established Patterns
- Facade singleton pattern in `NetworkInspector` with `resetForTesting()` and static accessor methods.
- Immutable config objects with `copyWith` and fallback evaluation (`_enabled ?? !kReleaseMode`).
- Comprehensive unit and widget testing with headless verification.

### Integration Points
- `NetworkInspector.initialize`: Hook `ShakeDetector` start when `config.enableShakeDetection` is true.
- `NetworkInspector.dispose` / `resetForTesting`: Hook `ShakeDetector.stop()` / `dispose()`.
- `lib/flutter_network_inspector.dart`: Export `NetworkInspectorWrapper` and `ShakeDetector`.

</code_context>

<specifics>
## Specific Ideas

- Ensure `userAccelerometerEventStream()` is not imported or invoked in pure Dart unit tests without a mockable stream or platform channel handler. Provide an injectable or mockable stream factory for `ShakeDetector` tests.
- Support both `child` widget and `builder` pattern in `NetworkInspectorWrapper`.

</specifics>

<deferred>
## Deferred Ideas

- Draggable floating overlay bubble trigger (deferred to v1.2.0 per REQUIREMENTS.md FLOAT-01).

</deferred>
