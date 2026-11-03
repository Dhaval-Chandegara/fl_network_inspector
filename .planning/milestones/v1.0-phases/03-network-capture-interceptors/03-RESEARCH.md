# Phase 3: Network Capture & Interceptors - Research

**Researched:** 2026-11-01  
**Domain:** Transparent HTTP/HTTPS Network Interception, Stream Tapping, & Manual Logging  
**Confidence:** HIGH  

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Deduplication & Request Filtering
- **D-33:** Client adapters (`NetworkInspectorDioInterceptor`, `NetworkInspectorHttpClient`) inject a synthetic UUID tracking header (`x-network-inspector-id: <uuid>`) into outgoing requests. `HttpOverrides` checks for this header; if present, it suppresses duplicate capture and strips the header before transmission over the wire so the backend server never receives it. — **Reversibility:** costly — Affects request lifecycle across all interceptor adapters and `HttpOverrides` pipeline.
- **D-34:** Client adapters prevent duplicate capture from nested or repeated registrations on the same client instance by tagging request metadata (e.g. `RequestOptions.extra` for Dio, internal request wrapper flag for `package:http`). — **Reversibility:** reversible — Internal client adapter state tracking.
- **D-35:** Retried and redirected requests (e.g., HTTP 301/302 redirects, Dio retry interceptors) are captured as distinct records with shared correlation metadata / new UUIDs rather than coalescing, ensuring developers have full visibility into intermediate redirections and retried failures. — **Reversibility:** costly — Impacts UI display and repository record structure.
- **D-36:** Configurable domain and URL pattern blacklist (`ignoredHosts` / `ignoredUrls`) in `NetworkInspectorConfig` to bypass capture early for analytics, logging services (Firebase, Sentry), or custom hostnames without modifying the underlying request. — **Reversibility:** reversible — Config filter check in interceptor ingress.

#### HttpOverrides Scope & Chaining
- **D-37:** `HttpOverrides` is automatically installed during `NetworkInspector.initialize()` when `enableAutoCapture: true` (and not on Flutter Web), with public helpers for explicit control: `NetworkInspector.startAutoCapture()`, `NetworkInspector.stopAutoCapture()`, and `NetworkInspector.runZoned()` for zone-scoped interception. — **Reversibility:** costly — Facade lifecycle and global runtime state management.
- **D-38:** Safe `HttpOverrides` chaining: preserve pre-existing `HttpOverrides.current` by delegating client creation to `previous.createHttpClient(context)` (falling back to default `HttpClient(context: context)` if null) and delegating proxy lookup to `previous.findProxyFromEnvironment(url, environment)`. — **Reversibility:** one-way — Critical for preventing breaking changes to host app proxy, corporate VPN, or custom SSL configurations.
- **D-39:** Transparent two-way proxying in custom `HttpClient` / `HttpClientRequest` / `HttpClientResponse` wrappers: forward all getters and setters directly to the underlying client (including `badCertificateCallback`, `idleTimeout`, `connectionTimeout`, `userAgent`, and proxy authentication) to ensure 100% fidelity to host application configuration. — **Reversibility:** costly — Affects all `dart:io` wrapped API surfaces.
- **D-40:** Clean lifecycle restoration: calling `NetworkInspector.stopAutoCapture()` or `NetworkInspector.dispose()` restores the exact previous override (`HttpOverrides.global = _previousOverrides`), leaving zero residual hooks or leaks. — **Reversibility:** reversible — Disposal logic.

#### Response Stream Buffering & Chunked/SSE Handling
- **D-41:** Non-destructive response stream tapping via `StreamTransformer.fromHandlers`: response chunks are copied into an internal byte accumulator up to `maxBodyBytes` and forwarded downstream synchronously to the host app's listener, guaranteeing zero latency introduction, zero stream backpressure corruption, and zero `StateError: Stream has already been listened to`. — **Reversibility:** one-way — Fundamental stream interception mechanism across `dart:io` and `package:http`.
- **D-42:** Progressive status updates for long-lived / infinite streams (e.g., SSE `text/event-stream` or live feeds): response status code and headers are saved immediately upon arrival; the body is captured up to `maxBodyBytes` and marked completed/truncated without waiting indefinitely for stream close (`onDone`). — **Reversibility:** costly — Repository update lifecycle and SSE support.
- **D-43:** Binary response streams (images, audio, video, pdf, zip) bypass memory buffering completely: bytes are forwarded directly downstream while accumulating only byte count, recording `[Binary data: <mime_type>, <total_bytes>]` with zero memory allocation. — **Reversibility:** reversible — Optimizes memory during large downloads.
- **D-44:** Aborted or failed response streams retain the partial body buffered so far and capture full error details (exception type, message, stack trace), marking status as `failed` rather than hanging or dropping the record. — **Reversibility:** costly — In-flight error handling and state persistence.

#### Manual Logging API DX
- **D-45:** Dual manual logging API: one-shot `NetworkInspector.logApi(...)` for completed calls + two-phase `NetworkInspector.startRequest(...)` returning a `NetworkRequestTracker` handle with `.onResponse(...)` and `.onError(...)` for tracking GraphQL, gRPC, WebSockets, or custom SDKs with exact timing. — **Reversibility:** costly — Public API facade and tracker contract.
- **D-46:** Flexible body parameter accepting `Object?` (such as `Map`, `List`, `String`, `Uint8List`): automatically detects `BodyType`, stringifies/encodes JSON, applies `RedactionEngine` and `PayloadTruncator`, and extracts multipart metadata if applicable. — **Reversibility:** reversible — Public helper input preprocessing.
- **D-47:** Standalone & linked error logging: `NetworkInspector.logError(...)` creates a standalone `failed` record if called independently, or updates an existing transaction if an `id` is supplied. — **Reversibility:** costly — Error logging facade contract.
- **D-48:** Complete zero-overhead no-op when `!NetworkInspector.isEnabled`: all manual logging methods return immediately without model allocations, JSON serialization, or database calls; `startRequest()` returns a lightweight no-op tracker instance. — **Reversibility:** costly — Production release performance guarantee.

### the agent's Discretion
- Internal class hierarchy and naming for `dart:io` wrappers (`InspectorHttpClient`, `InspectorHttpClientRequest`, `InspectorHttpClientResponse`).
- Stream transformation and chunk accumulation buffer mechanics.
- Header string normalization and case-insensitive check for `x-network-inspector-id`.
- Implementation details of `NetworkRequestTracker` and no-op tracker.

