# Feature Research: Flutter Network Inspector Package

**Domain:** Flutter In-App Network Inspection & Diagnostics Package  
**Researched:** 2026-10-31  
**Confidence:** HIGH (Cross-verified against pub.dev prior art: `chucker_flutter`, `alice`/`flutter_alice`, `talker_flutter`/`talker_dio_logger_plus`, `requests_inspector`, desktop proxy benchmarks from Proxyman/Charles, and GitHub issue trackers)

---

## Executive Overview

In modern Flutter application development, network inspection is vital for debugging API integrations, validating payloads, verifying authentication headers, and diagnosing performance bottlenecks. Historically, developers have relied on desktop proxy tools (Charles Proxy, Proxyman, Fiddler) or existing Flutter in-app packages (`alice`, `chucker_flutter`, `requests_inspector`). 

However, existing Flutter in-app tools suffer from critical architectural weaknesses:
- **Memory crashes:** `chucker_flutter` persists logs into `SharedPreferences` or unbounded in-memory caches, triggering Android `OutOfMemoryError` (OOM) on large payloads or heavy traffic.
- **Stream consumption errors:** Both `chucker_flutter` and `alice` frequently fail when handling chunked responses, Server-Sent Events (SSE), or stream downloads, throwing `Bad state: Stream has already been listened to`.
- **Global override conflicts:** Standard packages overwrite `HttpOverrides.global` destructively, breaking self-signed SSL certificates, corporate proxies, and crash reporting SDKs (Sentry, Firebase).
- **Security vulnerabilities:** Lack of robust, out-of-the-box data sanitization results in sensitive authentication tokens and PII leaking into device logs and exports.

`flutter_network_inspector` positions itself as the **reliable, production-safe, zero-crash network inspector** for Flutter. It solves the pain points of existing packages by combining transparent stream splitting, safe `HttpOverrides` chaining, indexed asynchronous SQLite storage with automated FIFO pruning, configurable PII redaction, and deep export capabilities (cURL and HAR).

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist in any modern network inspection tool. Missing any of these makes the package feel broken or incomplete compared to standard developer workflows.

