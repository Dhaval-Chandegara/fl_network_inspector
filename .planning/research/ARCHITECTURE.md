# Architecture Research

**Domain:** Flutter In-App Network Inspection & Diagnostics Package
**Researched:** 2026-10-31
**Confidence:** MEDIUM (Dart core HTTP mechanisms and sqflite patterns verified against official Dart/Flutter specifications and production package benchmarks)

---

## Standard Architecture

In Flutter and Dart mobile ecosystems, in-app network inspection tools (such as Chucker, Alice, and Talker) intercept HTTP/HTTPS traffic at multiple layers of the networking stack, normalize heterogeneous request/response payloads into a unified domain representation, persist records asynchronously in an embedded database (SQLite), and expose an in-app Material UI driven by reactive state and hardware triggers (shake detection).

The architecture is divided into five decoupled layers:
1. **Public Facade & Configuration Layer** (single point of contact; runtime toggle & safe production no-op)
2. **Interception & Ingestion Layer** (`HttpOverrides` wrapper, client adapters for `Dio` / `http`, manual logging API, redaction engine, payload size limiter)
3. **Domain & Data Pipeline Layer** (immutable models, serialization, sanitization, event stream)
4. **Storage & Persistence Layer** (abstract repository, SQLite engine, indexed queries, write buffer, auto-pruning)
5. **Presentation & Interaction Layer** (Material UI, infinite scroll pagination, syntax viewer, cURL/HAR export, shake detector)

### System Overview

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                 HOST APPLICATION                                       │
│   ┌───────────────────────────┐    ┌───────────────────────────┐    ┌──────────────┐   │
│   │ Dio / Http Package Client │    │ Raw dart:io HttpClient    │    │ Manual Logs  │   │
└─────┬───────────────────────────────┬─────────────────────────────────┬────────────────┘
      │ (Interceptor / Adapter)       │ (HttpOverrides Chaining)        │ (logApi)
      ▼                               ▼                                 ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        INTERCEPTION & INGESTION LAYER                                  │