### Deferred Ideas (OUT OF SCOPE)
- None — all decisions directly clarify Phase 3 scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **INTC-01** | Automatic `dart:io` HTTP interception via `HttpOverrides` and custom non-destructive wrappers (`HttpClient`, `HttpClientRequest`, `HttpClientResponse`). | Researched transparent two-way proxying pattern for `dart:io` client interfaces, forwarding all configuration getters/setters without side effects. |
| **INTC-02** | Safe `HttpOverrides` chaining preserving pre-existing overrides (proxies, custom SSL certificates, APM hooks) without clobbering. | Documented parent-override delegation for `createHttpClient` and `findProxyFromEnvironment`, with clean teardown restoration in `stopAutoCapture()`. |
| **INTC-03** | Non-destructive stream handling via dual-forwarding `StreamTransformer` ensuring zero single-subscription stream draining (`Bad state: Stream has already been listened to`). | Established `StreamTransformer.fromHandlers` byte-tapping mechanics that forward stream chunks synchronously to consumer sinks while non-destructively buffering payload copies. |
| **INTC-04** | Dedicated `Dio` client adapter (`NetworkInspectorDioInterceptor`) supporting request, response, and error hooks. | Verified Dio 5.x `Interceptor` API contract (`onRequest`, `onResponse`, `onError`), `FormData` multipart metadata extraction, and error diagnostics mapping. |
| **INTC-05** | Dedicated `package:http` client adapter (`NetworkInspectorHttpClient`) subclassing `http.BaseClient`. | Researched `http.BaseClient.send(BaseRequest)` subclassing, `StreamedResponse` stream wrapping, and support for `Request`, `MultipartRequest`, and `StreamedRequest`. |
| **INTC-06** | Cross-interceptor request deduplication using internal synthetic tracking header (`x-fl-net-inspector-tracked-id` / `x-network-inspector-id`) stripped before wire transmission. | Established deduplication protocol: adapters inject UUID header; low-level `InspectorHttpClientRequest` checks, suppresses duplicate logging, and removes header before wire transmission. |
| **INTC-07** | Complete error, timeout, and socket failure interception ensuring aborted requests transition to failed status with stack traces. | Researched error boundary hooks catching `SocketException`, `HttpException`, `TimeoutException`, and `DioException`, preserving partial buffers and mapping to `HttpErrorDetails`. |
| **LOG-01** | Public static manual logging API (`NetworkInspector.logApi` and `NetworkInspector.logRequest` / `NetworkInspector.startRequest`) working independently of automatic interception. | Designed facade static methods `logApi`, `startRequest`, and `logError` interfacing directly with `NetworkInspectorRepository`. |
| **LOG-02** | Full parameter support for manual logging: method, URL, headers, query params, request/response bodies, status code, duration, timestamps, errors, and multipart metadata. | Designed flexible `Object?` input processing pipeline utilizing existing `BodyTypeDetector`, `RedactionEngine`, and `PayloadTruncator`. |
</phase_requirements>

## Project Constraints (from GEMINI.md)

- **Tech Stack:** Dart `>=3.0.0 <4.0.0`, Flutter `>=3.10.0`. Strict sound null safety, class modifiers (`sealed`, `final`, `interface`), records, pattern matching.
- **Database:** SQLite via `sqflite` (mobile) / `sqflite_common_ffi` (desktop & tests). Interceptors must save records asynchronously through `NetworkInspectorRepository` without blocking the main/UI thread.
- **Sensors & Sharing:** Out of scope for Phase 3 (handled in Phase 4 and Phase 5).
- **Performance:** Zero UI thread blocking; asynchronous I/O; bounded payload buffers (default limit 1MB / `1,048,576 bytes`).
- **Security:** Complete no-op in release builds unless explicitly forced (`NetworkInspectorConfig.enabled` defaults to `!kReleaseMode`); configurable redaction of sensitive credentials applied before storage.
- **Zero-Codegen:** Hand-crafted, immutable Dart 3 models with explicit serialization; no `build_runner`, `freezed`, or `json_serializable`.
- **Web Safety:** Conditional imports ensuring `dart:io` code is never statically imported on Flutter Web (`kIsWeb`).
- **No MITM / No Tampering:** Interceptors must observe and inspect traffic strictly non-destructively; never alter or mock server responses.

---

## Summary

Phase 3 implements the heart of the Flutter Network Inspector: transparent, non-destructive network capture across `dart:io`, `Dio`, and `package:http`, complemented by a high-ergonomics manual logging API (`NetworkInspector.logApi`, `startRequest`, and `logError`). The primary technical challenge in Dart network inspection is stream preservation: `HttpClientResponse` and `StreamedResponse` are single-subscription streams (`Stream<List<int>>`). Attempting to listen to them or buffer their bytes directly causes the host application to crash with `StateError: Stream has already been listened to`. 

To solve this transparently, Phase 3 employs a dual-forwarding `StreamTransformer.fromHandlers` stream view. Response chunks are synchronously emitted to the consumer application's event sink while copying bytes into an internal bounded accumulator up to `maxBodyBytes` (default 1MB). Binary responses (images, videos, PDFs) bypass buffer accumulation completely to prevent memory bloat, recording byte counts and MIME types directly.

Furthermore, Phase 3 establishes a safe `HttpOverrides` chaining mechanism that preserves pre-existing host application proxy and SSL configurations, coupled with an active deduplication protocol. Client adapters (`NetworkInspectorDioInterceptor` and `NetworkInspectorHttpClient`) inject an internal synthetic tracking header (`x-network-inspector-id`). When the request reaches the low-level `dart:io` layer, `InspectorHttpClientRequest` detects the tracking ID, suppresses duplicate capture, and strips the header before transmission over the wire. In production release builds or when disabled, all interceptors and manual logging methods immediately no-op with zero allocations.