| Feature | Why Expected | Complexity | Implementation Notes |
|---------|--------------|------------|----------------------|
| **Automatic HTTP Interception (`dart:io`)** | Developers expect zero-configuration network capture across all standard Dart HTTP calls without manually wrapping every single call. | HIGH | Implemented via `HttpOverrides` chaining and custom `HttpClient`, `HttpClientRequest`, and `HttpClientResponse` proxy wrappers. Must non-destructively split byte streams. |
| **Dedicated Dio Client Interceptor** | Dio is the dominant third-party HTTP client in Flutter (>60% market share). Developers expect a clean `dio.interceptors.add(...)` integration. | MEDIUM | Dedicated `NetworkInspectorDioInterceptor` hooking into `onRequest`, `onResponse`, and `onError`. Captures query params, form data, headers, and cancellation errors. |
| **Dedicated `package:http` Adapter** | Official Dart team HTTP library. Must provide a drop-in client wrapper for apps not using Dio. | MEDIUM | `NetworkInspectorHttpClient` wrapping `http.BaseClient`, capturing outgoing `BaseRequest` and intercepting `StreamedResponse` without double-draining the stream. |
| **Comprehensive Transaction Metadata** | Essential debugging context: HTTP method, full URL, path, query parameters, status code, status message, request/response headers, timestamp, duration (latency in ms), and payload size. | LOW | Normalized into an immutable `NetworkRecord` domain model with strongly-typed properties and ISO 8601 timestamps. |
| **Tabbed Details Inspector UI** | Developers need organized, distraction-free views to inspect distinct facets of a network transaction. | MEDIUM | Material 3 inspector view featuring organized tabs: Overview, Request Headers, Query Parameters, Request Body, Response Headers, Response Body, and Error Details. |
| **Status Code Color Coding & Badges** | Instant visual triage in the request list: green (2xx), blue (3xx), orange (4xx), red (5xx), magenta (network errors/timeouts). | LOW | Standard visual badges displayed on list tiles and details screen headers for quick recognition. |
| **Pretty-Printed JSON Viewer** | Raw minified JSON is unreadable on mobile screens; formatted indentation with syntax readability is mandatory. | MEDIUM | Structured JSON formatter with indentation, syntax-friendly styling, and a one-tap toggle between **Formatted** and **Raw** string view. Must handle deep trees without `RenderFlex` overflow. |
| **Multi-Parameter Search** | Quickly finding a specific call in a list of hundreds of API transactions during an active debugging session. | MEDIUM | Fast text query matching against URL, endpoint path, query parameters, status code, and payload text. |
| **Filter by Method, Status & Errors** | Isolating failing endpoints (e.g., only 4xx/5xx errors) or specific REST verbs (e.g., POST/PUT). | MEDIUM | Multi-select filter chips for HTTP methods (`GET`, `POST`, `PUT`, `DELETE`, `PATCH`), status code bands (`2xx`, `3xx`, `4xx`, `5xx`), and error-only toggle. |
| **Sort by Timestamp & Duration** | Identifying slow API calls causing app lag or reviewing chronological request sequences. | LOW | Sort options: Newest First (default), Oldest First, Slowest Duration (bottlenecks), and Status Code. |
| **Copy to Clipboard (cURL & Payloads)** | Reproducing bugs in Postman, cURL terminal, or sharing request/response bodies with backend engineers. | LOW | Granular copy buttons for: Full cURL command, URL, Request Body, Response Body, and Headers. cURL command must include headers, method, and escaped body. |
| **Native Share Sheet Export** | Quick sharing of network logs to team channels (Slack, Email, Messages, AirDrop) directly from test devices. | LOW | Integrated via `share_plus`. Generates formatted text summaries or export files. Must support `sharePositionOrigin` on iPadOS and desktop to avoid crashes. |
| **Shake-to-Open Gesture** | Opening the inspector on physical devices without cluttering the host app UI with debug buttons. | LOW | Integrated via `sensors_plus` listening to `userAccelerometerEventStream`. Filters out gravity (9.8 m/s²) to eliminate false positives. |
| **Programmatic & Wrapper Launch** | Explicit programmatic invocation for custom debug menus or QA drawer buttons. | LOW | `NetworkInspector.open(context)` and `NetworkInspectorWrapper` widget for seamless overlay integration. |
| **Persistent SQLite Storage** | Logs must survive app backgrounding, hot restarts, and app crashes to inspect pre-crash API failures. | MEDIUM | Asynchronous SQLite database (`sqflite` on mobile/macOS, `sqflite_common_ffi` on desktop/tests). Fully decoupled via repository pattern. |
| **Clear All Logs** | Resetting state between test test-cases or clearing clutter during long QA sessions. | LOW | Database purge action with confirmation dialog, immediately clearing UI state and resetting auto-increment counters. |
| **Production-Safe Master Toggle** | Guaranteeing zero performance impact or data leakage if package code remains in release builds. | LOW | `enabled: false` flag causing all interceptors, stream taps, sensors, and database writes to immediately no-op. |

---

### Differentiators (Competitive Advantage)

Features that distinguish `flutter_network_inspector` from existing solutions (`alice`, `chucker_flutter`, `talker`), addressing real-world pain points and providing unique value.