│ ┌──────────────────────────┐  ┌──────────────────────────┐  ┌────────────────────────┐ │
│ │ NetworkInspectorDio      │  │ NetworkInspectorHttp     │  │ NetworkInspector       │ │
│ │ Interceptor              │  │ Overrides & Stream Taps │  │ Manual Logging API    │ │
│ └────────────┬─────────────┘  └────────────┬─────────────┘  └────────────┬───────────┘ │
│              │ Duplicate Marker Filter     │                             │             │
│              └──────────────────────┬──────┴─────────────────────────────┘             │
│                                     ▼                                                  │
│                        ┌────────────────────────┐                                      │
│                        │ Sanitizer & Redaction  │ (Header/Body Token Masking)          │
│                        │ & Payload Truncator    │ (Max Body Size Bounds)               │
│                        └────────────┬───────────┘                                      │
├─────────────────────────────────────┼──────────────────────────────────────────────────┤
│                        DOMAIN & EVENT PIPELINE                                         │
│                                     ▼                                                  │
│                        ┌────────────────────────┐                                      │
│                        │  NetworkRecord Model   │ (Normalized Immutable Entity)        │
│                        └────────────┬───────────┘                                      │
│                                     ├──────────────────────────────────┐               │
│                                     ▼                                  ▼               │
│                        ┌────────────────────────┐         ┌──────────────────────────┐ │
│                        │   Write Buffer Queue   │         │ Event Bus (Broadcast)    │ │
│                        └────────────┬───────────┘         └────────────┬─────────────┘ │
├─────────────────────────────────────┼──────────────────────────────────┼───────────────┤
│                        STORAGE & REPOSITORY LAYER                      │               │
│                                     ▼                                  │               │
│ ┌───────────────────────────────────────────────────────────────────┐  │               │
│ │              NetworkInspectorRepository (Interface)               │  │               │
│ └───────────────────────────────────┬───────────────────────────────┘  │               │
│                                     ▼                                  │               │
│ ┌───────────────────────────────────────────────────────────────────┐  │               │
│ │              SQLiteNetworkInspectorRepository                     │  │               │
│ │  - Schema Migrations      - Retention / Auto-Prune (maxRecords)   │  │               │
│ │  - Indexed Queries (timestamp, status, method, duration)          │  │               │
│ └───────────────────────────────────┬───────────────────────────────┘  │               │
├─────────────────────────────────────┼──────────────────────────────────┼───────────────┤
│                        PRESENTATION & INSPECTOR UI LAYER               │               │
│                                     │ (Async Paginated Queries)        │ (Live Events) │
│                                     ▼                                  ▼               │
│ ┌────────────────────────────────────────────────────────────────────────────────────┐ │
│ │ Inspector Controller / State Store (ChangeNotifier / ValueNotifier)                │ │
│ └───────────────────────────────────┬────────────────────────────────────────────────┘ │
│                                     ▼                                                  │
│ ┌──────────────────────────┐  ┌──────────────────────────┐  ┌────────────────────────┐ │
│ │ API Listing Screen       │  │ API Details Screen       │  │ Native Share Sheet     │ │
│ │ - Search & Filter Chips  │  │ - Multi-tab Viewer       │  │ - cURL / HAR Export    │ │
│ │ - Infinite Scroll List   │  │ - Formatted JSON Viewer  │  │ - Sensitive Data Redact│ │
│ └──────────────────────────┘  └──────────────────────────┘  └────────────────────────┘ │
├────────────────────────────────────────────────────────────────────────────────────────┤
│                        HARDWARE & NAVIGATION TRIGGERS                                  │
│ ┌─────────────────────────────────────────┐  ┌───────────────────────────────────────┐ │
│ │ ShakeDetector (sensors_plus)            │  │ NetworkInspector.open(context)        │ │
│ │ - Threshold calculation & debounce gate │  │ NetworkInspectorWrapper               │ │
│ └─────────────────────────────────────────┘  └───────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| **`NetworkInspector` (Facade)** | Single entry point for initialization, configuration access, manual API logging, and programmatic UI navigation. Operates as a strict zero-overhead no-op when disabled. | Static class or singleton holding references to config, repository, event bus, and navigation key. |
| **`NetworkInspectorConfig`** | Configuration model holding toggles (`enabled`, `enableAutoCapture`, `enableShakeDetection`, `enableDatabase`), retention bounds (`maxRecords`), payload limits (`maxBodyBytes`), and redaction rules. | Immutable Dart data class with `copyWith` and sane defaults. |
| **`NetworkInspectorHttpOverrides`** | Intercepts standard `dart:io` HTTP calls globally without breaking existing overrides; delegates to wrapped `HttpClient`. | Subclasses `HttpOverrides`, preserves `_previous = HttpOverrides.current`, instantiates custom `HttpClient`. |
| **`NetworkInspectorHttpClient` & Wrappers** | Wraps `HttpClient`, `HttpClientRequest`, and `HttpClientResponse`. Taps payload streams without consuming or cancelling them. | Decorator pattern forwarding `IOSink` calls for requests and applying `StreamTransformer` on responses. |
| **`NetworkInspectorDioInterceptor`** | Interceptor for `Dio` network clients; captures rich metadata (FormData, query parameters, timing, errors). | Extends `Interceptor` from `package:dio`. Adds deduplication marker to prevent duplicate capture by `HttpOverrides`. |
| **`NetworkInspectorHttpClient` (package:http)** | Client wrapper for standard `package:http` calls. | Extends `http.BaseClient`, intercepts `send(BaseRequest)`. |
| **`RedactionEngine`** | Sanitizes sensitive tokens, passwords, authorization headers, and cookie data before persistence. | Case-insensitive regex and JSON-path matching replacing values with `***REDACTED***`. |
| **`NetworkRecord`** | Canonical domain entity representing an HTTP request/response transaction lifecycle. | Immutable Dart model with UUID, timestamps, status, duration, headers, sanitized bodies, and error details. |
| **`NetworkInspectorRepository`** | Abstract persistence interface decoupling data consumer logic from the underlying storage technology. | Pure Dart abstract interface defining `saveRecord`, `updateRecord`, `getRecords`, `getRecordById`, and `clearAll`. |
| **`SQLiteNetworkInspectorRepository`** | SQLite implementation providing schema versioning, indexed queries, paginated batch reads, and auto-pruning. | Backed by `sqflite` (mobile) / `sqflite_common_ffi` (desktop/unit testing) with WAL mode enabled. |
| **`WriteBufferQueue`** | Batches frequent network events during high-throughput bursts to prevent SQLite thread lock and UI jank. | Asynchronous micro-batch queue draining via transactions. |
| **`ShakeDetector`** | Monitors device accelerometer to detect deliberate shaking gestures and trigger the inspector overlay. | Subscribes to `sensors_plus` stream; applies vector magnitude threshold ($g = \sqrt{x^2+y^2+z^2}$) and debounce timers. |
| **`InspectorListingView`** | Displays captured network transactions with status badges, method tags, search bar, and filter chips. | Flutter `StatefulWidget` or `StatelessWidget` with `ListView.builder` supporting infinite scroll pagination. |
| **`InspectorDetailView`** | Presents deep diagnostic inspection with tabs for Overview, Headers, Query Params, Request/Response Body, Multipart Info, and Stacktrace. | Flutter `DefaultTabController` with tabs, syntax-highlighted JSON viewer, raw/formatted toggle, and copy buttons. |
| **`ExportService`** | Formats captured network transactions into exportable representations (cURL command, JSON summary, HAR file) and opens native share sheet. | Text formatter converting `NetworkRecord` into cURL/HAR, invoking `share_plus`. |