**Primary recommendation:** Build `StreamTransformer`-based transparent stream wrappers for `dart:io` and `package:http`, implement `NetworkInspectorDioInterceptor` for Dio 5.x, enforce cross-interceptor deduplication via wire-stripped synthetic headers, and route all events asynchronously through the existing `NetworkInspectorRepository` pipeline.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| `dart:io` HTTP Interception (`HttpOverrides`) | Client Runtime (IO) | Interceptor Layer | Hooks into Dart VM's low-level `dart:io` socket/HTTP pipeline via `HttpOverrides.global` and `runZoned`. |
| `HttpOverrides` Safe Chaining | Interceptor Layer | Client Runtime (IO) | Preserves parent `HttpOverrides.current` by delegating client creation and proxy lookup to previous overrides. |
| Non-Destructive Stream Tapping | Interceptor Layer | Stream Processing | `StreamTransformer.fromHandlers` synchronously forwards chunks to host app while accumulating inspection buffers. |
| `Dio` Client Adapter | Client Adapter Layer | Interceptor Layer | Integrates with Dio's `Interceptor` chain (`onRequest`, `onResponse`, `onError`) for apps using Dio 5.x. |
| `package:http` Client Adapter | Client Adapter Layer | Interceptor Layer | Subclasses `http.BaseClient` to intercept `send(BaseRequest)` transparently across all platforms including Web. |
| Cross-Interceptor Deduplication | Interceptor Layer | Client Adapter Layer | Client adapters inject synthetic tracking headers; low-level `dart:io` wrapper detects, suppresses duplicates, and strips header. |
| URL & Host Filtering (`ignoredHosts`/`ignoredUrls`) | Interceptor Layer | Config Layer | Evaluates incoming URLs against configured blacklists prior to model allocation or repository storage. |
| Manual Logging Facade (`logApi`, `startRequest`) | Public Facade Tier | Repository Tier | Exposes simple static APIs for GraphQL, gRPC, WebSockets, or bespoke SDKs, returning `NetworkRequestTracker`. |
| Error & Abort Diagnostics | Interceptor Layer | Repository Tier | Traps network exceptions (`SocketException`, `TimeoutException`, `DioException`), saving partial payloads with `HttpErrorDetails`. |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard | Confidence |
|---------|---------|---------|--------------|------------|
| **`dart:io`** | Dart SDK | Low-level HTTP client & `HttpOverrides` | Native Dart VM networking library providing `HttpClient`, `HttpClientRequest`, and `HttpOverrides`. | HIGH `[VERIFIED: dart:io SDK docs]` |
| **`dart:async`** | Dart SDK | Stream transformers & asynchronous primitives | Provides `StreamTransformer.fromHandlers`, `EventSink`, and `StreamView` for non-destructive stream tapping. | HIGH `[VERIFIED: dart:async SDK docs]` |
| **`uuid`** | `^4.6.0` | RFC 4122 v4 unique ID generation | Cryptographically secure transaction ID generation for cross-interceptor tracking (already in `pubspec.yaml`). | HIGH `[VERIFIED: lib/src/utils/uuid_generator.dart:1-25]` |

### Supporting (Client Adapters)
| Library | Version Range | Purpose | When to Use | Confidence |
|---------|---------------|---------|-------------|------------|
| **`dio`** | `>=5.0.0 <6.0.0` (Latest: `5.11.1`) | Dedicated client adapter (`NetworkInspectorDioInterceptor`) | For consumer Flutter applications using Dio. Plugs into `dio.interceptors.add(...)`. | HIGH `[VERIFIED: pub.dev/packages/dio 5.11.1]` |
| **`http`** | `>=1.0.0 <2.0.0` (Latest: `1.6.0`) | Dedicated client adapter (`NetworkInspectorHttpClient`) | For consumer Flutter applications using `package:http`. Subclasses `http.BaseClient`. | HIGH `[VERIFIED: pub.dev/packages/http 1.6.0]` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `StreamTransformer.fromHandlers` | `StreamController.broadcast()` or `Stream.asBroadcastStream()` | Broadcast streams convert single-subscription streams to multi-subscription but break backpressure, buffer entire chunks in memory, and discard unlistened initial events. `StreamTransformer` maintains 100% fidelity to the host app's subscription timing. |
| Synthetic Header Deduplication (`x-network-inspector-id`) | Hash of (Method + URL + Timestamp) | Time-and-URL hashing fails under concurrent bursts, misses redirect variations, and risks false collisions. A synthetic UUID header guarantees 100% collision-free correlation and is stripped before wire transmission. |
| Client wrapper subclassing `http.BaseClient` | Monkey-patching global `http` top-level functions | Dart top-level functions (`http.get`, `http.post`) cannot be dynamically swapped or patched at runtime. Subclassing `http.BaseClient` provides standard idiomatic injection. |

**Installation in `pubspec.yaml`:**
```yaml
dependencies:
  flutter:
    sdk: flutter
  uuid: ^4.6.0
  sqflite: ^2.4.5
  sqflite_common_ffi: ^2.4.5
  path: ^1.9.1
  dio: ">=5.0.0 <6.0.0"
  http: ">=1.0.0 <2.0.0"
```

**Version verification:**
- `dio`: `5.11.1` published 2026-09-04 by verified publisher `flutter.cn` `[VERIFIED: pub.dev/packages/dio]`
- `http`: `1.6.0` published 2025-11-10 by verified publisher `dart.dev` `[VERIFIED: pub.dev/packages/http]`

---

## Package Legitimacy Audit

| Package | Registry | Age | Likes / Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-------------------|-------------|---------|-------------|
| `dio` | pub.dev | ~7 yrs | 8.3k likes, 140 pub points | `github.com/cfug/dio` | [OK] | Approved |
| `http` | pub.dev | ~12 yrs | 8.4k likes, 140 pub points | `github.com/dart-lang/http` | [OK] | Approved |

**Packages removed due to [SLOP] verdict:** None.  
**Packages flagged as suspicious [SUS]:** None.  

---

## Architecture Patterns

### System Architecture Diagram

```
       Host Application Network Calls
      ┌───────────────────────────────┐
      │  Manual API    Dio Client     │
      │  (logApi /     (Dio 5.x)      │
      │ startRequest)                 │
      └──────┬─────────────┬──────────┘
             │             │
             │     [NetworkInspectorDioInterceptor]
             │     - Injects: x-network-inspector-id
             │     - Extracts: FormData multipart metadata
             │     - Saves: Pending NetworkRecord
             │             │
             ▼             ▼
   [NetworkInspectorFacade] ──► [dart:io / http.Client]
                                       │
                                       ▼
                       [InspectorHttpOverrides]
                       (Chained with previous HttpOverrides)
                                       │
                                       ▼
                         [InspectorHttpClient]
                                       │
                                       ▼
                     [InspectorHttpClientRequest]
                     - Check x-network-inspector-id?
                       ├─► YES: Suppress duplicate capture,
                       │        strip header from wire!
                       └─► NO:  Native dart:io request!
                                Check ignoredHosts/Urls,
                                Save Pending NetworkRecord
                                       │
                                       ▼
                         Wire Transmission (Network)
                                       │
                                       ▼
                    [InspectorHttpClientResponse]
                    - Capture status code & headers
                    - Tap Stream<List<int>> non-destructively:
                      ┌────────────────────────────────┐
                      │ StreamTransformer.fromHandlers │
                      └───────┬────────────────┬───────┘
                              │                │
            Forward chunks to │                │ Accumulate copy up to
            Host App Listener │                │ maxBodyBytes (skip binary)
                              ▼                ▼
                     [Host App Stream]   [Buffer Accumulator]
                                               │
                                               ▼ onDone / onError
                                     [RedactionEngine]
                                               │
                                               ▼
                                     [PayloadTruncator]
                                               │
                                               ▼
                                     [Repository.save()]
                                     (NetworkStatus.success /
                                      NetworkStatus.failed)
```