| Feature | Value Proposition | Complexity | Implementation Notes |
|---------|-------------------|------------|----------------------|
| **Safe `HttpOverrides` Chaining** | **Preserves existing network overrides.** Alice and other tools blindly overwrite `HttpOverrides.global`, breaking corporate proxies, self-signed SSL certs (`badCertificateCallback`), and APM SDKs (Sentry, Firebase). | MEDIUM | Captures `HttpOverrides.current` during initialization and delegates `createHttpClient` and `findProxyFromEnvironment` down the chain, only falling back to base behavior if null. |
| **Non-Destructive Stream Splitting** | **Zero stream consumption crashes.** Prevents `Bad state: Stream has already been listened to` errors during chunked responses, SSE (Server-Sent Events), LLM streaming, and file downloads. | HIGH | Custom dual-forwarding stream splitter that proxies `Stream<List<int>>` chunks to the host application in real time while accumulating a mirrored copy for logging up to the capture limit. |
| **Cross-Interceptor Request Deduplication** | **Eliminates duplicate log records.** If an application enables global `HttpOverrides` AND configures a dedicated `Dio` interceptor, requests are recorded twice in naive tools. | MEDIUM | Attaches an internal correlation tag / header (`x-fl-inspector-id`) to outgoing requests. Interceptors detect existing tags and skip duplicate storage ingestion. |
| **Metadata-Only Multipart Handling** | **Prevents out-of-memory crashes on uploads.** Uploading 10MB–50MB files (images, videos, documents) in other inspectors buffers raw bytes into memory or DB, causing immediate OOM crashes. | MEDIUM | Parses `multipart/form-data` streams to extract field names, file names, MIME types, and file sizes, strictly omitting raw binary file bytes from SQLite storage. |
| **Configurable PII & Data Redaction** | **Production and compliance safe.** Prevents sensitive credentials (Bearer tokens, passwords, cookies, credit cards) from persisting to disk or leaking into exports. | MEDIUM | Rule-based sanitization engine applied before persistence. Redacts configured header keys (case-insensitive) and JSON body fields (recursive key matching) replacing values with `***REDACTED***`. |
| **Bounded Asynchronous Storage with Auto-Pruning (FIFO)** | **Guarantees bounded disk and memory footprint.** Unlike Chucker (which bloats SharedPreferences until the app crashes), storage is strictly capped. | MEDIUM | Enforces configurable `maxRecords` (default: 200) and optional age retention. An automated batch trigger (`DELETE FROM records WHERE id NOT IN (SELECT id ORDER BY timestamp DESC LIMIT maxRecords)`) runs asynchronously. |
| **Configurable Payload Size Ceilings** | **Prevents memory bloat on massive API responses.** Large JSON or text downloads (e.g., 5MB–20MB) are bounded safely. | LOW | Configurable body limit (default: 1MB per body). Payloads exceeding the limit are truncated with a visible indicator (`[Payload truncated: size exceeded 1,048,576 bytes]`). |
| **Public Manual Logging API (`logApi`)** | **Universal protocol support.** Allows logging network traffic from non-HTTP clients, GraphQL (`graphql_flutter`), gRPC metadata, or WebSockets. | LOW | `NetworkInspector.logApi(...)` and `NetworkInspector.logRequest(...)` static methods that construct and persist synthetic `NetworkRecord` entries with full metadata. |
| **HAR (HTTP Archive 1.2) Export** | **Cross-tool interoperability.** QA and developers can export sessions as `.har` files and import them directly into Charles Proxy, Proxyman, Postman, or Chrome DevTools. | MEDIUM | Serializer converting `NetworkRecord` instances into RFC-compliant HTTP Archive 1.2 JSON structures, downloadable or shareable via native share sheet. |
| **Non-Blocking Write Buffer Queue** | **Zero UI frame drops during network bursts.** High-concurrency operations (e.g., sync routines firing 50 requests in parallel) don't lock the UI thread. | MEDIUM | In-memory micro-queue that batches incoming network records and writes them to SQLite in asynchronous batches every 100ms or when the buffer reaches 10 items. |
| **Navigation-Independent UI Wrapper** | **Works with modern declarative routing.** Solves the infamous Alice crash where missing `navigatorKey` crashes apps using `AutoRoute`, `GoRouter`, or nested navigators. | LOW | `NetworkInspectorWrapper` wraps the root widget, hosting an overlay stack that can present the inspector screen directly without requiring a global `NavigatorState` key. |

---

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem appealing on the surface but introduce severe stability, performance, security, or architectural problems. These are explicitly **NOT** built.

