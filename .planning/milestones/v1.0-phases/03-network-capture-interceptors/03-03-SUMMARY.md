---
phase: 03-network-capture-interceptors
plan: 03
subsystem: logging
tags:
  - manual-logging
  - request-tracker
  - error-interception
  - partial-buffer
  - release-guard
  - no-op
dependency_graph:
  requires:
    - 03-01 # InspectorHttpClientRequest, InspectorHttpClientResponse, NetworkInspectorConfig
    - 03-02 # Client adapters (Dio, http), deduplication header protocol
    - 01-01 # NetworkRecord, PayloadData, BodyType, MultipartEntry, HttpErrorDetails
    - 01-02 # RedactionEngine, PayloadTruncator
    - 02-01 # NetworkInspectorRepository
  provides:
    - INTC-07 # Socket failure, timeout, and abort capture with partial buffer retention
    - LOG-01 # Public static manual logging facade (logApi, startRequest, logError)
    - LOG-02 # Flexible Object? payload support (Map, List, String, Uint8List, Multipart)
  affects:
    - Phase 04 # In-App UI inspector (consumes manually logged and intercepted records)
tech_stack:
  added: []
  patterns:
    - Two-phase in-flight request tracking handle (NetworkRequestTracker, D-45)
    - Const zero-allocation release/disabled no-op tracker (NoOpNetworkRequestTracker, D-48)
    - Object? input normalization pipeline (BodyTypeDetector + RedactionEngine + PayloadTruncator)
    - Standalone and linked error logging with HttpErrorDetails and status code capture (D-47)
    - Partial response body retention on socket reset and abort (D-44)
key_files:
  created:
    - lib/src/logging/network_request_tracker.dart
    - lib/src/logging/network_request_tracker_impl.dart
    - lib/src/logging/no_op_network_request_tracker.dart
    - lib/src/logging/manual_logger.dart
    - test/interceptor/error_interception_test.dart
    - test/logging/manual_logging_test.dart
    - test/logging/manual_logging_parameters_test.dart
  modified:
    - lib/flutter_network_inspector.dart
    - lib/src/core/network_inspector.dart
    - lib/src/interceptor/io/inspector_http_client_request.dart
    - lib/src/interceptor/io/inspector_http_client_response.dart
decisions:
  - "InspectorHttpClientRequest captures request.abort() with duration and HttpErrorDetails before delegating (INTC-07, D-44)"
  - "InspectorHttpClientResponse retains partial response bodies and status codes upon mid-stream failure, forwarding errors downstream (INTC-07, D-44)"
  - "NetworkInspector.startRequest returns a two-phase NetworkRequestTracker handle recording pending status and updating on completion (D-45, LOG-01)"
  - "NetworkInspector.logApi records completed or failed calls in a one-shot facade (D-45, LOG-01)"
  - "ManualLogger processes Map, List, String, and Uint8List through RedactionEngine and PayloadTruncator without raw byte bloat (D-46, LOG-02)"
  - "NetworkInspector.logError updates existing transactions when id is supplied and creates standalone failed records when id is null (D-47)"
  - "NoOpNetworkRequestTracker provides a const zero-allocation implementation when inspection is disabled or in release mode (D-48)"
  - "Public barrel export lib/flutter_network_inspector.dart exposes NetworkRequestTracker and NoOpNetworkRequestTracker"
metrics:
  duration: 22m
  completed_date: "2026-11-01"
status: complete
actuals:
  tokens: 14584
  tasks: 3
  commits: 3
  plan_head_before: 9c5ae9a8980073cba0842013b04671fc278bff8c
  plan_head_after: 17150eecfff5d7808e036e32e724c921be0ae996
---

# Phase 03 Plan 03: Error / Abort Diagnostics & Manual Logging Facade Summary

Robust error, timeout, and abort diagnostics with partial buffer retention, high-ergonomics developer manual logging APIs (`NetworkInspector.logApi`, `NetworkInspector.startRequest`, `NetworkInspector.logError`), two-phase request tracking, and zero-allocation release protection.

## What Was Built

1. **Error, Timeout, and Abort Diagnostics with Partial Buffer Retention (INTC-07, D-44):**
   - **Request Abort & Timeout Trapping:** Updated `InspectorHttpClientRequest` to intercept explicit `request.abort(...)` calls and `_inner.close()` connection failures, calculating elapsed duration and recording `NetworkStatus.failed` transactions with `HttpErrorDetails` (error type, message, stack trace) before rethrowing.
   - **Mid-Stream Partial Response Retention:** Enhanced `InspectorHttpClientResponse._onResponseError` to retain any partial response body buffered up to the failure point, formatting text/JSON payloads via `RedactionEngine` and `PayloadTruncator` or generating binary metadata summaries (`[Binary data: <mime>, <bytes>]`) for binary streams.
   - **Stream Error Forwarding:** Ensured `StreamTapTransformer` immediately forwards errors downstream via `sink.addError(error, stackTrace)` without swallowing exceptions.
   - **Deduplication Error Guard:** Validated that low-level `dart:io` error logging is suppressed when synthetic tracking headers (`x-network-inspector-id`) are present.