---

## Recommended Project Structure

```
lib/
├── flutter_network_inspector.dart    # Main public barrel export
└── src/
    ├── core/                         # Facade, configuration, and constants
    │   ├── network_inspector.dart    # Public static facade API
    │   ├── network_inspector_config.dart # Configuration model & builder
    │   ├── event_bus.dart            # Reactive broadcast stream for real-time UI updates
    │   └── constants.dart            # Internal constants, default limits, deduplication headers
    │
    ├── domain/                       # Core domain entities and contracts (Pure Dart)
    │   ├── models/
    │   │   ├── network_record.dart   # Canonical transaction model
    │   │   ├── multipart_entry.dart  # Metadata-only model for multipart attachments
    │   │   ├── record_filter.dart    # Query filter criteria (status, method, error, date)
    │   │   └── record_sort.dart      # Sorting definitions (newest, duration, status)
    │   ├── repository/
    │   │   └── network_inspector_repository.dart # Abstract persistence contract
    │   └── redaction/
    │       ├── redaction_engine.dart # Masking engine for sensitive data
    │       └── redaction_rule.dart   # Pattern/key matcher definitions
    │
    ├── interception/                 # Network capture implementations
    │   ├── http_overrides/           # Global dart:io interception
    │   │   ├── inspector_http_overrides.dart # Chained HttpOverrides implementation
    │   │   ├── inspector_http_client.dart    # Wrapped HttpClient
    │   │   ├── inspector_http_request.dart   # Wrapped HttpClientRequest (IOSink delegate)
    │   │   └── inspector_http_response.dart  # Wrapped HttpClientResponse (StreamTransformer)
    │   ├── adapters/                 # Dedicated 3rd-party client adapters
    │   │   ├── dio_interceptor.dart  # NetworkInspectorDioInterceptor
    │   │   └── http_client_adapter.dart # NetworkInspectorHttpClient (package:http wrapper)
    │   ├── manual/
    │   │   └── manual_logger.dart    # Manual logging implementation (logApi/logRequest)
    │   └── utils/
    │       ├── stream_tee.dart       # Non-destructive StreamTransformer utilities
    │       └── deduplication_registry.dart # Prevents duplicate capture across nested interceptors
    │
    ├── storage/                      # SQLite persistence and query engine
    │   ├── sqlite_repository.dart    # SQLiteNetworkInspectorRepository
    │   ├── database_helper.dart      # Database initialization, schema setup, WAL mode
    │   ├── migrations/               # Schema versioning and migration scripts
    │   │   └── migration_v1.dart
    │   ├── write_buffer.dart         # Micro-batching queue for SQLite writes
    │   └── retention_manager.dart    # Auto-cleanup worker enforcing maxRecords limit
    │
    ├── presentation/                 # Flutter UI Layer
    │   ├── controllers/
    │   │   └── inspector_controller.dart # UI state management (pagination, filters, search)
    │   ├── screens/
    │   │   ├── listing_screen.dart   # API requests list screen
    │   │   └── detail_screen.dart    # Multi-tab request/response detail screen
    │   ├── widgets/
    │   │   ├── json_viewer.dart      # Pretty-printed formatted JSON viewer
    │   │   ├── filter_modal.dart     # Filter & sorting bottom sheet / dialog
    │   │   ├── status_badge.dart     # HTTP status code badge (2xx green, 4xx/5xx red)
    │   │   └── copy_button.dart      # Clipboard action button with SnackBar feedback
    │   └── navigation/
    │       └── inspector_navigator.dart # Programmatic router & overlay manager
    │
    ├── triggers/                     # Hardware and user gesture triggers
    │   ├── shake_detector.dart       # Accelerometer shake listener via sensors_plus
    │   └── network_inspector_wrapper.dart # Optional root wrapper widget
    │
    └── utils/                        # Formatting, cURL generation, and sharing
        ├── curl_formatter.dart       # Converts NetworkRecord to cURL command string
        ├── export_formatter.dart     # Formats record to HAR or diagnostic markdown
        └── share_helper.dart         # Invokes share_plus native sheet
```