| Anti-Feature | Why Requested | Why Problematic | What to Do Instead |
|--------------|---------------|-----------------|-------------------|
| **Raw Binary Body Persistence in SQLite** | Developers want to view downloaded images, PDFs, or audio files directly inside the inspector database. | Storing megabytes of binary BLOBs in SQLite causes rapid database bloat, disk write locks, severe UI jank, and eventual SQLite `DatabaseException` or device OOM crashes. | Store metadata only (content-type, byte size, filename). For small images (<50KB), provide an optional in-memory visual preview thumbnail without persisting raw bytes to SQLite. |
| **Live Request/Response Modification & Mock Server (MITM)** | Developers familiar with Charles Proxy want to tamper with live headers/bodies or mock backend endpoints on the device. | In-app live interception requires blocking asynchronous streams, introduces severe race conditions, breaks app architectural invariants, and creates massive security risks if accidentally shipped to production. | Keep the package strictly an **observer and logger**. Use dedicated mocking tools (e.g. `http_mock_adapter` for Dio) or external desktop proxies (Proxyman) for mock workflows. |
| **Device-Hosted Local Reverse Proxy Daemon** | Attempting to capture non-Flutter traffic (native Android/iOS SDKs, WebViews) by binding a local proxy server on `localhost:8888`. | Requires background service permissions, handling OS socket lifecycle, battery drain, and installing custom CA certificates on the host operating system. Breaks completely on cellular networks. | Use dedicated desktop proxy software (Charles Proxy or Proxyman) when full-device native OS network capture is required. |
| **Network Bandwidth Throttling / Latency Simulation** | QA wants to simulate slow 2G/3G connections directly inside the mobile app. | Dart `HttpClient` operates on native OS sockets. Artificial delays injected at the Dart stream layer frequently trigger native OS socket read timeouts (`SocketException: Connection timed out`), distorting real connection behaviors. | Use native OS network conditioners (iOS Network Link Conditioner, Android Emulator cellular settings) or desktop proxies for network throttling. |
| **Remote Cloud Telemetry & Sync** | Teams want live network traffic automatically streamed to an external web dashboard. | Violates user data privacy, risks exposing production API keys/PII, introduces backend hosting costs, adds heavy network overhead, and complicates GDPR/HIPAA compliance. | Keep the package strictly **local-first** on-device. Provide one-tap cURL, JSON, and HAR export via native share sheets for deliberate user sharing. |
| **Reflection / `dart:mirrors` Magic** | Magical zero-line configuration that automatically intercepts all network traffic without setting overrides or interceptors. | `dart:mirrors` is fundamentally disabled in Flutter and completely breaks Ahead-Of-Time (AOT) native compilation on mobile and desktop. | Use standard `HttpOverrides` chaining and explicit client interceptors (`NetworkInspectorDioInterceptor`). |

---

## Feature Dependencies

```
[Master Configuration: enabled, maxRecords, redactionRules]
       │
       ├──controls──> [Production No-Op Mode]
       │
       └──initializes──> [Storage Engine: SQLite + Schema + Auto-Prune]
                               │
                               ├──persists──> [NetworkRecord Model]
                               │                     ▲
                               │                     │ writes
┌──────────────────────────────┴─────────────────────┴──────────────────────────────┐
│                                                                                   │
│ [HttpOverrides Chaining] ──uses──> [Stream Splitter & Non-Draining Tap]           │
│                                           │ captures                              │
│ [Dio Interceptor Adapter] ────────────────┤                                       │
│                                           │ captures                              │
│ [package:http Adapter] ───────────────────┤                                       │
│                                           │ captures                              │
│ [Manual Logging API: logApi] ─────────────┘                                       │
│                                           │                                       │
│                                           ▼                                       │
│                           [Sanitizer & Redaction Engine]                          │
│                                           │                                       │
│                           [Payload Truncation Limiter]                            │
│                                           │                                       │
│                           [Duplicate Request Filter]                              │
│                                           │                                       │
│                                           ▼                                       │
│                           [Asynchronous Write Buffer Queue]                       │
└───────────────────────────────────────────┬───────────────────────────────────────┘
                                            │
                                            ▼
                       [Repository Query & Search Engine]
                                            │
                                            ├──feeds──> [Inspector Listing Screen]
                                            │                 │ (Pagination / Filter / Sort)
                                            │                 ▼
                                            │           [Inspector Details Screen]
                                            │                 ├── [Tabbed Views]
                                            │                 ├── [Pretty JSON Viewer]
                                            │                 ├── [cURL Generator]
                                            │                 └── [Share Sheet Export]
                                            │
                                            └──feeds──> [HAR 1.2 Export Serializer]

[Shake Detection: sensors_plus] ──triggers──> [Inspector UI Navigation]
[Programmatic open(context)]   ──triggers──> [Inspector UI Navigation]
[NetworkInspectorWrapper]       ──triggers──> [Inspector UI Navigation]
```

### Dependency Notes

