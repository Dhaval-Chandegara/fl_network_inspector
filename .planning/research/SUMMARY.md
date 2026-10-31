# Project Research Summary

**Project:** `flutter_network_inspector` (`fl_network_inspector`)  
**Domain:** Flutter In-App Network Inspection & Diagnostics Package  
**Researched:** 2026-10-31  
**Confidence:** HIGH  

---

## Executive Summary

`flutter_network_inspector` is an embeddable, production-safe, in-app HTTP/HTTPS network diagnostics package for Flutter and Dart applications. It empowers mobile developers and QA engineers to intercept, inspect, search, filter, and export network traffic in real time directly on iOS, Android, and desktop devices—eliminating the friction of installing SSL root certificates, configuring Wi-Fi proxies (Charles, Proxyman), or managing external debugging daemons.

Leading in-app tools in the Flutter ecosystem (`chucker_flutter`, `alice`, `requests_inspector`) suffer from severe structural liabilities: single-subscription stream consumption crashes (`Bad state: Stream has already been listened to`), out-of-memory (OOM) fatal crashes caused by unbounded in-memory buffers or storing raw multipart binary blobs in `SharedPreferences`, destructive `HttpOverrides.global` overwrites breaking corporate proxies and APM SDKs (Sentry, Firebase), and accidental plaintext leaks of sensitive credentials (JWTs, session cookies, passwords) into log exports.

The recommended architecture solves these vulnerabilities through a strict five-layer decoupled design:
1. **Zero-disruption ingestion:** Non-destructive `StreamTransformer` proxies that deliver byte chunks to the host application in real time without latency while mirroring payloads to a bounded inspection buffer.
2. **Safe chaining & deduplication:** `HttpOverrides` that delegates to existing active handlers, combined with internal tracking headers (`x-fl-net-inspector-tracked-id`) to eliminate duplicate logs across nested `Dio` or `package:http` interceptors.
3. **Resilient local persistence:** An asynchronous SQLite repository backed by `sqflite` (mobile) and `sqflite_common_ffi` (desktop and headless CI testing), operating in Write-Ahead Logging (`WAL`) mode with an in-memory micro-batch queue and automated FIFO retention pruning.
4. **Pre-persistence security:** Case-insensitive PII sanitization and payload size ceilings (1MB default) applied before disk writes or export generation.
5. **Fluid presentation:** A decoupled Material 3 UI supporting infinite scrolling, syntax-highlighted JSON rendering, cURL/HAR generation, and native share sheet dispatch (`share_plus`), activated programmatically or via accelerometer shake detection (`sensors_plus`).

---

## Key Findings

### Recommended Stack

The package relies on battle-tested, zero-code-generation dependencies with broad version bounds to prevent dependency lockups for consumer applications.