### Recommended Project Structure
```
lib/src/
├── interceptor/
│   ├── dio/
│   │   └── network_inspector_dio_interceptor.dart  # INTC-04: Dio interceptor adapter
│   ├── http/
│   │   └── network_inspector_http_client.dart      # INTC-05: package:http BaseClient adapter
│   ├── io/
│   │   ├── http_overrides_manager.dart             # INTC-01, INTC-02: HttpOverrides chaining
│   │   ├── inspector_http_client.dart              # INTC-01, INTC-02: HttpClient proxy wrapper
│   │   ├── inspector_http_client_request.dart      # INTC-01, INTC-06: Request wrapper & header stripper
│   │   └── inspector_http_client_response.dart     # INTC-01, INTC-03: Response wrapper & stream tapping
│   ├── platform/
│   │   ├── http_capture_stub.dart                  # Web no-op fallback for HttpOverrides
│   │   └── http_capture_io.dart                    # dart:io HttpOverrides registration
│   └── stream/
│       └── stream_tap_transformer.dart             # INTC-03: Reusable dual-forwarding transformer
├── logging/
│   ├── manual_logger.dart                          # LOG-01, LOG-02: NetworkInspector.logApi / logError
│   ├── network_request_tracker.dart                # LOG-01: Two-phase request tracker interface
│   └── no_op_network_request_tracker.dart          # LOG-01, D-48: Zero-overhead production no-op tracker
```

---

### Pattern 1: Transparent `dart:io` Stream Tapping via `StreamTransformer`
**What:** Synchronously tap response stream chunks without consuming or buffering the stream in advance, passing each chunk immediately to the host application while accumulating a byte copy up to `maxBodyBytes`.  
**When to use:** In `InspectorHttpClientResponse` and `NetworkInspectorHttpClient` to avoid `StateError: Stream has already been listened to`.  
**Example:**
```dart
// StreamTapTransformer using StreamTransformer.fromHandlers
StreamTransformer<List<int>, List<int>> createStreamTapTransformer({
  required int maxBodyBytes,
  required bool isBinary,
  required void Function(List<int> bufferedBytes, bool isTruncated) onComplete,
  required void Function(Object error, StackTrace stackTrace, List<int> partialBytes) onError,
}) {
  final buffer = BytesBuilder(copy: false);
  int accumulatedBytes = 0;
  bool isTruncated = false;

  return StreamTransformer<List<int>, List<int>>.fromHandlers(
    handleData: (List<int> chunk, EventSink<List<int>> sink) {
      // 1. Synchronously forward chunk downstream to host application listener
      sink.add(chunk);

      // 2. Accumulate copy for network inspection buffer
      if (!isBinary) {
        if (accumulatedBytes + chunk.length <= maxBodyBytes) {
          buffer.add(chunk);
          accumulatedBytes += chunk.length;
        } else if (!isTruncated) {
          final remaining = maxBodyBytes - accumulatedBytes;
          if (remaining > 0) {
            buffer.add(chunk.sublist(0, remaining));
            accumulatedBytes += remaining;
          }
          isTruncated = true;
        }
      } else {
        accumulatedBytes += chunk.length;
      }
    },
    handleError: (Object error, StackTrace stackTrace, EventSink<List<int>> sink) {
      sink.addError(error, stackTrace);
      onError(error, stackTrace, buffer.takeBytes());
    },
    handleDone: (EventSink<List<int>> sink) {
      sink.close();
      onComplete(buffer.takeBytes(), isTruncated);
    },
  );
}
```

---

### Pattern 2: Safe `HttpOverrides` Chaining and Two-Way Delegation
**What:** Retain reference to `HttpOverrides.current` before overwriting `HttpOverrides.global`. In `createHttpClient` and `findProxyFromEnvironment`, delegate to `previous` if present, falling back to Dart defaults.  
**When to use:** In `InspectorHttpOverrides` to ensure enterprise proxies, VPN routes, and custom SSL certificates continue operating uninterrupted.  
**Example:**
```dart
class InspectorHttpOverrides extends HttpOverrides {
  final HttpOverrides? _previousOverrides;
  final NetworkInspectorConfig _config;

  InspectorHttpOverrides({
    HttpOverrides? previousOverrides,
    required NetworkInspectorConfig config,
  })  : _previousOverrides = previousOverrides,
        _config = config;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = _previousOverrides != null
        ? _previousOverrides!.createHttpClient(context)
        : super.createHttpClient(context);
    return InspectorHttpClient(client, _config);
  }

  @override
  String findProxyFromEnvironment(Uri url, Map<String, String>? environment) {
    if (_previousOverrides != null) {
      return _previousOverrides!.findProxyFromEnvironment(url, environment);
    }
    return super.findProxyFromEnvironment(url, environment);
  }
}
```

---

### Pattern 3: Cross-Interceptor Deduplication with Synthetic Header Stripping
**What:** Client adapters inject a synthetic header (`x-network-inspector-id`). When the request hits the underlying `dart:io` `InspectorHttpClientRequest`, it inspects headers: if present, it removes the header so it never reaches the backend and suppresses creating a duplicate `NetworkRecord`.  
**When to use:** Whenever Dio or `package:http` operates on a platform where `HttpOverrides` is also active.  
**Example:**
```dart
// Inside InspectorHttpClientRequest.close()
final trackingHeader = NetworkInspectorConstants.internalTrackingHeader;
// Also support case-insensitive check or D-33 header 'x-network-inspector-id'
final isAlreadyTracked = _underlyingRequest.headers[trackingHeader] != null ||
    _underlyingRequest.headers['x-network-inspector-id'] != null;

if (isAlreadyTracked) {
  // Strip tracking header before transmitting over the wire!
  _underlyingRequest.headers.removeAll(trackingHeader);
  _underlyingRequest.headers.removeAll('x-network-inspector-id');
  // Suppress duplicate record creation
  _isSuppressed = true;
}
```

---