- **`HttpOverrides Chaining` requires `Stream Splitter & Non-Draining Tap`:** Without non-destructive stream splitting, intercepting `HttpClientRequest` and `HttpClientResponse` drains the single-subscription byte stream, causing immediate host app crashes (`Bad state: Stream has already been listened to`).
- **`Storage Engine` requires `Sanitizer & Redaction Engine`:** Redaction must execute *before* database insertion so that unredacted sensitive tokens (passwords, auth headers) never touch persistent disk storage.
- **`Storage Engine` requires `Payload Truncation Limiter`:** Truncation must occur before SQL write serialization to prevent multi-megabyte payloads from causing SQLite write thread locks.
- **`Duplicate Request Filter` enhances `HttpOverrides Chaining` and `Dio Interceptor`:** When an application initializes both global `HttpOverrides` and the dedicated `Dio` interceptor, the duplicate filter prevents identical requests from being logged twice.
- **`Inspector Details Screen` requires `NetworkRecord Model`:** The details UI binds directly to immutable `NetworkRecord` instances retrieved by transaction ID from the repository.
- **`cURL Generator` requires `Sanitizer & Redaction Engine`:** The cURL generator must respect redaction settings so that copied bash commands do not accidentally expose production secrets unless explicitly configured.
- **`Shake Detection` requires `Inspector UI Navigation`:** The accelerometer listener invokes the navigation handler when the shake threshold is exceeded. Shake detection degrades gracefully if sensors are absent (e.g. desktop/simulator).
- **`HAR 1.2 Export` requires `Storage Engine`:** The HAR exporter queries stored `NetworkRecord` instances and serializes them into the RFC-compliant HTTP Archive 1.2 format.

---

## MVP Definition

### Launch With (v1)

The minimum viable product needed to deliver a rock-solid, production-safe in-app network inspector that solves the core developer frustrations of existing packages.

- [x] **Master Initialization & Configuration:** One-line initialization with `enabled`, `maxRecords`, `enableShakeDetection`, and `redactionRules` (`CORE-01`).
- [x] **Safe `HttpOverrides` Capture:** Universal transparent capture preserving existing `HttpOverrides.current` (`INTC-01`, `INTC-02`).
- [x] **Non-Draining Stream Splitting:** Reliable response stream proxying without stream consumption crashes (`INTC-01`).
- [x] **Dedicated Dio & `package:http` Adapters:** Clean interceptors for top client libraries (`INTC-03`, `INTC-04`).
- [x] **Duplicate Request Filtering:** Prevents double-logging when multiple interceptors are active (`INTC-05`).
- [x] **Metadata-Only Multipart Capture:** Safe file upload metadata parsing without storing binary payload bytes (`DATA-03`).
- [x] **Redaction & Size Limiting:** Header/body token masking and 1MB payload ceilings (`DATA-04`, `DATA-05`).
- [x] **SQLite Database Engine with Auto-Prune:** Non-blocking async persistence with automated FIFO pruning on `maxRecords` (`DB-01`, `DB-02`, `DB-03`).
- [x] **Inspector Listing Screen:** Material 3 list with method badges, status colors, duration, URL, and batch pagination (`UI-01`, `UI-02`).
- [x] **Search, Filter & Sort:** Instant query filtering by URL, method, status range (2xx–5xx), and duration sorting (`UI-03`, `UI-04`, `UI-05`).
- [x] **Tabbed Details Screen:** Overview, Headers, Query, Body, and Error tabs (`UI-07`).
- [x] **Pretty-Printed JSON Viewer:** Formatted syntax indentation with Formatted/Raw toggle (`UI-08`).
- [x] **Copy Actions & cURL Generator:** One-tap copy for URLs, headers, bodies, and executable cURL commands (`UI-09`).
- [x] **Native Share Sheet Export:** Sharing request/response logs via `share_plus` (`UI-10`).
- [x] **Shake Detection & Programmatic Open:** Shake-to-open gesture and `NetworkInspector.open(context)` (`SHAKE-01`, `NAV-01`).
- [x] **Clear Logs:** Immediate database cleanup with confirmation dialog (`UI-06`).
- [x] **Manual Logging API:** `NetworkInspector.logApi` for custom clients (`LOG-01`).

### Add After Validation (v1.x)

Enhancements to add once the core interception and storage foundation is verified in consumer applications.

- [ ] **HAR 1.2 Full Export:** Export complete session history as an HTTP Archive (`.har`) file to import into Charles, Proxyman, or Postman.
- [ ] **Image Preview Thumbnail:** In-memory image thumbnail preview in the response body tab for image responses under 50KB (without storing raw bytes in SQLite).
- [ ] **Floating Overlay Bubble:** Draggable floating bubble option on screen for quick access without physical device shaking.
- [ ] **Custom Tagging API:** Ability to tag network calls (e.g. `tag: 'checkout-flow'`) to filter multi-step user journeys.
- [ ] **Response Header Search:** Extending search query matching into response headers and status text.

### Future Consideration (v2+)