### Structure Rationale

- **`core/` vs `domain/`:** Decouples the package configuration and public facade from core domain models (`NetworkRecord`). Domain models have zero dependencies on Flutter UI or `dart:io`, ensuring they can be unit-tested without mocks.
- **`interception/` isolation:** All networking hooks are isolated into dedicated subdirectories. The `http_overrides/` implementation relies only on `dart:io`, while `adapters/` can optionally integrate with `Dio` or `package:http`.
- **`storage/` abstracted behind `domain/repository/`:** The UI never calls SQLite directly. It queries the abstract `NetworkInspectorRepository`. This enables swap-in mock repositories for fast widget tests without spinning up SQLite FFI binaries.
- **`presentation/` decoupled from interception:** The UI only reads from the repository and listens to real-time events on the `EventBus`. Interceptors do not know or care whether the UI is open.
- **`triggers/` independent module:** Hardware sensors (`sensors_plus`) are completely separated from networking logic so apps on unsupported platforms (or test environments) can disable shake detection without touching network inspection.

---

## Architectural Patterns

### Pattern 1: Non-Destructive Stream Interception via `StreamTransformer`

**What:** In `dart:io`, `HttpClientResponse` is a single-subscription `Stream<List<int>>`. If an inspector reads the response body directly using `await response.toList()` or `response.transform()`, the host application's attempt to read the stream throws a runtime `StateError: Stream has already been listened to`.
**When to use:** Whenever intercepting incoming HTTP response bodies or outgoing streaming request bodies in `dart:io`.
**Trade-offs:** Buffering chunks consumes transient RAM proportional to payload size; mitigated by enforcing a strict maximum capture limit (e.g., 1MB) and ignoring binary streams if specified.

**Example:**
```dart
import 'dart:async';
import 'dart:io';

class InspectorHttpResponseStreamTransformer {
  static Stream<List<int>> create({
    required Stream<List<int>> sourceStream,
    required int maxBodyBytes,
    required void Function(List<int> bufferedBytes) onComplete,
    required void Function(Object error, StackTrace stackTrace) onError,
  }) {
    final buffer = <int>[];
    var isTruncated = false;

    final transformer = StreamTransformer<List<int>, List<int>>.fromHandlers(
      handleData: (List<int> chunk, EventSink<List<int>> sink) {
        // 1. Pass data immediately downstream so host app experiences zero latency
        sink.add(chunk);

        // 2. Buffer data up to configured limit
        if (!isTruncated) {
          if (buffer.length + chunk.length <= maxBodyBytes) {
            buffer.addAll(chunk);
          } else {
            final remainingCapacity = maxBodyBytes - buffer.length;
            if (remainingCapacity > 0) {
              buffer.addAll(chunk.sublist(0, remainingCapacity));
            }
            isTruncated = true;
          }
        }
      },
      handleError: (error, stackTrace, sink) {
        sink.addError(error, stackTrace);
        onError(error, stackTrace);
      },
      handleDone: (EventSink<List<int>> sink) {
        sink.close();
        onComplete(buffer);
      },
    );

    return sourceStream.transform(transformer);
  }
}
```

---

### Pattern 2: Safe `HttpOverrides` Chaining

**What:** Assigning `HttpOverrides.global = MyOverrides()` wipes out any pre-existing global overrides (such as custom SSL certificate validators, corporate proxies, or OpenTelemetry tracers). Calling `HttpClient()` inside `createHttpClient` causes an infinite loop (`StackOverflowError`) because it recursively looks up the current override.
**When to use:** During `NetworkInspector.initialize()` when `enableAutoCapture: true`.
**Trade-offs:** Requires defensive null-checking on the previous override; if previous overrides have unexpected custom behaviors, they must be faithfully preserved.

