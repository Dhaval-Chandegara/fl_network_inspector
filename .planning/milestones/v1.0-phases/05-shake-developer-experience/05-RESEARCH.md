# Phase 05: Shake & Developer Experience - Research

## Executive Summary

Phase 5 introduces frictionless invocation triggers and ergonomic integration wrappers for consumer Flutter applications:
1. **Accelerometer Shake Detection (`sensors_plus: ^7.1.1`):** Subscribes to `userAccelerometerEventStream()`, which mathematically isolates dynamic user motion by subtracting the 9.8 m/s² gravity vector at the platform layer. Computes Euclidean vector magnitude (`sqrt(x*x + y*y + z*z)`) against configurable threshold (`15.0 m/s²`) and enforces a 1500ms debounce cooldown to eliminate false-positive triggers and rebound oscillations.
2. **Lifecycle-Aware Battery Protection:** Implements `WidgetsBindingObserver` to pause sensor event subscriptions (`_subscription.pause()`) when the application transitions to background states (`paused`, `inactive`, `hidden`), and resumes sampling (`_subscription.resume()`) when the app returns to `resumed`.
3. **Platform Graceful Degradation:** Safely catches `MissingPluginException`, platform channel errors, or unsupported device configurations (desktop OSes, web browsers, simulator without sensor mock), ensuring zero crashes or unhandled exceptions.
4. **Ergonomic Root Wrapper (`NetworkInspectorWrapper`):** Provides a clean root widget wrapper (`child` widget) that automatically attaches shake detection and lifecycle observation with zero configuration boilerplate, and captures the root `NavigatorState` for contextless programmatic opening (`NetworkInspector.open()`).

---

## Technical Stack & API Findings

### 1. `sensors_plus: ^7.1.1`

- **Stream Selection:** Always use `userAccelerometerEventStream()`, NEVER `accelerometerEventStream()`.
  - `accelerometerEventStream()` includes the constant 9.8 m/s² gravity vector. When the device is laid flat on a desk, tilted in the hand, or picked up gently, the gravity vector shifts across axes, causing spurious shake triggers.
  - `userAccelerometerEventStream()` isolates pure dynamic motion (`UserAccelerometerEvent(double x, double y, double z)`). In static resting state, all components are ~0.0 m/s².
- **Sampling Period:** Default `SensorInterval.normalInterval` or `SensorInterval.uiInterval` (~100–200ms) provides more than enough temporal resolution to capture human shake gestures without consuming excessive CPU or battery.
- **Mockable Architecture for Unit Testing:**
  - `sensors_plus` platform channels are unavailable in headless unit tests (`flutter test`).
  - `ShakeDetector` must accept an optional `Stream<UserAccelerometerEvent>? stream` parameter (or `StreamFactory`) so tests can drive synthetic motion events with 100% deterministic assertion without mocking platform binaries.

### 2. Gesture Mathematics & Thresholds

- **Euclidean Vector Magnitude:**
  $$\text{magnitude} = \sqrt{x^2 + y^2 + z^2}$$
- **Threshold Calibration:**
  - Normal phone handling / walking: $\approx 2.0 - 6.0 \text{ m/s}^2$.
  - Intentional vigorous shake gesture: $\ge 12.0 - 20.0 \text{ m/s}^2$.
  - Recommended default threshold: `15.0 m/s²` (configured via `NetworkInspectorConfig.shakeThreshold`).
- **Debounce / Cooldown Window:**
  - Physical shaking consists of rapid back-and-forth oscillations lasting 200–800ms. Without debouncing, a single human shake will fire 4–10 consecutive events.
  - Cooldown timer: `1500 ms` (`shakeDebounceMs: 1500`). When a shake event crosses the threshold, trigger the callback once and ignore all subsequent sensor events until 1500ms has elapsed.

### 3. Application Lifecycle Management (`WidgetsBindingObserver`)

- **State Transitions:**
  - `AppLifecycleState.resumed`: App is active and visible in foreground $\rightarrow$ Resume accelerometer sampling (`_subscription.resume()`).
  - `AppLifecycleState.inactive`: Incoming phone call, notification shade pulled down, or multi-window app switcher $\rightarrow$ Pause accelerometer sampling (`_subscription.pause()`).
  - `AppLifecycleState.paused`: App is backgrounded $\rightarrow$ Pause accelerometer sampling.
  - `AppLifecycleState.hidden`: App is obscured or in background $\rightarrow$ Pause accelerometer sampling.
- **Resource Cleanup:**
  - Unregister `WidgetsBinding.instance.removeObserver(this)` in `dispose()` to prevent memory leaks and dangling listeners.

### 4. Root Wrapper & Programmatic Navigation

- **`NetworkInspectorWrapper`:**
  - `StatefulWidget` wrapping `Widget child`.
  - Manages `ShakeDetector` lifecycle: starts when `NetworkInspector.isEnabled && NetworkInspector.currentConfig.enableShakeDetection`, pauses/resumes across app lifecycle states, and disposes cleanly.
  - Automatically captures the root navigator context or `navigatorKey` if provided.
- **Contextless Programmatic Opening (`NetworkInspector.open([BuildContext? context])`):**
  - If `context` is passed: use `Navigator.of(context, rootNavigator: true)`.
  - If `context` is omitted: resolve `_currentConfig.navigatorKey?.currentState` or `NetworkInspectorWrapper.navigatorKey?.currentState`.
  - If neither is available and context is omitted: log a clear developer warning notice in debug mode.

---

## Known Pitfalls & Mitigations

| Pitfall | Consequence | Mitigation |
|---------|-------------|------------|
| Raw accelerometer instead of user accelerometer | Device tilt or desk placement triggers spurious shake events | Use `userAccelerometerEventStream()`, which mathematically isolates dynamic motion from gravity |
| Continuous background sensor polling | Severe battery drain when phone is in user's pocket or screen is off | Implement `WidgetsBindingObserver` to pause stream on `paused`/`inactive`/`hidden` |
| Route stacking from rapid shaking | Multiple `NetworkInspectorScreen` instances pushed onto Navigator stack | Enforce `NetworkInspector.isOpen` reentrancy guard and 1500ms debounce cooldown |
| Desktop / Web platform crash | `MissingPluginException` thrown on macOS/Windows/Linux/Web | Catch stream errors gracefully, log single debug note, and fallback to no-op |
| Release build overhead | Sensor channels active in production release builds | When `config.enabled` is false, `ShakeDetector` and `NetworkInspectorWrapper` compile to no-ops |
