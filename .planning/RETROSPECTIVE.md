# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — Initial Release

**Shipped:** 2026-11-03  
**Phases:** 6 | **Plans:** 17 | **Commits:** 66+

### What Was Built
- **Core Domain & Redaction**: Immutable Dart 3 network transaction models, memory-bounded payload truncator (1MB limit), and recursive credential redaction engine.
- **SQLite Storage**: Asynchronous WAL-mode SQLite repository with write buffer debouncing and FIFO threshold pruning.
- **Capture Interceptors**: Transparent `dart:io` `HttpOverrides` chaining with non-destructive stream tap transformers, dedicated `Dio` interceptor, and `package:http` client adapter with deduplication.
- **Material 3 Inspector UI**: Dark-themed in-app inspector screen with real-time multi-parameter search, compound filtering, 4-tab request detail inspector, background isolate JSON viewer, copy actions, cURL generator, and native share sheet export.
- **Developer Experience**: Accelerometer shake detection via `sensors_plus` with gravity isolation, `NetworkInspectorWrapper`, singleton `NetworkInspector.navigatorKey`, and Android 16 edge-to-edge + 16KB page size alignment.
- **Quality & Example**: 210 passing automated unit/integration/widget tests, complete documentation, and an interactive example application.

### What Worked
- SQLite in-memory FFI for headless desktop and CI testing (`sqflite_common_ffi`) eliminated flaky mocks and allowed real SQL schema testing.
- Dual-forwarding stream transformer ensured zero single-subscription stream draining when intercepting network calls.
- Synthetic tracking headers prevented duplicate recording across nested interceptors.
- Singleton `NetworkInspector.navigatorKey` solved ancestor context issues with shake-to-open.

### What Was Inefficient
- Post-implementation file edits invalidated verification digests, requiring a full re-verification pass across all 6 phases.
- Theme propagation required explicit theme injection to modal bottom sheets and dialogs due to Flutter root Navigator routing.

### Patterns Established
- Hand-crafted immutable Dart 3 records and sealed classes instead of code generation (`build_runner`).
- Dedicated client adapters (`DioInterceptor`, `HttpClientAdapter`) as first-class citizens alongside `HttpOverrides`.
- Dynamic safe insets via `MediaQuery.viewPaddingOf(context).bottom` for Android 16 navigation bars.

### Key Lessons
1. Always expose a default `GlobalKey<NavigatorState>` so developers can integrate shake detection with one line without encountering ancestor context traps.
2. Uncompressed 16KB ELF alignment (`packaging.jniLibs.useLegacyPackaging = false`) is required for Android 15/16 modern targets.

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Commits | Phases | Plans | Key Change |
|-----------|---------|--------|-------|------------|
| v1.0 | 66+ | 6 | 17 | Initial full bottom-up architecture and package release |

### Cumulative Quality

| Milestone | Tests | Analysis Issues | Zero-Dep Core |
|-----------|-------|-----------------|---------------|
| v1.0 | 210 | 0 | Yes (pure Dart models) |

### Top Lessons (Verified Across Milestones)

1. Zero UI thread blocking via asynchronous SQLite WAL writes and compute isolates for large JSON parsing ensures fluid app performance.