**Example:**
```dart
import 'dart:io';

class NetworkInspectorHttpOverrides extends HttpOverrides {
  // Capture the override that was active immediately prior to this initialization
  final HttpOverrides? _previous = HttpOverrides.current;
  final HttpClient Function(HttpClient client) _wrapper;

  NetworkInspectorHttpOverrides({
    required HttpClient Function(HttpClient client) wrapper,
  }) : _wrapper = wrapper;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    // 1. Delegate client creation to previous override, or fallback to super
    final HttpClient baseClient = _previous != null
        ? _previous!.createHttpClient(context)
        : super.createHttpClient(context);

    // 2. Wrap client with network inspector proxy
    return _wrapper(baseClient);
  }

  @override
  String findProxyFromEnvironment(Uri url, Map<String, String>? environment) {
    if (_previous != null) {
      return _previous!.findProxyFromEnvironment(url, environment);
    }
    return super.findProxyFromEnvironment(url, environment);
  }
}
```

---

### Pattern 3: Deduplication via Synthetic Internal Header Marker

**What:** When both `HttpOverrides.global` and `NetworkInspectorDioInterceptor` (or `NetworkInspectorHttpClient`) are active, the high-level client invokes the underlying `dart:io HttpClient`. Without deduplication, both interceptors will capture the same network call, creating duplicate entries in SQLite.
**When to use:** In all higher-level adapters (`Dio`, `package:http`) before passing requests to the transport socket.
**Trade-offs:** Adds a lightweight internal header that must be filtered out before the raw bytes leave the device, or recognized and ignored by the `HttpOverrides` layer.

**Example:**
```dart
class InterceptorConstants {
  static const String internalTrackingHeader = 'x-fl-net-inspector-tracked-id';
}

// In NetworkInspectorDioInterceptor:
@override
void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
  final requestId = Uuid().v4();
  // Tag request with internal tracking ID
  options.headers[InterceptorConstants.internalTrackingHeader] = requestId;
  // Log request to inspector repository...
  handler.next(options);
}

// In NetworkInspectorHttpClientRequest (HttpOverrides wrapper):
@override
Future<HttpClientResponse> close() async {
  // Check if higher-level adapter has already claimed this request
  if (headers.value(InterceptorConstants.internalTrackingHeader) != null) {
    // Strip header before transmission so backend server never receives it
    headers.removeAll(InterceptorConstants.internalTrackingHeader);
    // Let request proceed through socket WITHOUT logging duplicate entry
    return _innerRequest.close();
  }

  // Not tracked yet: proceed with full HttpOverrides capture & logging
  return _performLoggedClose();
}
```

---

### Pattern 4: Abstract Repository with Non-Blocking Asynchronous SQLite

**What:** Decouples storage operations behind `NetworkInspectorRepository`. Uses SQLite WAL mode (Write-Ahead Logging) and an in-memory batch write buffer so heavy network bursts never block the Flutter UI thread.
**When to use:** For all persistence operations.
**Trade-offs:** Slight delay (e.g. 50-100ms debounce) before bursts are flushed to disk, but UI maintains a consistent 60/120 fps.

**Example:**
```dart
abstract class NetworkInspectorRepository {
  Future<void> saveRecord(NetworkRecord record);
  Future<void> updateRecord(NetworkRecord record);
  Future<List<NetworkRecord>> getRecords({
    RecordFilter? filter,
    RecordSort? sort,
    int limit = 20,
    int offset = 0,
  });
  Future<NetworkRecord?> getRecordById(String id);
  Future<void> clearAll();
  Future<int> getRecordCount();
}
```

---

## Data Flow

### Request Flow (Capture to Persistence)

```
[ App Code (e.g. Dio.get() / http.post()) ]
       │
       ▼
[ Interceptor / Adapter ] ──► Injects Tracking Header
       │
       ▼
[ Redaction Engine ] ──► Masks Passwords, Tokens, API Keys
       │
       ▼
[ NetworkRecord Entity Created ] (Status: Pending, Timestamp: Now)
       │
       ├─────────────────────────────────────────┐
       ▼                                         ▼
[ EventBus.emit(onRequestStarted) ]     [ WriteBufferQueue.enqueue() ]
       │                                         │
       │ (Real-time UI notification)             ▼ (Async batch transaction)
       ▼                                [ SQLiteDatabase.insert() ]
[ Active UI / Notification Updates ]             │
                                                 ▼
                                        [ Retention Check ] (if count > maxRecords, prune)
```