### Pattern 4: Two-Phase Manual Logging Tracker with No-Op Optimization
**What:** Provide `NetworkInspector.startRequest(...)` returning a `NetworkRequestTracker` that handles asynchronous completion via `.onResponse(...)` or `.onError(...)`. In release mode or when disabled, return `const NoOpNetworkRequestTracker()`.  
**When to use:** For instrumenting custom SDKs, GraphQL, gRPC, or WebSocket HTTP handshakes.  
**Example:**
```dart
abstract interface class NetworkRequestTracker {
  String get id;
  Future<void> onResponse({
    required int statusCode,
    Map<String, dynamic>? headers,
    Object? body,
    DateTime? timestamp,
  });
  Future<void> onError({
    required Object error,
    StackTrace? stackTrace,
    int? statusCode,
    Map<String, dynamic>? headers,
    Object? body,
  });
}

final class NoOpNetworkRequestTracker implements NetworkRequestTracker {
  const NoOpNetworkRequestTracker();

  @override
  String get id => '';

  @override
  Future<void> onResponse({
    required int statusCode,
    Map<String, dynamic>? headers,
    Object? body,
    DateTime? timestamp,
  }) async {}

  @override
  Future<void> onError({
    required Object error,
    StackTrace? stackTrace,
    int? statusCode,
    Map<String, dynamic>? headers,
    Object? body,
  }) async {}
}
```

---

### Anti-Patterns to Avoid
- **Consuming Single-Subscription Streams (`await response.toList()`):** Drains the stream, crashing the host app with `StateError: Stream has already been listened to`. Always use non-destructive `StreamTransformer`.
- **Clobbering `HttpOverrides.global` without Parent Delegation:** Overwrites host app VPN, enterprise proxy, and SSL certificate pins. Always capture `HttpOverrides.current` and delegate client creation and proxy lookup.
- **Transmitting Synthetic Headers to Upstream Servers:** Leaks internal package implementation details to remote APIs and may trigger CORS errors or header validation failures. Always remove `x-network-inspector-id` before transmission.
- **Storing Raw Binary File Uploads/Downloads:** Capturing 20MB image/video bytes in SQLite triggers Out-Of-Memory (OOM) crashes and frame drops. Always detect binary MIME types, omit raw bytes, and store `[Binary data: <mime_type>, <total_bytes>]` metadata only.
- **Unconditionally Importing `dart:io`:** Breaks Flutter Web compilation. Always isolate `dart:io` code behind conditional exports.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Stream splitting & tapping | Custom byte broadcaster or manual multi-listener queue | `StreamTransformer.fromHandlers` | Preserves stream single-subscription lifecycle, backpressure, and synchronous chunk forwarding without memory spikes or delayed emissions. |
| Unique Request Tracking IDs | Custom timestamp/counter string generator | `UuidGenerator.v4()` | RFC 4122 v4 UUIDs eliminate collision risks in high-throughput concurrent async environments (`[VERIFIED: lib/src/utils/uuid_generator.dart:10-25]`). |
| Sensitive Credential Redaction | Ad-hoc regex replacements on raw request strings | `RedactionEngine` | Handles delimiter normalization (`-`, `_`, `.`), recursive JSON sanitization, and header masking consistently (`[VERIFIED: lib/src/utils/redaction_engine.dart:18-35]`). |
| Payload Body Truncation & UTF-8 Slicing | Naive string slicing (`body.substring(0, limit)`) | `PayloadTruncator` | Prevents UTF-8 multi-byte character boundary corruption and formats standardized truncation banners (`[VERIFIED: lib/src/utils/payload_truncator.dart:15-30]`). |
| Content Type Detection | Manual string contains checks | `BodyTypeDetector` | Accurately identifies `json`, `formData`, `multipart`, `binary`, and `text` from MIME types and content heuristics (`[VERIFIED: lib/src/utils/body_type_detector.dart:1-50]`). |

**Key insight:** Custom interception solutions frequently introduce stream draining bugs, corrupt multi-byte UTF-8 character boundaries during truncation, or clobber host application proxies. Relying on verified Phase 1 domain utilities and native `StreamTransformer` patterns ensures zero regression risk.

---

## In-Repo Values & Type Definitions

The following in-repo values have been verified by reading source files directly during this research session:

### `NetworkStatus`
`[VERIFIED: lib/src/models/network_status.dart:2-10]`
```dart
enum NetworkStatus {
  /// Request has been sent/intercepted and is awaiting server response.
  pending,

  /// Request completed with a valid HTTP response.
  success,

  /// Request encountered a network error, socket exception, timeout, or failure.
  failed;
```

### `BodyType`
`[VERIFIED: lib/src/models/body_type.dart:2-19]`
```dart
enum BodyType {
  /// Structured JSON format.
  json,

  /// Plain text, HTML, XML, or unstructured string content.
  text,

  /// URL-encoded form data (`application/x-www-form-urlencoded`).
  formData,

  /// Multi-part form data containing parameters and file upload references.
  multipart,

  /// Binary octet stream or raw byte content.
  binary,

  /// Empty or absent request/response body.
  empty;
```

### `PayloadData`
`[VERIFIED: lib/src/models/payload_data.dart:7-26]`
```dart
class PayloadData {
  /// The string representation of the payload body (or formatted summary for binary/multipart).
  final String? body;

  /// The raw payload size in bytes.
  final int byteSize;

  /// The detected payload format classification.
  final BodyType bodyType;

  /// Whether the body content was truncated due to configured size limits.
  final bool isTruncated;

  /// Creates a [PayloadData] instance.
  const PayloadData({
    this.body,
    this.byteSize = 0,
    this.bodyType = BodyType.empty,
    this.isTruncated = false,
  });
```

### `HttpErrorDetails`
`[VERIFIED: lib/src/models/http_error_details.dart:5-24]`
```dart
class HttpErrorDetails {
  /// The human-readable error description or exception message.
  final String message;

  /// The runtime type or classification of the error (e.g. `SocketException`, `TimeoutException`, `DioException`).
  final String? errorType;

  /// Stringified stack trace captured at the failure site.
  final String? stackTrace;

  /// The associated HTTP response status code, if any.
  final int? statusCode;

  /// Creates an [HttpErrorDetails] instance.
  const HttpErrorDetails({
    required this.message,
    this.errorType,
    this.stackTrace,
    this.statusCode,
  });
```

### `NetworkInspectorConstants`
`[VERIFIED: lib/src/core/constants.dart:2-31]`
```dart
abstract final class NetworkInspectorConstants {
  const NetworkInspectorConstants._();

  /// Default maximum records retained in local storage (D-01).
  static const int defaultMaxRecords = 500;

  /// Default maximum payload body bytes before truncation (1 MB / 1,048,576 bytes) (D-02).
  static const int defaultMaxBodyBytes = 1048576;

  /// Constant placeholder for redacted sensitive values (D-12).
  static const String redactedPlaceholder = '[REDACTED]';

  /// Internal tracking header used to correlate request/response pairs across interceptors.
  static const String internalTrackingHeader = 'x-fl-net-inspector-tracked-id';

  /// Default blacklist of sensitive keys for headers, query params, and JSON bodies (D-09).
  static const List<String> defaultSensitiveKeys = [
    'authorization',
    'cookie',
    'set-cookie',
    'token',
    'access_token',
    'refresh_token',
    'password',
    'secret',
    'api_key',
    'apikey',
    'private_key',
  ];
}
```