Advanced features to evaluate after broad ecosystem adoption.

- [ ] **Network Performance Metrics Dashboard:** Aggregated visual charts showing average latency per domain, error rates, and top slowest endpoints.
- [ ] **GraphQL Operation Name Inspector:** Dedicated UI tab highlighting GraphQL operation names, queries, mutations, and variables.
- [ ] **Desktop Companion Client:** Optional local LAN sync to view device logs in a dedicated desktop Flutter app (strictly opt-in for development).
- [ ] **Export to Postman Collection:** Formatting captured logs directly into a downloadable Postman Collection v2.1 JSON file.

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority | Target Release |
|---------|------------|---------------------|----------|----------------|
| **Safe `HttpOverrides` Chaining** | HIGH | MEDIUM | P1 | v1.0.0 |
| **Non-Draining Stream Splitting** | HIGH | HIGH | P1 | v1.0.0 |
| **Dedicated Dio & http Client Adapters** | HIGH | MEDIUM | P1 | v1.0.0 |
| **Duplicate Request Prevention** | HIGH | MEDIUM | P1 | v1.0.0 |
| **SQLite Persistence with FIFO Pruning** | HIGH | MEDIUM | P1 | v1.0.0 |
| **Metadata-Only Multipart Capture** | HIGH | MEDIUM | P1 | v1.0.0 |
| **Sensitive Data Redaction (PII/Tokens)** | HIGH | MEDIUM | P1 | v1.0.0 |
| **Payload Size Limiter & Truncation** | HIGH | LOW | P1 | v1.0.0 |
| **Inspector Listing Screen & Pagination** | HIGH | MEDIUM | P1 | v1.0.0 |
| **Search, Filter & Sort** | HIGH | MEDIUM | P1 | v1.0.0 |
| **Tabbed Details Screen** | HIGH | MEDIUM | P1 | v1.0.0 |
| **Pretty JSON Viewer with Raw Toggle** | HIGH | MEDIUM | P1 | v1.0.0 |
| **cURL Command Generator & Copy Actions** | HIGH | LOW | P1 | v1.0.0 |
| **Shake Detection & Programmatic Open** | HIGH | LOW | P1 | v1.0.0 |
| **Native Share Sheet Export** | HIGH | LOW | P1 | v1.0.0 |
| **Master Toggle & Safe Production No-Op** | HIGH | LOW | P1 | v1.0.0 |
| **Clear All Logs Action** | MEDIUM | LOW | P1 | v1.0.0 |
| **Manual Logging API (`logApi`)** | MEDIUM | LOW | P1 | v1.0.0 |
| **HAR 1.2 Archive Export** | HIGH | MEDIUM | P2 | v1.1.0 |
| **Image Thumbnail Preview (<50KB)** | MEDIUM | LOW | P2 | v1.1.0 |
| **Floating Overlay Debug Bubble** | MEDIUM | MEDIUM | P2 | v1.2.0 |
| **Session Flow Tagging API** | MEDIUM | LOW | P2 | v1.2.0 |
| **Performance Statistics Dashboard** | MEDIUM | HIGH | P3 | v2.0.0 |
| **Postman Collection Exporter** | MEDIUM | MEDIUM | P3 | v2.0.0 |
| **GraphQL Specialized Inspector Tab** | LOW | MEDIUM | P3 | v2.0.0 |

---

## Competitor Feature Analysis

Comparison between `flutter_network_inspector` and leading prior art in the Flutter ecosystem as well as desktop proxies.

