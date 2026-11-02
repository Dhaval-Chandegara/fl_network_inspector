# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-11-02

### Added
- **Core Architecture & Foundation**:
  - `NetworkInspector` facade singleton with thread-safe lifecycle control (`initialize`, `open`, `flush`, `dispose`).
  - Immutable domain models: `NetworkRecord`, `PayloadData`, `MultipartEntry`, `HttpErrorDetails`, and `RecordFilter`.
  - Configurable `NetworkInspectorConfig` with release mode safety guard (compiles to no-op in `kReleaseMode` unless `enabled: true` explicitly forced).
  - Sensitive header and body field redaction engine (`Authorization`, `Cookie`, `apiKey`, `password`, `token`, etc.) with customizable rules.
  - Safe payload truncation with configurable 1MB default limits and `[Body truncated at 1MB]` warnings to eliminate Out-Of-Memory crashes.
- **Embedded SQLite Storage**:
  - `SqliteNetworkInspectorRepository` utilizing native `sqflite` on iOS/Android/macOS and `sqflite_common_ffi` on desktop/tests.
  - Non-blocking batch write buffer queue (`WriteBufferQueue`) with micro-task debounce and auto-flush on queries.
  - Sub-millisecond indexed SQL filtering across URL, endpoint, HTTP method, status code, duration, and date ranges.
  - Automatic database migrations and LRU/FIFO record pruning preserving the newest configured capacity (`maxRecords`).
  - `InMemoryNetworkInspectorRepository` fallback for Flutter Web and test environments.
- **Transparent Network Capture & Interceptors**:
  - Global `HttpOverrides` chaining (`NetworkInspectorHttpOverrides`) capturing `dart:io` `HttpClient` traffic without breaking host app proxies or SSL configurations.
  - Dedicated `NetworkInspectorDioInterceptor` adapter for Dio 5.x apps.
  - Dedicated `NetworkInspectorHttpClient` adapter for `package:http` apps.
  - Non-destructive single-subscription stream tapping (`StreamTapTransformer`) preventing "Stream has already been listened to" runtime errors.
  - Synthetic tracking headers (`x-fl-net-inspector-tracked-id`) for zero-duplicate logging across nested interceptors.
  - Multipart upload metadata capture (file name, parameter, MIME type, byte size) omitting raw file binaries to prevent disk bloat.
  - Two-phase manual request tracker (`NetworkInspector.startRequest`) and one-shot manual logger (`NetworkInspector.logApi`).
- **In-App Inspector UI**:
  - Material 3 listing screen with HTTP method badges, status code indicators, durations, timestamps, and payload sizes.
  - Real-time debounced search (300ms) and multi-parameter filter sheet (methods, status codes, errors-only, duration bounds, date ranges).
  - 4-tab details screen: Overview, Request, Response, and Error with Header Summary Card.
  - Syntax-highlighted JSON viewer with 2-space indentation, Raw/Pretty mode toggle, and isolate-based formatting for payloads > 50KB.
  - 48px touch-target clipboard copy buttons with confirmation SnackBars.
  - Terminal-executable cURL command generator with line continuations and safe bash quote escaping.
  - Native multi-format share sheet export (Markdown, cURL, JSON) with iPadOS `RenderBox` anchor origin crash protection.
  - In-app Theme toggle (Light / Dark / System).
- **Shake Gesture & Developer Experience**:
  - Hardware accelerometer shake detection via `sensors_plus` isolating dynamic user motion by subtracting static gravity (`userAccelerometerEventStream()`).
  - Automatic battery optimization: pauses sensor sampling on app backgrounding and resumes on foregrounding via `WidgetsBindingObserver`.
  - Configurable shake sensitivity threshold (default 15.0 m/s²) and debounce cooldown (default 1500ms).
  - Transparent `NetworkInspectorWrapper` root widget with zero layout side effects.
  - Programmatic `NetworkInspector.open([BuildContext? context])` with navigator key resolution cascade and reentrancy guard.
- **Example App & Multi-Tier Testing**:
  - Interactive reference example app in `example/`.
  - 100% automated test pass rate across 207 unit, integration, and widget tests.
