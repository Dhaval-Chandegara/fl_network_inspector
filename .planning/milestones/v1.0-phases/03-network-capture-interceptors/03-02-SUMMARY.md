---
phase: 03-network-capture-interceptors
plan: 02
subsystem: interceptor
tags:
  - dio
  - package:http
  - deduplication
  - wire-stripping
  - multipart
  - stream-tap
dependency_graph:
  requires:
    - 03-01 # InspectorHttpClientRequest, StreamTapTransformer, NetworkInspectorConfig
    - 01-01 # NetworkRecord, PayloadData, BodyType, MultipartEntry
    - 01-02 # RedactionEngine, PayloadTruncator
  provides:
    - INTC-04 # Dedicated Dio 5.x client adapter
    - INTC-05 # Dedicated package:http client adapter
    - INTC-06 # Cross-interceptor deduplication protocol and wire header stripping
  affects:
    - 03-03 # Error interception and manual logging API
tech_stack:
  added:
    - dio: ">=5.0.0 <6.0.0" (5.11.1)
    - http: ">=1.0.0 <2.0.0" (1.6.0)
  patterns:
    - Cross-interceptor synthetic tracking header protocol (x-network-inspector-id, D-33)
    - Wire header stripping in InspectorHttpClientRequest before socket dispatch (INTC-06, D-33)
    - Nested / repeated interceptor registration guard via request metadata (D-34)
    - Fresh transaction IDs for retried requests (D-35)
    - Non-destructive StreamTapTransformer proxying for http.BaseClient (INTC-03, D-41)
    - Pure Dart / Web-safe adapter implementations with zero dart:io dependencies
    - Multipart metadata extraction without raw binary storage (DATA-04)
key_files:
  created:
    - lib/src/interceptor/dio/network_inspector_dio_interceptor.dart
    - lib/src/interceptor/http/network_inspector_http_client.dart
    - test/interceptor/deduplication_test.dart
    - test/interceptor/dio_interceptor_test.dart
    - test/interceptor/http_client_adapter_test.dart
  modified:
    - lib/flutter_network_inspector.dart
    - lib/src/interceptor/io/inspector_http_client_request.dart
    - pubspec.yaml
    - pubspec.lock
decisions:
  - "Client adapters inject synthetic UUID tracking headers (x-network-inspector-id) to suppress duplicate capture in low-level HttpOverrides (D-33)"
  - "InspectorHttpClientRequest performs case-insensitive detection and strips tracking headers before wire dispatch (INTC-06, D-33)"
  - "RequestOptions.extra and request headers guard against repeat or nested client registrations (D-34)"
  - "Retried requests reset the captured flag so subsequent attempts generate fresh transaction IDs (D-35)"
  - "Dio FormData and package:http MultipartRequest record MultipartEntry items for fields and files while discarding raw binary bytes (DATA-04)"
  - "NetworkInspectorHttpClient transparently wraps response streams using createStreamTapTransformer, preserving single-subscription consumption (INTC-03, D-41)"
metrics:
  duration: 12m
  completed_date: "2026-11-01"
status: complete
actuals:
  tokens: 15214
  tasks: 3
  commits: 3
  plan_head_before: 14c816d17c99042fc8a2d9dcf4de75bbe3565eae
  plan_head_after: 114f614041b6567eecf2b90623d6a911a3df3f33
---

# Phase 03 Plan 02: Client Adapters & Cross-Interceptor Deduplication Summary

Dedicated client adapters for `Dio` (5.x) and `package:http` (1.x) with cross-interceptor deduplication, wire header stripping, non-destructive response stream tapping, and multipart metadata extraction.

## What Was Built

1. **Cross-Interceptor Deduplication & Wire Stripping Protocol:**
   - Client adapters (`NetworkInspectorDioInterceptor` and `NetworkInspectorHttpClient`) inject synthetic correlation tracking headers (`x-network-inspector-id` and `x-fl-net-inspector-tracked-id`) with UUID v4 transaction IDs (INTC-06, D-33).
   - `InspectorHttpClientRequest` detects these synthetic tracking headers in a case-insensitive manner in `close()`, strips them from `_inner.headers` before invoking the underlying client close, ensuring remote APIs never receive the tracking headers over the wire.
   - When the tracking header is detected, `InspectorHttpClientRequest` sets `_isSuppressed = true`, returning the raw `HttpClientResponse` and skipping pending/completed/failed record persistence in the repository so low-level `HttpOverrides` does not create duplicate entries for requests already captured by client adapters.