| Feature Area | Alice (`alice`) | Chucker (`chucker_flutter`) | Desktop Proxies (Proxyman / Charles) | `flutter_network_inspector` (Our Approach) |
|--------------|-----------------|-----------------------------|--------------------------------------|-------------------------------------------|
| **Interception Method** | Destructive `HttpOverrides` or client interceptors | Client interceptors (Dio, http, Chopper) | OS-level Wi-Fi Proxy + SSL CA certificate | **Safe `HttpOverrides` Chaining** + dedicated Dio and `http` adapters. Non-destructive stream splitting. |
| **Chunked / Stream Response Handling** | Prone to `Stream has already been listened to` crashes on downloads/SSE | Fails or throws exceptions on Dio chunked streams | Full stream capture at TCP socket layer | **Dual-forwarding stream splitter** delivering chunks in real time to the host app while mirroring to inspector buffer. |
| **Duplicate Prevention** | None (logs twice if both Dio interceptor and `HttpOverrides` active) | None | Deduplicated at proxy connection level | **Internal correlation tagging** (`x-fl-inspector-id`) preventing duplicate ingestion across nested interceptors. |
| **Persistence Engine** | Memory by default; optional ObjectBox plugin | `SharedPreferences` / memory cache | Desktop disk database | **Embedded SQLite (`sqflite`)** with automated asynchronous FIFO pruning. Safe against OOM. |
| **Crash Protection & Storage Bounds** | Can crash on large payloads or unbounded sessions | **Known crash:** Android OOM due to SharedPreferences payload storage | Bounded by host computer RAM/disk | **Configurable `maxRecords`**, 1MB payload ceilings, and automated background SQLite pruning. |
| **Multipart Uploads** | Can buffer full binary into memory causing lag | Buffers multipart payloads into storage | Inspects multipart MIME streams | **Metadata-only capture:** extracts filename, field, MIME type, and size; excludes raw bytes from SQLite. |
| **PII & Credential Redaction** | Basic manual header exclusion | None (logs raw tokens and credentials) | Manual regex rule replacement | **Built-in recursive redaction engine:** masks configured headers and JSON body keys before persistence. |
| **Inspector UI** | Deep inspection, Gantt timeline, tree JSON | Chronological list, toast notifications, basic tabs | Multi-column native desktop UI | **Clean Material 3 UI:** Tabbed details, infinite scroll pagination, syntax JSON viewer with Raw toggle. |
| **Navigation Independence** | **Known issue:** Hard crash if `navigatorKey` is missing or in AutoRoute | Needs `navigatorKey` for notification taps | Not applicable (external app) | **Both programmatic `open(context)` and `NetworkInspectorWrapper`**; works with all router packages. |
| **Copy & Share Capabilities** | Copy to clipboard, export to file | Copy details, share sheet | Export HAR, cURL, CSV, raw payload | **One-tap cURL generation**, granular section copying, native share sheet dispatch, and HAR export. |
| **Setup Friction** | Low to medium | Low | High (SSL cert install, Wi-Fi proxy setup, breaks on cellular) | **Zero setup friction:** one-line `NetworkInspector.initialize()` without proxy certificates or Wi-Fi constraints. |

---

## Sources

- **Chucker Flutter:**
  - Pub.dev: [pub.dev/packages/chucker_flutter](https://pub.dev/packages/chucker_flutter)
  - GitHub Repository & Issue Tracker: [github.com/ChuckerTeam/chucker-flutter](https://github.com/ChuckerTeam/chucker-flutter)
  - Verified Issues: OOM crashes with SharedPreferences storage, Stream-based response failures in Dio, RenderFlex layout overflows on deep JSON.
- **Alice / Flutter Alice:**
  - Pub.dev: [pub.dev/packages/alice](https://pub.dev/packages/alice)
  - GitHub Repository: [github.com/jhomlala/alice](https://github.com/jhomlala/alice)
  - Verified Issues: Destructive `HttpOverrides.global` overwrites, `navigatorKey` missing crashes, stream consumption conflicts.
- **Talker Flutter Ecosystem:**
  - Pub.dev: [pub.dev/packages/talker_flutter](https://pub.dev/packages/talker_flutter) and [pub.dev/packages/talker_dio_logger](https://pub.dev/packages/talker_dio_logger)
  - Evaluated community additions: `talker_dio_logger_plus` (cURL generation, image preview, dedicated tabs).
- **Requests Inspector:**
  - Pub.dev: [pub.dev/packages/requests_inspector](https://pub.dev/packages/requests_inspector)
  - Features evaluated: Shake-to-open gesture, HAR export, Dio interceptor integration.
- **Desktop Proxies:**
  - Proxyman documentation and macOS architecture benchmarks ([proxyman.com](https://proxyman.com)).
  - Charles Proxy feature specifications ([charlesproxy.com](https://www.charlesproxy.com)).
- **Dart SDK & Flutter Core:**
  - Dart `dart:io` `HttpClient` and `HttpOverrides` implementation specifications ([api.dart.dev](https://api.dart.dev)).
  - Single-subscription `Stream<List<int>>` semantics and `StreamSplitter` documentation.

---
*Feature research for: Flutter Network Inspector Package (`fl_network_inspector`)*  
*Researched: 2026-10-31*
