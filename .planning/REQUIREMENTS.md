# Requirements: Flutter Network Inspector Package

**Defined:** 2026-10-31  
**Core Value:** Reliably capture, persist, and inspect HTTP requests and responses directly inside a Flutter application without breaking or modifying existing network streams, degrading app performance, or leaking sensitive data.

## v1 Requirements

### Core & Configuration (CORE)

- [ ] **CORE-01**: One-line package initialization with flag-based activation (`enabled`, `enableAutoCapture`, `enableShakeDetection`, `enableDatabase`, `maxRecords`) and safe compile-time/runtime no-op mode in production.
- [ ] **CORE-02**: Clean modular architecture isolating Core, Config, Interception, Manual Logging, Models, Storage, Repository, Presentation UI, Sharing, and Shake Detection.
- [ ] **CORE-03**: Cross-platform runtime safety with conditional imports ensuring pure Dart and Flutter compatibility across Android, iOS, macOS, Windows, Linux, and graceful Web degradation.

### Automatic Network Interception (INTC)

- [ ] **INTC-01**: Automatic `dart:io` HTTP interception via `HttpOverrides` and custom non-destructive wrappers (`HttpClient`, `HttpClientRequest`, `HttpClientResponse`).
- [ ] **INTC-02**: Safe `HttpOverrides` chaining preserving pre-existing overrides (proxies, custom SSL certificates, APM hooks) without clobbering.
- [ ] **INTC-03**: Non-destructive stream handling via dual-forwarding `StreamTransformer` ensuring zero single-subscription stream draining (`Bad state: Stream has already been listened to`).
- [ ] **INTC-04**: Dedicated `Dio` client adapter (`NetworkInspectorDioInterceptor`) supporting request, response, and error hooks.
- [ ] **INTC-05**: Dedicated `package:http` client adapter (`NetworkInspectorHttpClient`) subclassing `http.BaseClient`.
- [ ] **INTC-06**: Cross-interceptor request deduplication using internal synthetic tracking header (`x-fl-net-inspector-tracked-id`) stripped before wire transmission.
- [ ] **INTC-07**: Complete error, timeout, and socket failure interception ensuring aborted requests transition to failed status with stack traces.

### Manual API Logging (LOG)

- [ ] **LOG-01**: Public static manual logging API (`NetworkInspector.logApi` and `NetworkInspector.logRequest`) working independently of automatic interception.
- [ ] **LOG-02**: Full parameter support for manual logging: method, URL, headers, query params, request/response bodies, status code, duration, timestamps, errors, and multipart metadata.

### Request & Response Data Management (DATA)

- [ ] **DATA-01**: Capture complete request metadata (unique UUID v4 ID, HTTP method, full URL, base URL, path, query params, headers, body, content type, timestamp, size, duration, status).
- [ ] **DATA-02**: Capture complete response metadata (status code, headers, body, content type, size, timestamp, duration, error/exception info).
- [ ] **DATA-03**: Support diverse payload formats (JSON, plain text, form URL encoded, HTML, XML, binary, empty payloads).
- [ ] **DATA-04**: Metadata-only multipart request handling (filename, field name, MIME type, size, configurable file path) strictly omitting raw binary file bytes in storage.
- [ ] **DATA-05**: Configurable payload body size limits (default 1MB) with truncation indicators to prevent OOM.
- [ ] **DATA-06**: Configurable sensitive data redaction for headers and body fields (Authorization, Cookie, tokens, passwords, API keys) applied before persistence or export.

### Local SQLite Database Architecture (DB)

- [ ] **DB-01**: Asynchronous non-blocking SQLite database implementation using `sqflite` (mobile) and `sqflite_common_ffi` (desktop & testing).
- [ ] **DB-02**: Optimized schema with normalized tables, WAL journal mode, and indexes on `timestamp`, `status_code`, `method`, and `duration_ms`.
- [ ] **DB-03**: Asynchronous write buffer queue to batch database operations during heavy network bursts.
- [ ] **DB-04**: Automated FIFO database pruning and cleanup based on configurable `maxRecords` (default 200) or storage limits.
- [ ] **DB-05**: Database schema versioning, automated migrations, and graceful error recovery.
- [ ] **DB-06**: Abstracted `NetworkInspectorRepository` interface decoupling database implementation from business logic.

### Network Inspector UI (UI)

- [ ] **UI-01**: API listing screen displaying HTTP method badge, endpoint/URL, status code badge, duration, timestamp, size, and visual status indicators (success, failure, error).
- [ ] **UI-02**: Efficient batch pagination and infinite scrolling on listing screen avoiding full-table memory loads.
- [ ] **UI-03**: Multi-parameter search across URL, endpoint, method, status code, and payload text.
- [ ] **UI-04**: Robust filters by HTTP method, status code categories (2xx, 3xx, 4xx, 5xx), success/error, date range, and duration.
- [ ] **UI-05**: Sorting options: newest first, oldest first, fastest, slowest, and status code.
- [ ] **UI-06**: Clear-all captured records action with confirmation prompt.
- [ ] **UI-07**: API details screen with tabbed sections: Overview, Request Headers, Query Parameters, Request Body, Response Headers, Response Body, Multipart Info, and Error Details.
- [ ] **UI-08**: Formatted JSON visualization with syntax formatting, expandable tree/raw view toggle, and background isolate parsing for large payloads.
- [ ] **UI-09**: Clipboard copy actions for full URL, request headers, response headers, request body, and response body.
- [ ] **UI-10**: cURL command generator producing copyable, properly escaped cURL CLI commands.
- [ ] **UI-11**: Native platform share sheet export via `share_plus` generating formatted text reports with options to exclude sensitive data.