2. **Dedicated Dio 5.x Client Adapter (`NetworkInspectorDioInterceptor`):**
   - Implemented `NetworkInspectorDioInterceptor` extending `package:dio`'s `Interceptor` (INTC-04).
   - Guards all hooks (`onRequest`, `onResponse`, `onError`) with `NetworkInspector.isEnabled`.
   - Protects against duplicate capture from nested or repeated interceptor registrations on the same `Dio` instance using `options.extra['__fl_net_inspector_captured']` (D-34).
   - Evaluates URL/host blacklist against `ignoredHosts` and `ignoredUrls` (D-36).
   - Extracts `FormData` multipart fields and file metadata (`fileName`, `contentType`, `byteSize`) into `MultipartEntry` domain models, strictly discarding raw binary byte buffers (DATA-04).
   - In `onResponse`, sanitizes headers and body via `RedactionEngine` and `PayloadTruncator`, and updates the repository with `NetworkStatus.success`.
   - In `onError`, captures `DioException` details (error type `err.type.name`, message, stack trace, status code) into `HttpErrorDetails`, records `NetworkStatus.failed`, and resets the captured flag on options so retried requests generate distinct records with fresh UUIDs (D-35, INTC-07).
   - Maintains pure Dart implementation with zero `dart:io` imports for Flutter Web compatibility.

3. **Dedicated package:http Client Adapter (`NetworkInspectorHttpClient`):**
   - Implemented `NetworkInspectorHttpClient` subclassing `http.BaseClient` (INTC-05).
   - Accepts an optional `http.Client? inner` parameter, defaulting to `http.Client()`.
   - Intercepts `send(http.BaseRequest request)`, checking headers to prevent repeated/nested wrapper registrations (D-34).
   - Injects synthetic tracking headers `x-network-inspector-id` and `x-fl-net-inspector-tracked-id` (D-33).
   - Handles standard `http.Request`, `http.MultipartRequest` (extracting field and file `MultipartEntry` metadata per DATA-04), and `http.StreamedRequest`.
   - Traps synchronous or connection-level exceptions around `_inner.send` and records `NetworkStatus.failed` before rethrowing.
   - Uses `createStreamTapTransformer` to non-destructively tap `response.stream`, forwarding byte chunks synchronously downstream to the host application while accumulating bounded copies up to `maxBodyBytes` (INTC-03, D-41).
   - Bypasses raw memory buffering for binary MIME responses, recording `[Binary data: <mime_type>, <bytes>]` (D-43).
   - Wraps the tapped stream into a new `http.StreamedResponse`, permitting the caller to consume `response.stream.bytesToString()` without single-subscription stream draining errors.
   - Maintains pure Dart implementation with zero `dart:io` imports for Flutter Web compatibility.

## Verification Evidence

Automated tests passing:
- `test/interceptor/deduplication_test.dart` (4/4 passed): Verifies `x-network-inspector-id` is stripped before wire transmission, `InspectorHttpClientRequest` generates zero repository records when suppressed, case-insensitive header names are stripped, and normal requests without tracking headers are captured normally.
- `test/interceptor/dio_interceptor_test.dart` (8/8 passed): Verifies GET/POST request capture, `FormData` multipart metadata extraction without raw bytes, `DioException` mapping to `HttpErrorDetails` on HTTP 500, repeat registration protection, blacklisted host bypass, retried request fresh UUID generation, and disabled state no-op.
- `test/interceptor/http_client_adapter_test.dart` (8/8 passed): Verifies GET request capture, single-subscription stream consumption (`response.body` / `stream.bytesToString()`), POST request capture with redaction, `MultipartRequest` metadata extraction, binary response summary, socket failure handling, repeat wrapper protection, blacklisted host bypass, and disabled state no-op.
- `test/core/platform_safety_test.dart` (1/1 passed): Confirms zero `dart:io` imports in `lib/src/interceptor/dio/` and `lib/src/interceptor/http/`.
- Full test suite: 130/130 tests passing across the entire package.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected PayloadTruncator and RedactionEngine method signatures in client adapters**
- **Found during:** Task 2
- **Issue:** Initial draft in `NetworkInspectorDioInterceptor` attempted to call non-existent methods `PayloadTruncator.truncateString` and `RedactionEngine.redactJson`.
- **Fix:** Switched to existing domain utility APIs: `PayloadTruncator.truncate(body: ..., contentType: ..., maxBytes: ...)` and `engine.redactBody(jsonStr, 'application/json')`, which already performs deep recursive JSON redaction.
- **Files modified:** `lib/src/interceptor/dio/network_inspector_dio_interceptor.dart`
- **Commit:** `a9a5a19`

## Known Stubs

None. All adapters, deduplication handlers, and stream tapping pipelines are fully functional and wired to the repository.

## Threat Flags

None. Threat mitigations from STRIDE register T-03-04 (tracking header stripped before wire transmission), T-03-05 (duplicate capture suppression prevents database storm), and T-03-06 (FormData raw binary files discarded, retaining metadata only) were implemented and verified.

## Self-Check: PASSED

1. Created files exist:
   - `lib/src/interceptor/dio/network_inspector_dio_interceptor.dart` (FOUND)
   - `lib/src/interceptor/http/network_inspector_http_client.dart` (FOUND)
   - `test/interceptor/deduplication_test.dart` (FOUND)
   - `test/interceptor/dio_interceptor_test.dart` (FOUND)
   - `test/interceptor/http_client_adapter_test.dart` (FOUND)

2. Commits exist:
   - `f56ed21` (FOUND)
   - `a9a5a19` (FOUND)
   - `114f614` (FOUND)