### Response Flow (Network to Completion)

```
[ Remote Server / Socket Response Chunks ]
       │
       ▼
[ InspectorHttpResponseStreamTransformer ]
       │
       ├──► 1. Yield chunk immediately to host app (No delay)
       │
       └──► 2. Append chunk to bounded in-memory buffer (up to maxBodyBytes)
                   │
                   ▼ (On Stream Done / Close)
       [ Redaction Engine ] (Sanitizes JSON response fields)
                   │
                   ▼
       [ NetworkRecord Entity Updated ] (Status: 200, Duration: 142ms, Body: sanitized)
                   │
       ┌───────────┴─────────────────────────────┐
       ▼                                         ▼
[ EventBus.emit(onResponseReceived) ]   [ WriteBufferQueue.enqueueUpdate() ]
       │                                         │
       ▼                                         ▼
[ Inspector UI Updates Live ]           [ SQLiteDatabase.update() ]
```

### Key Data Flows

1. **Interception to Persistence Flow:**
   - Client issues HTTP call.
   - Interceptor records method, URI, request headers, query parameters, request body (redacted).
   - `NetworkRecord` inserted as `pending`.
   - On completion/error, response headers, response body (redacted), duration, status code, and error trace are calculated and updated.
   - Transaction is written to SQLite via asynchronous write queue.
2. **Querying & Filtering Flow:**
   - User opens inspector or applies filter (e.g., status 400-500, method POST, query "checkout").
   - `InspectorController` sends `RecordFilter(statusCodes: [400..500], method: 'POST', query: 'checkout')` with `limit: 20, offset: 0` to `NetworkInspectorRepository`.
   - SQLite queries indexed columns (`WHERE status_code BETWEEN 400 AND 500 AND method = 'POST'`) using paginated SQL `LIMIT 20 OFFSET 0`.
   - Returns lightweight `List<NetworkRecord>` (excluding huge body fields for listing performance if needed).
3. **Manual Logging & Sharing Flow:**
   - Developer calls `NetworkInspector.logApi(...)` with custom payloads.
   - Payload passes through `RedactionEngine` and enters the standard persistence pipeline.
   - In UI, user taps "Export": `ExportService` loads full record, formats into cURL or HAR, and prompts native `share_plus` sheet.

---

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| **0 - 500 records** (Default dev session) | Standard SQLite single-table storage; in-memory listing fits comfortably within Flutter heap without strain. Direct queries execute in < 5ms. |
| **500 - 5,000 records** (Long QA / E2E test runs) | Enforce `maxRecords` pruning (e.g., limit default = 1,000). Index columns (`timestamp DESC`, `status_code`, `method`). Use paginated `LIMIT / OFFSET` in `ListView.builder` to prevent loading all rows into RAM. |
| **High-Throughput Bursts** (50+ simultaneous requests, e.g. sync/images) | Activate `WriteBufferQueue` (micro-batching 50ms intervals). Skip capturing raw image bytes for binary content-types (`image/*`, `application/octet-stream`). Truncate payloads at `maxBodyBytes` (1MB). Enable SQLite WAL mode (`PRAGMA journal_mode=WAL;`). |

### Scaling Priorities

1. **First bottleneck — Memory exhaustion from large responses/files:**
   Downloading a 50MB file or inspecting video streams will crash the app if buffered into memory as strings.
   *Mitigation:* Check `content-type` and `content-length`. If binary or non-text, log size metadata only. Impose a hard ceiling (`maxBodyBytes`, default 1MB) on body buffering.
2. **Second bottleneck — SQLite thread locking & UI frame drops during bursts:**
   Making 20 concurrent HTTP requests can fire 40 simultaneous SQLite insert/update calls, causing micro-jank on the main thread.
   *Mitigation:* Batch database writes through a debounced queue; configure SQLite in Write-Ahead Logging mode (`WAL`).
3. **Third bottleneck — Database file unbounded growth:**
   Leaving the inspector active over days of continuous QA testing could bloat app storage to gigabytes.
   *Mitigation:* Periodic asynchronous cleanup query deleting rows older than retention limits or exceeding `maxRecords`.

