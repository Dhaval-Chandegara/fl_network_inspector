---
phase: 03-network-capture-interceptors
plan: 01
subsystem: interceptor
tags:
  - dart:io
  - http_overrides
  - stream_tap
  - proxy
  - blacklisting
  - sse
dependency_graph:
  requires:
    - 01-01 # NetworkRecord, PayloadData, BodyType
    - 01-02 # RedactionEngine, PayloadTruncator
    - 02-01 # NetworkInspectorRepository
  provides:
    - INTC-01 # dart:io transparent capture via HttpOverrides
    - INTC-02 # Safe HttpOverrides chaining
    - INTC-03 # Non-destructive StreamTapTransformer
  affects:
    - 03-02 # Dio and package:http client adapters (relies on HttpOverrides deduplication)
    - 03-03 # Manual logging API
tech_stack:
  added: []
  patterns:
    - StreamTransformer.fromHandlers for non-destructive response stream tapping (D-41)
    - Two-way transparent proxying in InspectorHttpClient / Request / Response (D-39)
    - HttpOverrides chaining delegating client creation and proxy lookup to previous overrides (D-38)
    - Web-safe conditional exports with no-op platform stubs
    - Early URL/host blacklisting and binary stream bypass (D-36, D-43)
key_files:
  created:
    - lib/src/interceptor/stream/stream_tap_transformer.dart
    - lib/src/interceptor/io/http_overrides_manager.dart
    - lib/src/interceptor/io/inspector_http_client.dart
    - lib/src/interceptor/io/inspector_http_client_request.dart
    - lib/src/interceptor/io/inspector_http_client_response.dart
    - lib/src/interceptor/platform/http_capture_platform.dart
    - lib/src/interceptor/platform/http_capture_stub.dart
    - lib/src/interceptor/platform/http_capture_io.dart
    - test/interceptor/stream_tap_transformer_test.dart
    - test/interceptor/http_client_interceptor_test.dart
    - test/interceptor/http_overrides_chaining_test.dart
  modified:
    - lib/src/config/network_inspector_config.dart
    - lib/src/core/constants.dart
    - lib/src/core/network_inspector.dart
    - test/config/network_inspector_config_test.dart
    - test/core/platform_safety_test.dart
decisions:
  - "StreamTapTransformer forwards byte chunks downstream synchronously while accumulating a bounded copy up to maxBodyBytes (D-41)"
  - "InspectorHttpOverrides delegates createHttpClient and findProxyFromEnvironment to previous HttpOverrides.current (D-38)"
  - "InspectorHttpClient captures connection and socket errors occurring during openUrl as well as close() (INTC-07, D-44)"
  - "Binary MIME streams bypass memory buffers, recording summary metadata directly (D-43)"
  - "SSE text/event-stream responses persist initial headers and status code immediately without blocking on stream termination (D-42)"
metrics:
  duration: 18m
  completed_date: "2026-11-01"
status: complete
actuals:
  tokens: 16876
  tasks: 3
  commits: 3
  plan_head_before: 0f379922bf71f5a0db12f001728594823c34e757
  plan_head_after: 33d6c37ddef7789a59a5783ba4d2313a6677a7ea
---

# Phase 03 Plan 01: Transparent dart:io Capture & Stream Tapping Summary

Transparent HTTP/HTTPS network capture and non-destructive stream tapping for standard `dart:io` networking with safe `HttpOverrides` parent chaining and Web-safe platform conditional exports.

## What Was Built

1. **Non-Destructive Stream Tap Transformer (`StreamTapTransformer`):**
   - Implemented via `StreamTransformer<List<int>, List<int>>.fromHandlers` per INTC-03, D-41, and D-43.
   - Synchronously forwards incoming byte chunks downstream to the host application listener (`sink.add(chunk)`) with zero added latency or backpressure disruption.
   - Concurrently accumulates a copy into a `BytesBuilder` up to `maxBodyBytes`, safely marking `isTruncated = true` when exceeded.
   - Bypasses raw memory accumulation entirely when `isBinary: true`, accumulating only total byte count and formatting metadata summaries (`[Binary data: <mime_type>, <bytes>]`).

2. **Transparent dart:io Proxy Wrappers:**
   - `InspectorHttpClient`: Implements `HttpClient` and forwards all configuration getters and setters (`idleTimeout`, `connectionTimeout`, `userAgent`, `badCertificateCallback`, proxy authenticators) to `_inner` per D-39. Captures early connection failures in `openUrl` (DNS, connection refused) to record `NetworkStatus.failed` transactions per D-44.
   - `InspectorHttpClientRequest`: Implements `HttpClientRequest`, buffers outgoing request body bytes up to `maxBodyBytes`, generates UUID v4 transaction IDs, extracts request headers and query parameters, and persists pending records to repository. Detects synthetic deduplication headers (`x-network-inspector-id`) and strips them before wire transmission (INTC-06, D-33).
   - `InspectorHttpClientResponse`: Extends `StreamView<List<int>>` and implements `HttpClientResponse`, tapping response stream chunks via `createStreamTapTransformer`. Formats sanitized response payloads, calculates round-trip duration, and saves completed `NetworkRecord` items to `NetworkInspector.repository`. Supports progressive SSE recording (`text/event-stream`) by immediately capturing initial status code and headers per D-42.