2. **Two-Phase Manual Request Tracking (LOG-01, D-45, D-48):**
   - **`NetworkRequestTracker` Interface:** Declared contract exposing `String get id`, `onResponse({required int statusCode, ...})`, and `onError({required Object error, ...})`.
   - **`NetworkRequestTrackerImpl`:** Records an initial `NetworkRecord` with `NetworkStatus.pending` upon initiation, tracks start time, and asynchronously updates the transaction with `NetworkStatus.success` on `onResponse` or `NetworkStatus.failed` on `onError`, measuring exact duration in milliseconds.
   - **`NoOpNetworkRequestTracker`:** Implemented as a `const` zero-allocation class returned when `NetworkInspector.isEnabled` is false or during production release mode per D-48.

3. **Flexible Manual Logging Facade (LOG-01, LOG-02, D-45, D-46, D-47):**
   - **`NetworkInspector.logApi`:** One-shot static facade recording completed or failed network calls with optional headers, bodies, duration, timestamps, and error details.
   - **`NetworkInspector.logError`:** Dual-mode error logger: updates an existing transaction with `HttpErrorDetails` and optional response body/headers when `id` is provided (linked mode), or creates a fresh standalone `failed` record with UUID v4 when `id` is omitted (standalone mode).
   - **Flexible `Object?` Body Preprocessing:** Handled `Map` and `List` (JSON serialization + recursive key redaction), `String` (text/json redaction + truncation), `Uint8List` (binary summary metadata banner + zero raw byte persistence per D-43), and `MultipartEntry` collections (DATA-04).
   - **Public Barrel Exports:** Exposed `NetworkRequestTracker` and `NoOpNetworkRequestTracker` in `lib/flutter_network_inspector.dart`.

## Verification Evidence

Automated tests passing:
- `test/interceptor/error_interception_test.dart` (5/5 passed): Verifies socket connection failures to unrouted ports, `request.abort()` capture, mid-stream response resets with partial body retention, binary mid-stream error summaries, and deduplication error suppression.
- `test/logging/manual_logging_test.dart` (5/5 passed): Verifies `startRequest` pending-to-success lifecycle, `onError` failure transitions with `HttpErrorDetails`, `logApi` one-shot recording, `logApi` with error parameter, and zero-allocation disabled no-op mode.
- `test/logging/manual_logging_parameters_test.dart` (7/7 passed): Verifies Map JSON encoding & redaction, List JSON array handling, Uint8List binary metadata formatting, raw String truncation at `maxBodyBytes`, `MultipartEntry` metadata extraction, standalone `logError`, and linked `logError` update without duplication.
- Full regression suite: 147/147 tests passing across the entire package.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected repository lookup method in manual logger and tests**
- **Found during:** Task 2
- **Issue:** Initial draft called non-existent `getRecordById` on `NetworkInspectorRepository`.
- **Fix:** Switched to existing domain repository contract `getById(id)`.
- **Files modified:** `lib/src/logging/manual_logger.dart`, `test/logging/manual_logging_test.dart`
- **Commit:** `3485fe9`

**2. [Rule 1 - Bug] Corrected MultipartEntry parameter names in test**
- **Found during:** Task 3
- **Issue:** Test used `length:` and `isText:` which do not exist on `MultipartEntry` (it uses `byteSize:`).
- **Fix:** Updated test instantiation to use `byteSize:` and removed non-existent parameters.
- **Files modified:** `test/logging/manual_logging_parameters_test.dart`
- **Commit:** `17150ee`

## Known Stubs

None. All interceptors, manual logging APIs, trackers, and serializers are fully wired and functional.

## Threat Flags

None. Threat mitigations from STRIDE register T-03-07 (`logError` sanitization and redaction), T-03-08 (`logApi` recursive redaction of Object? bodies), and T-03-09 (memory bounding via `PayloadTruncator` and const no-op tracker) were implemented and verified.

## Self-Check: PASSED

1. Created files exist:
   - `lib/src/logging/network_request_tracker.dart` (FOUND)
   - `lib/src/logging/network_request_tracker_impl.dart` (FOUND)
   - `lib/src/logging/no_op_network_request_tracker.dart` (FOUND)
   - `lib/src/logging/manual_logger.dart` (FOUND)
   - `test/interceptor/error_interception_test.dart` (FOUND)
   - `test/logging/manual_logging_test.dart` (FOUND)
   - `test/logging/manual_logging_parameters_test.dart` (FOUND)

2. Commits exist:
   - `8830a96` (FOUND)
   - `3485fe9` (FOUND)
   - `17150ee` (FOUND)