### `NetworkInspectorConfig` Existing Fields
`[VERIFIED: lib/src/config/network_inspector_config.dart:37-46]`
```dart
  const NetworkInspectorConfig({
    bool? enabled,
    this.maxRecords = NetworkInspectorConstants.defaultMaxRecords,
    this.maxBodyBytes = NetworkInspectorConstants.defaultMaxBodyBytes,
    this.enableAutoCapture = true,
    this.enableShakeDetection = true,
    this.enableDatabase = true,
    this.includeMultipartFilePaths = false,
    this.customRedactionKeys = const [],
  }) : _enabled = enabled;
```

---

## Common Pitfalls

### Pitfall 1: Breaking Single-Subscription Streams (`Stream has already been listened to`)
**What goes wrong:** The consumer application crashes when reading `response.body`, `response.transform()`, or listening to response bytes.  
**Why it happens:** In `dart:io` (`HttpClientResponse`) and `package:http` (`StreamedResponse`), response streams are single-subscription. Any interceptor that invokes `await response.toList()` or listens directly drains the stream permanently.  
**How to avoid:** Wrap the response stream in a custom `StreamView` using `StreamTransformer.fromHandlers`. Chunks are synchronously forwarded downstream via `sink.add(chunk)` while being accumulated into a background byte builder. The host application remains the only subscriber to the stream.  
**Warning signs:** Tests or apps throwing `Bad state: Stream has already been listened to`.

### Pitfall 2: Clobbering Host Application `HttpOverrides`
**What goes wrong:** Setting `HttpOverrides.global = InspectorHttpOverrides()` destroys pre-existing overrides such as corporate proxies, Charles/Proxyman debugging certs, or SSL pinning bypasses, breaking all app networking.  
**Why it happens:** `HttpOverrides.global` is a single static setter. Overwriting it drops the previous reference.  
**How to avoid:** In `InspectorHttpOverrides`, capture `final previous = HttpOverrides.current;` and delegate all unmatched methods (`createHttpClient`, `findProxyFromEnvironment`) to `previous`. When auto-capture is stopped, restore `HttpOverrides.global = previous`.  
**Warning signs:** Host application proxy or custom SSL cert callbacks failing after initializing `NetworkInspector`.

### Pitfall 3: Duplicate Records from Client Adapters + `HttpOverrides`
**What goes wrong:** When a user configures both `NetworkInspectorDioInterceptor` and `enableAutoCapture: true`, every Dio request is recorded twice (once by Dio interceptor, once by `dart:io` `HttpOverrides`).  
**Why it happens:** Dio uses `dart:io` under the hood on mobile and desktop.  
**How to avoid:** Dio and `package:http` adapters inject a synthetic header (`x-network-inspector-id`). `InspectorHttpClientRequest` checks for this header, strips it before sending over the wire, and suppresses duplicate capture.  
**Warning signs:** Database recording two entries with the same URL and timing for a single network call.

### Pitfall 4: Memory Exhaustion on Infinite / Long-Lived Streams (SSE)
**What goes wrong:** Buffering until `onDone` hangs indefinitely for Server-Sent Events (`text/event-stream`) or causes OOM crashes on massive file downloads.  
**Why it happens:** SSE streams never call `onDone` under normal operation.  
**How to avoid:** Progressive recording (D-42): save response status code and headers immediately upon arrival. For streaming responses, accumulate up to `maxBodyBytes` (default 1MB) and mark completed/truncated. For binary streams (D-43), skip buffering completely and accumulate only byte counts.  
**Warning signs:** Inspector records for SSE remaining stuck in `pending` indefinitely or app RAM climbing continuously during file downloads.

### Pitfall 5: Flutter Web Compilation Failure
**What goes wrong:** Building for Flutter Web throws `Error: Unsupported operation: dart:io is not supported on this platform`.  
**Why it happens:** Direct static imports of `dart:io` fail at web compile time.  
**How to avoid:** Isolate `dart:io` behind conditional imports (`export 'http_capture_stub.dart' if (dart.library.io) 'http_capture_io.dart';`). Ensure `NetworkInspectorDioInterceptor` and `NetworkInspectorHttpClient` remain pure platform-agnostic Dart.  
**Warning signs:** Web CI build failures reporting unresolved `dart:io` symbols.

---

## Code Examples