3. **Safe HttpOverrides Chaining & Lifecycle:**
   - `InspectorHttpOverrides`: Captures `previousOverrides = HttpOverrides.current` and delegates client creation and proxy discovery to previous overrides (INTC-01, INTC-02, D-38).
   - Platform conditional bridge (`http_capture_platform.dart`): Routes to `http_capture_io.dart` on VM runtimes and no-op stubs in `http_capture_stub.dart` on Web.
   - `NetworkInspector` facade lifecycle: Added `startAutoCapture()`, `stopAutoCapture()`, and `runZoned()` for zone-scoped overrides (D-37, D-40).

4. **URL & Host Blacklisting:**
   - Added `ignoredHosts` and `ignoredUrls` configuration options to `NetworkInspectorConfig` (D-36).
   - Early bypass in `InspectorHttpClient` and `InspectorHttpClientRequest` suppresses record persistence and buffer allocation for matched hostnames and URL patterns.

## Verification Evidence

Automated tests passing:
- `test/interceptor/stream_tap_transformer_test.dart` (4/4 passed): Verifies synchronous chunk forwarding, truncation at `maxBodyBytes`, error handling, and binary stream bypass.
- `test/interceptor/http_client_interceptor_test.dart` (7/7 passed): Verifies real loopback `HttpServer` GET/POST interception, single-subscription stream consumption without `Bad state: Stream has already been listened to`, connection failure recording, disabled state no-op, blacklist bypass, binary summary recording, and SSE immediate header persistence.
- `test/interceptor/http_overrides_chaining_test.dart` (4/4 passed): Verifies parent delegation for `createHttpClient` and `findProxyFromEnvironment`, global lifecycle restoration on `stopAutoCapture()` and `dispose()`, and zone-scoped execution via `runZoned()`.
- `test/config/network_inspector_config_test.dart` (7/7 passed): Verifies default config values, `copyWith`, equality, and hash codes with `ignoredHosts` and `ignoredUrls`.
- `test/core/platform_safety_test.dart` (1/1 passed): Verifies zero `dart:io` imports across foundational layers.
- Full test suite: 110/110 tests passing across the package.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Updated test/core/platform_safety_test.dart for isolated IO interceptors**
- **Found during:** Task 1
- **Issue:** `platform_safety_test.dart` scanned all files under `lib/src/` for `import 'dart:io'`, failing on the newly introduced VM-only interceptor files in `lib/src/interceptor/io/` and `http_capture_io.dart`.
- **Fix:** Added path exemption for `lib/src/interceptor/io/` and `lib/src/interceptor/platform/http_capture_io.dart` (which are guarded behind conditional platform exports per CORE-03) while maintaining strict zero `dart:io` enforcement across models, config, core, storage, and utils.
- **Files modified:** `test/core/platform_safety_test.dart`
- **Commit:** `13afe6c`

**2. [Rule 2 - Auto-add missing critical functionality] Connection error capture in InspectorHttpClient.openUrl**
- **Found during:** Task 1
- **Issue:** Socket connection failures occurring during `openUrl` (connection refused, DNS failure) threw before `InspectorHttpClientRequest` was returned, missing failure recording.
- **Fix:** Added try/catch in `InspectorHttpClient.openUrl` capturing `SocketException` and saving a `NetworkStatus.failed` record before rethrowing per INTC-07 and D-44.
- **Files modified:** `lib/src/interceptor/io/inspector_http_client.dart`
- **Commit:** `13afe6c`

**3. [Rule 1 - Bug] StreamTapTransformer callback execution order**
- **Found during:** Task 1
- **Issue:** `onComplete` in `handleDone` was invoked after `sink.close()`, which in some stream listeners caused downstream consumption to complete before callbacks updated inspector state.
- **Fix:** Reordered `handleDone` and `handleError` to invoke `onComplete` and `onError` before `sink.close()` and `sink.addError()`.
- **Files modified:** `lib/src/interceptor/stream/stream_tap_transformer.dart`
- **Commit:** `13afe6c`

## Known Stubs

None. All interceptors, proxies, transformers, and configurations are fully wired and functional.

## Threat Flags

None. Threat mitigations from STRIDE register T-03-01 (redaction before save), T-03-02 (bounded body bytes and binary bypass), and T-03-03 (parent override preservation and clean restoration) were implemented and verified.

## Self-Check: PASSED

1. Created files exist:
   - `lib/src/interceptor/stream/stream_tap_transformer.dart` (FOUND)
   - `lib/src/interceptor/io/http_overrides_manager.dart` (FOUND)
   - `lib/src/interceptor/io/inspector_http_client.dart` (FOUND)
   - `lib/src/interceptor/io/inspector_http_client_request.dart` (FOUND)
   - `lib/src/interceptor/io/inspector_http_client_response.dart` (FOUND)
   - `lib/src/interceptor/platform/http_capture_platform.dart` (FOUND)
   - `lib/src/interceptor/platform/http_capture_stub.dart` (FOUND)
   - `lib/src/interceptor/platform/http_capture_io.dart` (FOUND)
   - `test/interceptor/stream_tap_transformer_test.dart` (FOUND)
   - `test/interceptor/http_client_interceptor_test.dart` (FOUND)
   - `test/interceptor/http_overrides_chaining_test.dart` (FOUND)

2. Commits exist:
   - `13afe6c` (FOUND)
   - `cc0d25c` (FOUND)
   - `33d6c37` (FOUND)