### Shake Detection & Developer Experience (DEV)

- [ ] **SHAKE-01**: Accelerometer shake detection via `sensors_plus` using `userAccelerometerEventStream()` with gravity vector subtraction.
- [ ] **SHAKE-02**: Shake sensitivity configuration, debounce timer (1.5s), and route stacking prevention.
- [ ] **SHAKE-03**: Lifecycle-aware sensor listener pausing hardware sampling when app is backgrounded.
- [ ] **DEV-01**: Global programmatic opening method (`NetworkInspector.open(context)`).
- [ ] **DEV-02**: `NetworkInspectorWrapper` widget for root widget hierarchy wrapping.

### Testing & Verification (TEST)

- [ ] **TEST-01**: Comprehensive unit test suite for models, redaction engine, payload truncator, and SQLite repository using `sqflite_common_ffi` in-memory DB.
- [ ] **TEST-02**: Interception integration tests verifying non-destructive streaming, HttpOverrides chaining, and client adapters.
- [ ] **TEST-03**: UI widget tests for listing screen, search/filter interactions, detail tabs, and JSON formatting.

## v2 Requirements

### Deferred to Future Releases

- **HAR-01**: HTTP Archive (HAR 1.2) export specification support for Charles/Proxyman import (v1.1.0).
- **PREV-01**: Image thumbnail preview for image responses < 50KB in details screen (v1.1.0).
- **FLOAT-01**: Draggable floating overlay bubble trigger for desktop/simulator testing (v1.2.0).
- **DASH-01**: Performance analytics dashboard displaying error rate trends and latency percentiles (v2.0.0).

## Out of Scope

| Feature | Reason |
|---------|--------|
| Raw binary file storage in SQLite | Causes database bloat, disk exhaustion, UI frame drops, and mobile OOM crashes. Metadata-only capture is enforced. |
| Live MITM request/response tampering or mock server | Introduces severe security vulnerabilities, alters runtime invariants, and violates pure diagnostic inspection scope. |
| Local reverse proxy daemon on `localhost` | Fails on cellular networks, drains battery, and requires installing custom OS CA root certificates on every device. |
| Bandwidth throttling / network degradation simulation | Flaky at Dart layer and triggers socket resets; better handled natively by iOS Network Link Conditioner / Android Dev Tools. |
| Remote telemetry / cloud synchronization | Violates local-first architecture and developer privacy; all logs remain securely on-device. |

## Traceability

Which phases cover which requirements.

| Requirement | Phase | Status |
|-------------|-------|--------|
| CORE-01 | Phase 1 | Pending |
| CORE-02 | Phase 1 | Pending |
| CORE-03 | Phase 1 | Pending |
| DATA-01 | Phase 1 | Pending |
| DATA-02 | Phase 1 | Pending |
| DATA-03 | Phase 1 | Pending |
| DATA-04 | Phase 1 | Pending |
| DATA-05 | Phase 1 | Pending |
| DATA-06 | Phase 1 | Pending |
| DB-01 | Phase 2 | Pending |
| DB-02 | Phase 2 | Pending |
| DB-03 | Phase 2 | Pending |
| DB-04 | Phase 2 | Pending |
| DB-05 | Phase 2 | Pending |
| DB-06 | Phase 2 | Pending |
| INTC-01 | Phase 3 | Pending |
| INTC-02 | Phase 3 | Pending |
| INTC-03 | Phase 3 | Pending |
| INTC-04 | Phase 3 | Pending |
| INTC-05 | Phase 3 | Pending |
| INTC-06 | Phase 3 | Pending |
| INTC-07 | Phase 3 | Pending |
| LOG-01 | Phase 3 | Pending |
| LOG-02 | Phase 3 | Pending |
| UI-01 | Phase 4 | Pending |
| UI-02 | Phase 4 | Pending |
| UI-03 | Phase 4 | Pending |
| UI-04 | Phase 4 | Pending |
| UI-05 | Phase 4 | Pending |
| UI-06 | Phase 4 | Pending |
| UI-07 | Phase 4 | Pending |
| UI-08 | Phase 4 | Pending |
| UI-09 | Phase 4 | Pending |
| UI-10 | Phase 4 | Pending |
| UI-11 | Phase 4 | Pending |
| SHAKE-01 | Phase 5 | Pending |
| SHAKE-02 | Phase 5 | Pending |
| SHAKE-03 | Phase 5 | Pending |
| DEV-01 | Phase 5 | Pending |
| DEV-02 | Phase 5 | Pending |
| TEST-01 | Phase 6 | Pending |
| TEST-02 | Phase 6 | Pending |
| TEST-03 | Phase 6 | Pending |

**Coverage:**
- v1 requirements: 42 total
- Mapped to phases: 42
- Unmapped: 0 ✓

---
*Requirements defined: 2026-10-31*  
*Last updated: 2026-10-31 after initial definition*