See [STACK.md](file:///Users/dhavalchandegara/projects/fl_network_inspector/.planning/research/STACK.md) for complete package specifications.

**Core technologies:**
- **Dart SDK (`>=3.0.0 <4.0.0`) & Flutter SDK (`>=3.10.0`):** Leverages class modifiers (`sealed`, `base`), pattern matching, records, and sound null-safety to define immutable domain models (`NetworkRecord`, `RecordFilter`, `RecordSort`).
- **`sqflite` (`^2.4.5`):** Embedded SQLite database for Android, iOS, and macOS. Backed by OS-native SQLite engines with zero native compilation overhead. Supports WAL mode, compound indices, and transactional FIFO auto-pruning.
- **`sqflite_common_ffi` (`^2.4.5`):** SQLite FFI engine for desktop platforms (Windows, Linux) and headless Dart VM unit/widget tests (`inMemoryDatabasePath`) without requiring physical devices or flaky mocks.
- **`path` (`^1.9.1`):** Cross-platform filesystem path resolution preventing OS path delimiter bugs.
- **`sensors_plus` (`^7.1.1`):** Accelerometer hardware access utilizing `userAccelerometerEventStream()`, which mathematically isolates dynamic movement by subtracting the static 9.8 m/s² gravitational vector to eliminate false-positive shake events.
- **`share_plus` (`^13.3.1`):** Native OS share sheet export (`ACTION_SEND` on Android, `UIActivityViewController` on iOS). Natively handles `sharePositionOrigin` to prevent iPadOS and macOS anchor view crashes.
- **`uuid` (`^4.6.0`):** RFC 4122 v4 unique identifier generation for transaction correlation and deduplication.
- **`intl` (`^0.20.3`):** Standardized timestamp formatting and duration metrics display.

**Client Adapters & Supporting Tools:**
- **`dio` (`>=5.0.0 <6.0.0`):** Dedicated `NetworkInspectorDioInterceptor` supporting modern `RequestInterceptorHandler` and `DioException` APIs.
- **`http` (`>=1.0.0 <2.0.0`):** Drop-in `NetworkInspectorHttpClient` wrapping `http.BaseClient` for official Dart HTTP clients.
- **`mocktail` (`^1.0.5`):** Code-generation-free test mocking for unit and integration suites.

**What NOT to use:**
- Avoid `sqlite3_flutter_libs` (flagged as `+eol` on pub.dev).
- Avoid raw `accelerometerEventStream()` (triggers false positives from gravity).
- Avoid code generation dependencies (`build_runner`, `freezed`) in package runtime dependencies.
- Avoid storing raw multipart binary file bytes in SQLite.

---

### Expected Features

The feature landscape balances immediate developer ergonomics with uncompromising runtime safety.

See [FEATURES.md](file:///Users/dhavalchandegara/projects/fl_network_inspector/.planning/research/FEATURES.md) for full competitive analysis and user value matrices.

**Must have (table stakes for v1.0.0):**
- **Automatic `dart:io` Interception:** Transparent network capture via `HttpOverrides` chaining.
- **Dedicated Dio & `package:http` Adapters:** Clean plug-and-play interceptors for top client libraries.
- **Tabbed Details Inspector UI:** Dedicated tabs for Overview, Request Headers, Query Parameters, Request Body, Response Headers, Response Body, Multipart Info, and Error Details.
- **Pretty-Printed JSON Viewer:** Formatted syntax indentation with a one-tap Formatted/Raw toggle.
- **Search, Filter & Sort:** Instant query filtering by URL, method, status range (2xx–5xx), and duration sorting.
- **cURL Command Generator & Copy Actions:** Executable, escaped cURL generator and granular clipboard copy buttons.
- **Native Share Sheet Export:** Sharing logs via `share_plus` with sensitive data exclusion.
- **Shake Detection & Programmatic Open:** Shake-to-open gesture and `NetworkInspector.open(context)`.
- **Persistent SQLite Storage with FIFO Auto-Pruning:** Bounded storage (`maxRecords`, default: 200) with automatic pruning.
- **Production-Safe Master Toggle:** Compile-time and runtime no-op in `kReleaseMode` unless explicitly overridden.

**Should have (competitive differentiators for v1.0.0):**
- **Safe `HttpOverrides` Chaining:** Preserves pre-existing overrides (proxies, SSL callbacks, APM tracers).
- **Non-Destructive Stream Splitting:** Dual-forwarding stream splitter eliminating `Stream has already been listened to` crashes.
- **Cross-Interceptor Request Deduplication:** Synthetic tracking headers preventing 2x duplicate records when both Dio interceptors and `HttpOverrides` are active.
- **Metadata-Only Multipart Handling:** Captures filenames, sizes, and MIME types while strictly omitting raw binary bytes to prevent OOM crashes.
- **Configurable Pre-Persistence PII Redaction:** Masks auth headers, tokens, and sensitive body keys before database insertion.
- **Configurable Payload Size Ceilings:** 1MB default truncation threshold with visible indicator badges.
- **Non-Blocking Write Buffer Queue:** Batches SQLite inserts and updates to maintain 60/120 FPS during network bursts.
- **Public Manual Logging API (`logApi`):** Support for manual network event logging (GraphQL, WebSockets, gRPC metadata).

**Defer to v1.x / v2+:**
- **HAR 1.2 Export (v1.1.0):** HTTP Archive format export for Charles/Proxyman/Postman import.
- **Image Thumbnail Preview (v1.1.0):** In-memory thumbnail preview for images < 50KB without persisting raw bytes.
- **Floating Overlay Bubble (v1.2.0):** Draggable screen bubble for simulator or desktop use.
- **Performance Analytics Dashboard (v2.0.0):** Visual charts showing error rates and slowest endpoints.

**Anti-features (explicitly excluded):**
- *Raw binary body persistence in SQLite* (causes database bloat and OOM crashes).
- *Live request/response tampering / mock server* (breaks invariants and introduces production security vulnerabilities).
- *Local reverse proxy daemon on `localhost`* (battery drain, OS CA installation, fails on cellular).
- *Network bandwidth throttling simulation* (triggers native socket timeouts; better handled by OS network conditioners).
- *Remote cloud sync / telemetry* (violates local-first privacy and GDPR compliance).

---

### Architecture Approach

The architecture enforces strict separation of concerns across five modular layers. Presentation never directly couples to network sockets, and interception engines interact with persistence strictly through an abstract repository interface.

See [ARCHITECTURE.md](file:///Users/dhavalchandegara/projects/fl_network_inspector/.planning/research/ARCHITECTURE.md) for module structure and class designs.

```
[ Host App / Clients ] (Dio, package:http, dart:io, Manual logApi)
         │
         ▼
[ Interception & Redaction Layer ] ──► (Deduplication Check -> PII Redaction -> Truncator)
         │
         ▼
[ Domain & Event Pipeline ] ───────► (Immutable NetworkRecord -> EventBus -> WriteBuffer)
         │
         ▼
[ Storage Repository Layer ] ───────► (Abstract Repository -> SQLite WAL + Auto-Prune)
         │
         ▼
[ Presentation & Trigger Layer ] ──► (Listing & Detail Views, JSON Viewer, Share, Shake)
```

**Major components & responsibilities:**
1. **`NetworkInspector` (Core Facade):** Single public entry point providing static initialization, configuration access, manual logging (`logApi`), and navigation triggers. Operates as a strict zero-overhead no-op when disabled.
2. **`RedactionEngine` & `PayloadTruncator`:** Synchronously sanitizes sensitive tokens (Bearer, Cookies, API keys, passwords) and enforces byte limits before records reach storage.
3. **`InspectorHttpOverrides` & `StreamTransformer`:** Chained override capturing standard Dart I/O traffic with non-destructive stream proxying.
4. **`NetworkInspectorDioInterceptor` & `NetworkInspectorHttpClient`:** Dedicated client adapters that tag requests with synthetic tracking headers (`x-fl-net-inspector-tracked-id`) for deduplication.
5. **`NetworkInspectorRepository` & `SQLiteRepository`:** Abstract interface and SQLite engine featuring WAL mode, compound indices (`timestamp`, `status_code`, `method`), and asynchronous micro-batch write buffering.
6. **`InspectorListingView` & `InspectorDetailView`:** Material 3 UI supporting indexed pagination, multi-parameter search/filtering, pretty-printed JSON rendering, and native export.
7. **`ShakeDetector`:** Lifecycle-aware hardware sensor listener utilizing debounced accelerometer magnitude calculation.

---

### Critical Pitfalls

See [PITFALLS.md](file:///Users/dhavalchandegara/projects/fl_network_inspector/.planning/research/PITFALLS.md) for code post-mortems and test verification strategies.

1. **Single-Subscription Stream Draining (`Bad state: Stream has already been listened to`):**  
   *Root Cause:* Reading or transforming `HttpClientResponse` or `StreamedResponse.stream` directly consumes Dart's single-subscription stream, crashing the host app.  
   *Prevention:* Implement a non-draining proxy stream transformer that yields chunks downstream to the host app in real time while accumulating a mirrored copy in a bounded buffer.

2. **Unchained `HttpOverrides.global` Overwrites:**  
   *Root Cause:* Setting `HttpOverrides.global` directly obliterates existing proxy configurations, SSL certificate validation overrides (`badCertificateCallback`), and APM tracers (Sentry).  
   *Prevention:* Capture `final previous = HttpOverrides.current` and delegate client creation and proxy resolution to `previous`.

3. **Double Interception / Duplicate Log Flooding:**  
   *Root Cause:* Using both a dedicated Dio/http client adapter and global `HttpOverrides` causes requests to be logged twice because Dio uses `dart:io.HttpClient` under the hood.  
   *Prevention:* Inject an internal correlation header (`x-fl-net-inspector-tracked-id`) in client adapters; configure `HttpOverrides` to strip the header and bypass duplicate logging.

4. **Out-Of-Memory (OOM) Crashes on Large Payloads & File Uploads:**  
   *Root Cause:* Buffering 30MB–100MB files into memory and persisting raw multipart binary blobs into SQLite triggers iOS Jetsam kills and Android OOM errors.  
   *Prevention:* Enforce a strict 1MB payload ceiling with truncation flags, bypass body buffering for binary MIME types, and store multipart metadata only.

5. **SQLite Lock Contention & UI Thread Jank:**  
   *Root Cause:* Firing unbatched SQLite writes over the platform MethodChannel during network bursts causes `database is locked` errors and UI frame drops.  
   *Prevention:* Enable SQLite Write-Ahead Logging (`WAL`), batch writes via an in-memory micro-queue (`batch.commit(noResult: true)`), and split heavy payload bodies into a separate 1-to-1 table (`transaction_payloads`) away from listing indices.

---

## Implications for Roadmap

Based on the architectural dependencies and failure modes identified in research, development must proceed in strict dependency order: domain models and security first, followed by storage, interception, presentation, and hardware integration.

### Suggested Phase Structure

```
Phase 1: Core Foundation, Domain Models & Security Redaction
   │
   ▼
Phase 2: Storage Engine & SQLite Persistence Layer
   │
   ▼
Phase 3: Network Interception Engine, Client Adapters & Deduplication
   │
   ▼
Phase 4: Presentation, Inspector UI & Native Diagnostics
   │
   ▼
Phase 5: Entry Triggers, Public Facade & Example Application
```

---

### Phase 1: Core Foundation, Domain Models & Security Redaction

**Rationale:** The canonical `NetworkRecord` domain model and `RedactionEngine` have zero external dependencies on Flutter UI, platform channels, or network sockets. Establishing them first creates a shared domain contract for storage and interception while guaranteeing that security redactions are designed into the pipeline from day one.

**Delivers:**
- Core package configuration model (`NetworkInspectorConfig`) with sane defaults and production toggles.
- Canonical domain models (`NetworkRecord`, `MultipartEntry`, `RecordFilter`, `RecordSort`, `BodyType`).
- Pre-persistence `RedactionEngine` and `RedactionRule` with zero-config default masking for auth headers and sensitive JSON keys.
- Payload size truncator utilities (`PayloadLimiter`) enforcing configurable byte limits.
- Event bus (`Stream<NetworkRecord>`) for reactive updates.

**Addresses Requirements:** `CORE-01`, `CORE-02`, `DATA-01`, `DATA-02`, `DATA-04`, `DATA-05`.

**Avoids Pitfalls:**
- Pitfall 6: Plaintext sensitive credentials persisting to disk or leaking to exports.
- Pitfall 4: Unbounded memory allocation from untruncated payloads.

---

### Phase 2: Storage Engine & SQLite Persistence Layer

**Rationale:** Interceptors need a destination to persist records, and UI screens need a repository to query. Building the persistence layer with `sqflite` (and `sqflite_common_ffi` for unit tests) ensures schema versioning, WAL concurrency, and FIFO pruning are fully verified before live network traffic is hooked up.

**Delivers:**
- Abstract `NetworkInspectorRepository` contract decoupling storage technology.
- Concrete `SQLiteNetworkInspectorRepository` backed by `sqflite` (mobile/macOS) and `sqflite_common_ffi` (desktop/tests).
- Split schema design: indexed summary table (`transactions`) and body table (`transaction_payloads`).
- Write-Ahead Logging (`WAL`) initialization and in-memory micro-batch write queue (`WriteBuffer`).
- Automated asynchronous FIFO pruning enforcing `maxRecords` limits without write lock contention.
- Database schema versioning and migration infrastructure (`DB-03`).

**Addresses Requirements:** `DB-01`, `DB-02`, `DB-03`, `DB-04`, `UI-06`.

**Avoids Pitfalls:**
- Pitfall 5: UI thread jank, frame drops, and `database is locked` exceptions under concurrent load.
- Pitfall 4: Database file ballooning into gigabytes.

---

### Phase 3: Network Interception Engine, Client Adapters & Deduplication

**Rationale:** With domain models and persistence established, interception can be implemented and validated against real local test servers (`HttpServer.bind`). This phase tackles the most technically difficult challenges: stream splitting and override chaining.

**Delivers:**
- Non-destructive `StreamTransformer` proxy for `HttpClientResponse` and `IOSink` wrappers for `HttpClientRequest`.
- Chained `InspectorHttpOverrides` preserving `HttpOverrides.current` and proxy resolution.
- Dedicated `NetworkInspectorDioInterceptor` supporting `FormData`, query parameters, and `DioException`.
- Dedicated `NetworkInspectorHttpClient` wrapping `http.BaseClient`.
- Cross-interceptor request deduplication engine via synthetic tracking headers (`x-fl-net-inspector-tracked-id`).
- Metadata-only multipart parser strictly omitting raw binary file bytes.
- Robust error lifecycle capturing timeouts, handshake failures, and connection drops without leaving zombie "Pending" records.
- Public manual logging API (`NetworkInspector.logApi` / `logRequest`).

**Addresses Requirements:** `INTC-01`, `INTC-02`, `INTC-03`, `INTC-04`, `INTC-05`, `DATA-03`, `LOG-01`.

**Avoids Pitfalls:**
- Pitfall 1: `Bad state: Stream has already been listened to` crashes on chunked or downloaded streams.
- Pitfall 2: Overwriting host app proxy settings or SSL certificate callbacks.
- Pitfall 3: Duplicate 2x log flooding when both Dio and `HttpOverrides` are configured.
- Pitfall 7: Zombie "Pending" requests on network errors and timeouts.
- Pitfall 8: Flutter Web compilation errors caused by unisolated `dart:io` imports.

---

### Phase 4: Presentation, Inspector UI & Native Diagnostics

**Rationale:** The presentation layer consumes `NetworkInspectorRepository` queries and listens to the `EventBus`. Building the UI against an active database populated by Phase 3 ensures that visual layout, pagination, syntax formatting, and native export actions are refined using realistic API payloads.

**Delivers:**
- Material 3 `InspectorListingView` with method badges, status color coding, and infinite scroll pagination.
- Multi-parameter search bar and filter modal (method, status range, duration, error-only).
- Multi-tab `InspectorDetailView` (Overview, Request Headers, Query Params, Request Body, Response Headers, Response Body, Multipart Info, Error Details).
- Formatted JSON visualizer with background isolate decoding and Formatted/Raw toggle.
- Executable, escaped cURL command generator and granular clipboard copy actions.
- Native share sheet export via `share_plus` supporting iPadOS anchor bounds and pre-export sanitization confirmation.
- Clear logs action with confirmation dialog.

**Addresses Requirements:** `UI-01`, `UI-02`, `UI-03`, `UI-04`, `UI-05`, `UI-06`, `UI-07`, `UI-08`, `UI-09`, `UI-10`.

**Avoids Pitfalls:**
- Pitfall 10: UI freezes and jank when pretty-printing large JSON responses.
- Pitfall 6: Accidental leak of unredacted credentials via share sheet exports.
- iPadOS crash from missing `sharePositionOrigin`.

---

### Phase 5: Entry Triggers, Public Facade & Example Application

**Rationale:** This phase ties the entire package together: exposes the public facade API, hooks up hardware shake detection, guarantees release-mode no-op behavior, provides cross-router navigation wrappers, and delivers automated test suites and a functional reference app.

**Delivers:**
- `ShakeDetector` monitoring `userAccelerometerEventStream()` from `sensors_plus` with dynamic magnitude calculation, 1.5s debounce, and `WidgetsBindingObserver` lifecycle pausing.
- Programmatic launch methods (`NetworkInspector.open(context)`) and navigation-independent `NetworkInspectorWrapper`.
- Master `NetworkInspector` facade coordinating initialization, runtime toggles, and safe release-mode no-op guarantees (`kReleaseMode`).
- Comprehensive automated test suite (`TEST-01`): unit tests, database concurrency stress tests, interception integration tests, and widget tests.
- Reference example Flutter application demonstrating `dart:io`, `Dio`, `package:http`, multipart uploads, and error scenarios (`DOC-01`).

**Addresses Requirements:** `CORE-01`, `SHAKE-01`, `NAV-01`, `TEST-01`, `DOC-01`.

**Avoids Pitfalls:**
- Pitfall 9: Cascading duplicate screen pushes on rapid shake and background sensor battery drain.
- Pitfall 6: Inspector remaining active or leaking telemetry in production release builds.
- Router crashes caused by missing `navigatorKey` in declarative routing setups.

---

### Phase Ordering Rationale

1. **Dependency Inversion:** Domain entities and security redactions (Phase 1) have no platform channel or Flutter UI dependencies, allowing immediate unit testing.
2. **Storage Precedes Ingestion:** The SQLite persistence engine (Phase 2) must exist before network interceptors start emitting data; otherwise, interceptors would have nowhere to write.
3. **Headless Verification of Interception:** Interception (Phase 3) is verified against local mock HTTP servers in pure automated tests before building UI screens.
4. **UI Built on Real Data:** The presentation layer (Phase 4) is built and polished against real persisted `NetworkRecord` entries rather than fabricated stubs.
5. **Facade Closes the Loop:** Hardware sensors, navigation routing, and production release guards (Phase 5) wrap the completed subsystems into a clean developer-facing API.

---

### Research Flags

- **Phase 3 (Interception Engine): NEEDS DEEPER RESEARCH / SPIKE DURING PLANNING**  
  *Reason:* Dart's `dart:io` does not expose an official stream tapping interface. Proxying `HttpClientResponse` while maintaining pause/resume backpressure, chunked transfer encoding (SSE), and handling error propagation without consuming single-subscription streams requires precise stream controller handling. Dedicated spikes on `StreamSplitter` vs custom dual-forwarding controllers are required.
- **Phase 2 (SQLite Persistence): STANDARD PATTERNS (Skip research phase)**  
  *Reason:* `sqflite` with WAL mode and `sqflite_common_ffi` are thoroughly documented, established Flutter standards.
- **Phase 1 (Core Foundation): STANDARD PATTERNS (Skip research phase)**  
  *Reason:* Pure Dart 3 models and regex/JSON key redaction follow standard language patterns.
- **Phase 4 (Presentation): STANDARD PATTERNS (Skip research phase)**  
  *Reason:* Material 3 widgets, `DefaultTabController`, and `share_plus` follow well-documented Flutter patterns. Isolate decoding can use standard `compute()`.
- **Phase 5 (Triggers & Facade): STANDARD PATTERNS (Skip research phase)**  
  *Reason:* `sensors_plus` accelerometer math ($g = \sqrt{x^2+y^2+z^2}$) and `WidgetsBindingObserver` lifecycle hooks are established community practices.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| **Stack** | HIGH | All recommended packages (`sqflite`, `sensors_plus`, `share_plus`, `dio`, `http`, `uuid`) are verified on pub.dev, actively maintained by the Flutter Community or Dart team, and compatible with Flutter 3.10+ / Dart 3.0+. |
| **Features** | HIGH | Extensively cross-referenced against existing tools (`chucker_flutter`, `alice`, `talker_flutter`, `requests_inspector`) and real GitHub issue reports to isolate critical missing capabilities. |
| **Architecture** | HIGH | Decoupled 5-layer design verified against official Dart `dart:io` and SQLite best practices. Eliminates tight coupling between UI, interception, and storage. |
| **Pitfalls** | HIGH | Core failure modes (stream draining, unchained overrides, OOM on multipart uploads, SQLite lock contention, multi-shake screen cascades) are verified with reproducible mechanics and documented avoidance patterns. |

**Overall confidence:** HIGH

---

### Gaps to Address

1. **Flutter Web Interception & Persistence Fallback:**  
   *Gap:* `dart:io` and standard SQLite do not function on Flutter Web.  
   *Planning Mitigation:* Use conditional imports to compile stubs on Web. Document that Web apps must use `NetworkInspectorDioInterceptor` or `NetworkInspectorHttpClient`, and provide an in-memory repository fallback on `kIsWeb`.
2. **Threshold for Background Isolate JSON Formatting:**  
   *Gap:* Determining the optimal byte threshold where JSON formatting should switch from the UI isolate to a background isolate via `compute()`.  
   *Planning Mitigation:* Benchmark JSON formatting on lower-end devices; adopt a safe 50KB–100KB threshold where payloads larger than this automatically execute off the main thread.
3. **iPadOS Anchor Context for `share_plus`:**  
   *Gap:* iPadOS throws `NSGenericException` if `sharePositionOrigin` is null when presenting native share sheets.  
   *Planning Mitigation:* Ensure the export helper accepts the triggering widget's `BuildContext` and computes `RenderBox.localToGlobal(Offset.zero) & RenderBox.size`.

---

## Sources

### Primary (HIGH Confidence)
- **Dart SDK `dart:io` Official API:** `HttpOverrides`, `HttpClient`, `HttpClientRequest`, and `HttpClientResponse` specifications (`https://api.dart.dev/stable/dart-io/`).
- **Dart Async Stream API:** `StreamTransformer`, `StreamController`, and `StreamSplitter` contracts (`https://api.dart.dev/stable/dart-async/`).
- **Flutter SQLite Documentation (`sqflite` & `sqflite_common_ffi`):** WAL mode, batching transactions, FFI desktop configuration (`https://pub.dev/packages/sqflite`).
- **Flutter Community Plus Plugins:** `sensors_plus` accelerometer streams and `share_plus` cross-platform sharing (`https://github.com/fluttercommunity/plus_plugins`).
- **Dio Official Documentation:** Interceptor architecture, `RequestInterceptorHandler`, and `DioException` APIs (`https://pub.dev/packages/dio`).

### Secondary (MEDIUM Confidence)
- **Chucker Flutter Issue Tracker & Source:** Post-mortems regarding SharedPreferences OOM crashes, Dio chunked stream failures, and layout overflows (`https://github.com/ChuckerTeam/chucker-flutter`).
- **Flutter Alice Repository:** Architectural analysis of `HttpOverrides` overwrites and `navigatorKey` routing dependencies (`https://github.com/jhomlala/alice`).
- **Sentry Flutter SDK:** Chained `HttpOverrides` implementation patterns (`https://github.com/getsentry/sentry-dart`).
- **Talker Flutter Ecosystem:** cURL generation patterns and tabbed UI designs (`https://pub.dev/packages/talker_flutter`).

---
*Research completed: 2026-10-31*  
*Ready for roadmap: yes*