---

## Anti-Patterns

### Anti-Pattern 1: Direct Stream Consumption on `HttpClientResponse`

**What people do:**
```dart
// ❌ WRONG
final response = await client.getUrl(url).then((req) => req.close());
final bodyString = await response.transform(utf8.decoder).join(); // Consumes the stream!
return response; // Caller app will throw Bad state: Stream has already been listened to!
```
**Why it's wrong:** Dart sockets are single-subscription streams. Consuming the stream in the interceptor starves the host application and causes catastrophic runtime crashes.
**Do this instead:** Wrap `HttpClientResponse` with a non-destructive `StreamTransformer` that emits data chunks to the caller while collecting a copy in an internal buffer.

---

### Anti-Pattern 2: Overwriting `HttpOverrides.global` Blindly

**What people do:**
```dart
// ❌ WRONG
HttpOverrides.global = NetworkInspectorHttpOverrides(); // Erases existing proxy or SSL config!
```
**Why it's wrong:** Wipes out pre-configured network overrides (e.g. proxying tools, corporate certificate bypasses, or third-party SDK overrides).
**Do this instead:** Capture `final previous = HttpOverrides.current` and delegate `createHttpClient(context)` to `previous` if non-null.

---

### Anti-Pattern 3: Synchronous / Unbuffered SQLite Writes on Network Bursts

**What people do:**
```dart
// ❌ WRONG
void onChunkReceived(List<int> chunk) async {
  await db.rawUpdate('UPDATE records SET current_size = ...'); // Fires on every TCP packet!
}
```
**Why it's wrong:** Saturates the database thread, causing frame drops and UI stutter during rapid scrolling or concurrent network activity.
**Do this instead:** Update in-memory state; commit to SQLite only on request completion (`done`) or through a debounced batch writer.

---

### Anti-Pattern 4: Storing Binary Multipart File Blobs in SQLite

**What people do:**
```dart
// ❌ WRONG
await db.insert('records', {'file_bytes': multipartFileBytes}); // Bloats SQLite DB into hundreds of MBs
```
**Why it's wrong:** SQLite database bloat, disk exhaustion, slow query response times, and possible Out-Of-Memory (OOM) crashes when querying the database.
**Do this instead:** Extract metadata only (`fileName`, `fieldName`, `mimeType`, `fileSizeInBytes`) and store as structured JSON. Never write raw uploaded file bytes to SQLite.

---

## Integration Points

### External Ecosystem Clients

| Ecosystem Client | Integration Pattern | Notes |
|------------------|---------------------|-------|
| **`dart:io` `HttpClient`** | `HttpOverrides.global` with wrapper client | Primary automatic capture mechanism. Requires chaining to avoid overriding existing configurations. Not supported on Flutter Web. |
| **`package:dio`** | `NetworkInspectorDioInterceptor` added to `dio.interceptors` | Explicit adapter capturing `FormData`, query params, and typed errors. Emits deduplication marker. |
| **`package:http`** | `NetworkInspectorHttpClient(http.Client())` | Client wrapper intercepting `send()`. Transparently proxies requests and tags with deduplication marker. |
| **`sensors_plus`** | Accelerometer event stream listener | Gracefully disables shake listener if sensors are unsupported or unavailable on the target platform. |
| **`share_plus`** | Platform native share sheet | Used for cURL and diagnostic report export. Excludes redacted fields from exported text. |

### Internal Boundaries

| Boundary | Communication Method | Architectural Guarantee |
|----------|----------------------|-------------------------|
| **Interceptors ↔ Redaction Engine** | Direct synchronous method call | Payloads are sanitized before any object reaches storage or event streams. |
| **Interceptors ↔ Repository** | Asynchronous method call via `NetworkInspectorRepository` | Interceptors do not know about SQLite; repository interface handles persistence. |
| **Interceptors ↔ UI** | Decoupled via `EventBus` (`Stream<NetworkRecord>`) | Interception operates identically whether UI is mounted, minimized, or not yet initialized. |
| **UI ↔ Repository** | Asynchronous paginated queries (`getRecords`) | UI never loads full dataset into memory; queries are bounded by `limit` and `offset`. |
| **Shake Detector ↔ Navigator** | Callback via `GlobalKey<NavigatorState>` | Triggers `Navigator.push` safely; guards against duplicate modal pushes if inspector is already visible. |