### 1. `NetworkInspectorDioInterceptor` Implementation
```dart
import 'package:dio/dio.dart';
import '../../core/constants.dart';
import '../../core/network_inspector.dart';
import '../../models/http_error_details.dart';
import '../../models/multipart_entry.dart';
import '../../models/network_record.dart';
import '../../models/network_status.dart';
import '../../utils/uuid_generator.dart';

class NetworkInspectorDioInterceptor extends Interceptor {
  static const _capturedKey = '__fl_net_inspector_captured';
  static const _recordIdKey = '__fl_net_inspector_id';
  static const _startTimeKey = '__fl_net_inspector_start';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!NetworkInspector.isEnabled) {
      return handler.next(options);
    }

    // D-34: Prevent duplicate capture from repeated registrations
    if (options.extra[_capturedKey] == true) {
      return handler.next(options);
    }
    options.extra[_capturedKey] = true;

    // D-36: Host and URL blacklist check
    final uri = options.uri;
    if (_isIgnored(uri)) {
      return handler.next(options);
    }

    final id = UuidGenerator.v4();
    final startTimestamp = DateTime.now();
    options.extra[_recordIdKey] = id;
    options.extra[_startTimeKey] = startTimestamp;

    // D-33: Inject synthetic tracking header for low-level HttpOverrides deduplication
    options.headers[NetworkInspectorConstants.internalTrackingHeader] = id;
    options.headers['x-network-inspector-id'] = id;

    // Extract multipart metadata if FormData (DATA-04)
    List<MultipartEntry>? multipartEntries;
    if (options.data is FormData) {
      final formData = options.data as FormData;
      multipartEntries = [
        for (final field in formData.fields)
          MultipartEntry(
            fieldName: field.key,
            isText: true,
            textValue: field.value,
          ),
        for (final file in formData.files)
          MultipartEntry(
            fieldName: file.key,
            fileName: file.value.filename,
            contentType: file.value.contentType?.mimeType,
            length: file.value.length,
            isText: false,
          ),
      ];
    }

    // Create and save pending record
    final record = NetworkRecord(
      id: id,
      url: uri.toString(),
      baseUrl: '${uri.scheme}://${uri.authority}',
      path: uri.path,
      method: options.method.toUpperCase(),
      requestHeaders: Map<String, dynamic>.from(options.headers),
      requestQueryParams: uri.queryParameters,
      requestTimestamp: startTimestamp,
      multipartEntries: multipartEntries,
      status: NetworkStatus.pending,
    );

    NetworkInspector.repository?.save(record);
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!NetworkInspector.isEnabled) {
      return handler.next(response);
    }

    final id = response.requestOptions.extra[_recordIdKey] as String?;
    final startTimestamp = response.requestOptions.extra[_startTimeKey] as DateTime?;

    if (id != null && startTimestamp != null) {
      final endTimestamp = DateTime.now();
      final durationMs = endTimestamp.difference(startTimestamp).inMilliseconds;

      _updateRecordSuccess(
        id: id,
        response: response,
        durationMs: durationMs,
        endTimestamp: endTimestamp,
      );
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!NetworkInspector.isEnabled) {
      return handler.next(err);
    }

    final id = err.requestOptions.extra[_recordIdKey] as String?;
    final startTimestamp = err.requestOptions.extra[_startTimeKey] as DateTime?;

    if (id != null && startTimestamp != null) {
      final endTimestamp = DateTime.now();
      final durationMs = endTimestamp.difference(startTimestamp).inMilliseconds;

      final errorDetails = HttpErrorDetails(
        message: err.message ?? err.toString(),
        errorType: err.type.name,
        stackTrace: err.stackTrace.toString(),
        statusCode: err.response?.statusCode,
      );

      _updateRecordFailed(
        id: id,
        error: errorDetails,
        response: err.response,
        durationMs: durationMs,
        endTimestamp: endTimestamp,
      );
    }

    handler.next(err);
  }

  bool _isIgnored(Uri uri) {
    final config = NetworkInspector.currentConfig;
    // Evaluation against config.ignoredHosts and config.ignoredUrls
    return false;
  }

  void _updateRecordSuccess({required String id, required Response response, required int durationMs, required DateTime endTimestamp}) {
    // Deserialize, redact, and save updated record to repository
  }

  void _updateRecordFailed({required String id, required HttpErrorDetails error, Response? response, required int durationMs, required DateTime endTimestamp}) {
    // Deserialize, redact, and save failed record to repository
  }
}
```