---

## Suggested Build Order

To minimize rework and guarantee testability at each milestone, components must be constructed in order of strict dependency hierarchy:

```
┌────────────────────────────────────────────────────────┐
│  Phase 1: Core Foundation & Domain Models              │
│  - NetworkRecord, Filter, Sort, Config models          │
│  - RedactionEngine & Payload Truncator                 │
└──────────────────────────┬─────────────────────────────┘
                           ▼
┌────────────────────────────────────────────────────────┐
│  Phase 2: Storage & Repository Layer (SQLite)          │
│  - Abstract Repository & SQLite Implementation         │
│  - Schema, Indexing, Auto-Prune (maxRecords)           │
│  - WriteBuffer micro-batching                          │
└──────────────────────────┬─────────────────────────────┘
                           ▼
┌────────────────────────────────────────────────────────┐
│  Phase 3: Interception Engine & Client Adapters        │
│  - Safe HttpOverrides Chaining & Stream Transformers   │
│  - Dio Interceptor & package:http Client Adapter       │
│  - Deduplication Registry & Manual Logging API         │
└──────────────────────────┬─────────────────────────────┘
                           ▼
┌────────────────────────────────────────────────────────┐
│  Phase 4: Presentation & Inspector UI                  │
│  - Listing Screen (Infinite Scroll, Filter, Sort)      │
│  - Details Screen (Tabs, Pretty JSON, Copy, cURL/HAR)  │
│  - Native Share Sheet Export (share_plus)              │
└──────────────────────────┬─────────────────────────────┘
                           ▼
┌────────────────────────────────────────────────────────┐
│  Phase 5: Entry Triggers, Shake Detection & Facade     │
│  - ShakeDetector (sensors_plus) & Navigation Key       │
│  - NetworkInspector Facade & No-op release toggle      │
│  - End-to-End Integration Tests & Example App          │
└────────────────────────────────────────────────────────┘
```

### Build Sequence Rationale

1. **Phase 1: Core Foundation & Domain Models**
   - *Why first:* The `NetworkRecord` domain model and `RedactionEngine` have zero external dependencies. They form the canonical data language shared across interception, storage, and UI. Building these first allows immediate unit testing of redaction rules and payload formatting.
2. **Phase 2: Storage & Repository Layer**
   - *Why second:* Interception engines need somewhere to deposit records, and UI needs a source to query. Building the SQLite repository with schema indexing and pruning enables persistence verification using mock records before hooking into real network sockets.
3. **Phase 3: Interception Engine & Client Adapters**
   - *Why third:* With domain models and storage in place, network interception can be implemented and thoroughly verified via integration tests against local HTTP test servers (`HttpServer.bind`). Stream safety and deduplication can be validated without needing a UI.
4. **Phase 4: Presentation & Inspector UI**
   - *Why fourth:* Building the UI against an existing SQLite repository with real or mocked `NetworkRecord` entries ensures developer tools (syntax viewer, pagination, copy actions, share sheet) can be visually tested and refined with realistic network traffic.
5. **Phase 5: Entry Triggers, Shake Detection & Facade Integration**
   - *Why fifth:* Ties the system together: hardware triggers (`sensors_plus`), programmatic navigation (`NetworkInspector.open`), global initialization, and release-mode no-op guarantees. Final delivery includes the complete example application and end-to-end integration tests.

---

## Sources

- [Dart official `dart:io` documentation on `HttpOverrides`](https://api.dart.dev/stable/dart-io/HttpOverrides-class.html) — High confidence
- [Dart official `StreamTransformer` documentation](https://api.dart.dev/stable/dart-async/StreamTransformer-class.html) — High confidence
- [Flutter SQLite documentation (`sqflite`)](https://pub.dev/packages/sqflite) — High confidence
- [Chucker Flutter GitHub repository architecture & patterns](https://github.com/chuckerteam/chucker_flutter) — Verified / Medium confidence
- [Flutter Alice architecture & stream inspection patterns](https://github.com/jhomlala/alice) — Verified / Medium confidence
- [Dio Interceptors documentation](https://pub.dev/packages/dio#interceptors) — High confidence

---
*Architecture research for: Flutter Network Inspector Package (`flutter_network_inspector`)*  
*Researched: 2026-10-31*