### 2. `NetworkInspectorHttpClient` Implementation (`package:http`)
```dart
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/network_inspector.dart';
import '../../models/multipart_entry.dart';
import '../../models/network_record.dart';
import '../../models/network_status.dart';
import '../../utils/uuid_generator.dart';
import '../stream/stream_tap_transformer.dart';

class NetworkInspectorHttpClient extends http.BaseClient {
  final http.Client _inner;

  NetworkInspectorHttpClient([http.Client? inner]) : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!NetworkInspector.isEnabled) {
      return _inner.send(request);
    }

    final id = UuidGenerator.v4();
    final startTimestamp = DateTime.now();

    // D-33: Inject synthetic header for deduplication
    request.headers[NetworkInspectorConstants.internalTrackingHeader] = id;
    request.headers['x-network-inspector-id'] = id;

    // Capture pending record
    final record = NetworkRecord(
      id: id,
      url: request.url.toString(),
      baseUrl: '${request.url.scheme}://${request.url.authority}',
      path: request.url.path,
      method: request.method.toUpperCase(),
      requestHeaders: Map<String, dynamic>.from(request.headers),
      requestQueryParams: request.url.queryParameters,
      requestTimestamp: startTimestamp,
      status: NetworkStatus.pending,
    );
    await NetworkInspector.repository?.save(record);

    http.StreamedResponse response;
    try {
      response = await _inner.send(request);
    } catch (e, st) {
      // INTC-07: Intercept network failure
      final durationMs = DateTime.now().difference(startTimestamp).inMilliseconds;
      // Save failed record with error details
      rethrow;
    }

    // Tap response stream non-destructively
    final tappedStream = response.stream.transform(
      createStreamTapTransformer(
        maxBodyBytes: NetworkInspector.currentConfig.maxBodyBytes,
        isBinary: _isBinary(response.headers['content-type']),
        onComplete: (bytes, isTruncated) {
          final durationMs = DateTime.now().difference(startTimestamp).inMilliseconds;
          // Update record with status: NetworkStatus.success
        },
        onError: (err, st, partialBytes) {
          // Update record with status: NetworkStatus.failed
        },
      ),
    );

    return http.StreamedResponse(
      http.ByteStream(tappedStream),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  bool _isBinary(String? contentType) => false;

  @override
  void close() {
    _inner.close();
  }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `await response.toList()` to read body | `StreamTransformer.fromHandlers` stream view | Flutter 1.x / Modern Dart | Eliminates `StateError: Stream has already been listened to` entirely. |
| Overwriting `HttpOverrides.global` directly | Safe chaining preserving `HttpOverrides.current` | Dart 2.x | Allows coexistence with proxies, VPN tunnels, and custom SSL configurations. |
| In-memory List/RingBuffer logging | Asynchronous SQLite write buffer queue | Modern debugging architectures | Zero UI thread stutter and persistence across app restarts/crashes. |
| Storing raw multipart file binaries | Storing `MultipartEntry` metadata only | Modern mobile memory safety | Eliminates Out-Of-Memory (OOM) crashes on large file uploads. |
| One-shot manual logging only | Dual manual API: one-shot `logApi` + two-phase `startRequest` | Modern diagnostic requirements | Enables sub-millisecond round-trip profiling for GraphQL and gRPC. |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `ignoredHosts` and `ignoredUrls` can be cleanly added to `NetworkInspectorConfig` with backward-compatible default empty lists. | User Constraints / Config | Low — non-breaking additive configuration change. |
| A2 | Dio `FormData` files can be read for length, filename, and content type without reading file byte streams. | Code Examples / INTC-04 | Low — Dio `MultipartFile` exposes `filename`, `length`, and `contentType` properties synchronously. |

---

## Open Questions (RESOLVED)

1. **How should `NetworkInspectorConfig` support URL matching for `ignoredUrls`?** — RESOLVED: `ignoredUrls` uses `List<String>` with case-insensitive substring/glob matching per D-36, with optional regex support.
   - *What we know:* Users want to bypass capture for analytics endpoints (e.g., Firebase, Sentry).
   - *Resolution:* Supported as `List<String>` doing case-insensitive substring/contains matching, with full compatibility for exact paths and domain patterns.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Dart SDK | Core runtime | ✓ | `>=3.0.0 <4.0.0` | — |
| Flutter SDK | Framework runtime | ✓ | `>=3.10.0` | — |
| `pub.dev` | Package resolution | ✓ | Online | Cached pub cache |
| SQLite FFI | Desktop & unit testing | ✓ | `sqflite_common_ffi ^2.4.5` | In-memory repository fallback |

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (SDK) / `test` (`^1.25.0`) |
| Config file | `pubspec.yaml` |
| Quick run command | `flutter test test/interceptor/stream_tap_transformer_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| **INTC-01** | Automatic `dart:io` HTTP interception | integration | `flutter test test/interceptor/http_client_interceptor_test.dart` | ❌ Wave 0 |
| **INTC-02** | Safe `HttpOverrides` chaining | unit | `flutter test test/interceptor/http_overrides_chaining_test.dart` | ❌ Wave 0 |
| **INTC-03** | Non-destructive stream handling via `StreamTransformer` | unit | `flutter test test/interceptor/stream_tap_transformer_test.dart` | ❌ Wave 0 |
| **INTC-04** | Dedicated `Dio` client adapter (`NetworkInspectorDioInterceptor`) | unit / integration | `flutter test test/interceptor/dio_interceptor_test.dart` | ❌ Wave 0 |
| **INTC-05** | Dedicated `package:http` client adapter (`NetworkInspectorHttpClient`) | unit / integration | `flutter test test/interceptor/http_client_adapter_test.dart` | ❌ Wave 0 |
| **INTC-06** | Cross-interceptor request deduplication & header stripping | unit | `flutter test test/interceptor/deduplication_test.dart` | ❌ Wave 0 |
| **INTC-07** | Error, timeout, and socket failure interception | unit | `flutter test test/interceptor/error_interception_test.dart` | ❌ Wave 0 |
| **LOG-01** | Public static manual logging API (`logApi`, `startRequest`) | unit | `flutter test test/logging/manual_logging_test.dart` | ❌ Wave 0 |
| **LOG-02** | Full parameter support for manual logging | unit | `flutter test test/logging/manual_logging_parameters_test.dart` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/interceptor/`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full test suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/interceptor/stream_tap_transformer_test.dart` — tests non-destructive stream tapping, truncation, and single-subscription preservation (INTC-03)
- [ ] `test/interceptor/http_overrides_chaining_test.dart` — tests parent override preservation and restoration (INTC-02)
- [ ] `test/interceptor/deduplication_test.dart` — tests synthetic tracking header injection, wire stripping, and duplicate suppression (INTC-06)
- [ ] `test/interceptor/dio_interceptor_test.dart` — tests Dio request/response/error interceptor hooks (INTC-04)
- [ ] `test/interceptor/http_client_adapter_test.dart` — tests `package:http` BaseClient adapter (INTC-05)
- [ ] `test/logging/manual_logging_test.dart` — tests `NetworkInspector.logApi`, `startRequest`, and `logError` (LOG-01, LOG-02)

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| **V5 Input Validation** | Yes | Sanitize incoming URLs, validate header string structures, and enforce byte-bounded payload buffers (`maxBodyBytes`). |
| **V6 Cryptography** | No | No custom cryptography. Uses cryptographically secure RFC 4122 v4 UUIDs via `UuidGenerator.v4()`. |
| **Sensitive Data Redaction** | Yes | Always run `RedactionEngine` on request/response headers, query parameters, and bodies before persisting records. |
| **Synthetic Header Leakage** | Yes | `InspectorHttpClientRequest` must strictly strip `x-network-inspector-id` and `x-fl-net-inspector-tracked-id` before sending bytes over the wire. |
| **Release Build Protection** | Yes | In release mode (`kReleaseMode`), `NetworkInspectorConfig.enabled` defaults to `false`, rendering all interceptors and logging methods zero-allocation no-ops. |

### Known Threat Patterns for Network Interception

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Synthetic Header Leakage to Upstream APIs | Information Disclosure | Low-level `InspectorHttpClientRequest` strips `x-network-inspector-id` from `request.headers` before network dispatch. |
| Sensitive Credential Leakage in Persistent Storage | Information Disclosure | `RedactionEngine` sanitizes Authorization, Cookie, tokens, passwords, and custom keys prior to repository persistence. |
| Denial of Service via Memory Exhaustion (OOM) | Denial of Service | `PayloadTruncator` enforces strict 1MB limits; binary streams bypass memory buffering entirely. |
| Man-In-The-Middle / Stream Tampering | Tampering | Read-only inspection; interceptor never alters request or response bytes on the wire. |

---

## Sources

### Primary (HIGH confidence)
- `dart:io` SDK documentation (`dart:io/HttpClient`, `dart:io/HttpOverrides`, `dart:io/HttpClientRequest`, `dart:io/HttpClientResponse`)
- `dart:async` SDK documentation (`dart:async/StreamTransformer`, `dart:async/EventSink`)
- Official `pub.dev/packages/dio` (5.11.1) documentation & GitHub repository (`cfug/dio`)
- Official `pub.dev/packages/http` (1.6.0) documentation & GitHub repository (`dart-lang/http`)
- In-repo source of truth files:
  - `lib/src/models/network_status.dart:2-10`
  - `lib/src/models/body_type.dart:2-19`
  - `lib/src/models/http_error_details.dart:5-24`
  - `lib/src/models/payload_data.dart:7-26`
  - `lib/src/core/constants.dart:2-31`
  - `lib/src/config/network_inspector_config.dart:37-46`
  - `lib/src/utils/payload_truncator.dart:15-30`
  - `lib/src/utils/redaction_engine.dart:18-35`
  - `lib/src/utils/uuid_generator.dart:10-25`

### Secondary (MEDIUM confidence)
- Flutter Community Plus plugins documentation & architecture patterns
- Post-mortem documentation in `.planning/research/PITFALLS.md`

### Tertiary (LOW confidence)
- None.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Verified official packages (`dio 5.11.1`, `http 1.6.0`) and Dart SDK primitives.
- Architecture: HIGH — Validated against existing Phase 1 models and Phase 2 SQLite persistence.
- Pitfalls: HIGH — Root causes identified for single-subscription stream draining, `HttpOverrides` clobbering, and interceptor duplication.

**Research date:** 2026-11-01  
**Valid until:** 2026-12-01 (stable Dart/Flutter ecosystem)  
