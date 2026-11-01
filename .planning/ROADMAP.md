# Roadmap: flutter_network_inspector

## Overview

`flutter_network_inspector` is built across 6 coherent delivery phases structured in a bottom-up horizontal architecture. We begin with immutable core domain models, configuration, and sensitive data redaction (Phase 1), advance to high-performance local SQLite storage with WAL buffering and FIFO pruning (Phase 2), implement transparent network capture and client adapters with deduplication and stream safety (Phase 3), create an in-app Material 3 debugging UI with search, filtering, and export capabilities (Phase 4), wire up device shake detection and navigation triggers with production no-op safety (Phase 5), and finalize with automated multi-tier test suites, comprehensive developer documentation, and a functional reference example application (Phase 6).

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation & Models** - Establish core configuration, immutable domain models, payload limiting, and sensitive data redaction (completed 2026-10-31)
- [x] **Phase 2: SQLite Persistence** - Build asynchronous SQLite repository with WAL mode, write buffering, and FIFO pruning (completed 2026-11-01)
- [ ] **Phase 3: Network Capture & Interceptors** - Implement non-destructive HttpOverrides, client adapters (Dio/http), deduplication, and manual logging
- [ ] **Phase 4: Inspector UI** - Develop Material 3 inspector screens with pagination, search/filtering, formatted JSON viewer, cURL generation, and sharing
- [ ] **Phase 5: Shake & Developer Experience** - Implement hardware shake detection, lifecycle handling, programmatic navigation, and root wrapper
- [ ] **Phase 6: Quality, Testing & Release** - Deliver automated test suites (unit, integration, widget), comprehensive documentation, and reference example app

## Phase Details

### Phase 1: Foundation & Models
**Goal**: Establish the foundational package configuration, immutable network transaction domain models, memory payload truncator, and sensitive data redaction engine.
**Depends on**: Nothing (first phase)
**Requirements**: CORE-01, CORE-02, CORE-03, DATA-01, DATA-02, DATA-03, DATA-04, DATA-05, DATA-06
**Success Criteria** (what must be TRUE):
  1. Developers can configure package settings (`enabled`, `enableAutoCapture`, `enableShakeDetection`, `enableDatabase`, `maxRecords`, redaction keys) with safe compile-time and runtime no-op execution when disabled.
  2. Core domain models (`NetworkRecord`, `MultipartEntry`, `RecordFilter`, `RecordSort`) represent complete HTTP request/response lifecycles, error details, and multipart metadata with pure Dart cross-platform compatibility.
  3. Payloads exceeding the configured size limit (default 1MB) are automatically truncated with a truncation indicator flag while preserving metadata without throwing OOM.
  4. Pre-persistence redaction engine automatically masks sensitive header and body fields (Authorization, Cookie, Bearer tokens, passwords, API keys) using case-insensitive matching.
**Plans:** 3/3 plans complete

Plans:
- [x] 01-01-PLAN.md — Package setup, pubspec manifest, platform safety test, core configuration (NetworkInspectorConfig), and public facade
- [x] 01-02-PLAN.md — Pure Dart 3 immutable domain models (NetworkRecord, PayloadData, BodyType, NetworkStatus, MultipartEntry, HttpErrorDetails), query models, and UUID generator
- [x] 01-03-PLAN.md — BodyTypeDetector, memory-bounded PayloadTruncator, recursive RedactionEngine, public barrel export, and full test suite

### Phase 2: SQLite Persistence
**Goal**: Provide high-throughput, non-blocking local SQLite storage with indexed querying, batched write buffering, and automated FIFO database pruning.
**Depends on**: Phase 1
**Requirements**: DB-01, DB-02, DB-03, DB-04, DB-05, DB-06
**Success Criteria** (what must be TRUE):
  1. Captured network records are asynchronously persisted and updated in a local SQLite database without blocking the UI thread or triggering SQLite lock exceptions during burst traffic.
  2. Large request/response bodies are isolated into a dedicated payload table while indexed summary columns (`timestamp`, `status_code`, `method`, `duration_ms`) support instant querying and filtering.
  3. Database records exceeding `maxRecords` (default 200) are automatically pruned using background FIFO cleanup transactions.
  4. Database schema version migrations and corruption recovery run cleanly across package updates without crashing host apps.
  5. The `NetworkInspectorRepository` abstraction provides clean data access decoupled from underlying SQLite implementation.
**Plans:** 3/3 plans complete

Plans:
**Wave 1**
- [x] 02-01-PLAN.md — SQLite dependencies, DatabaseConstants schema definitions, DatabaseManager WAL configuration, and migration pipeline

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 02-02-PLAN.md — In-memory WriteBufferQueue debouncing, two-phase coalescing, and DatabasePruner threshold hysteresis FIFO pruning

**Wave 3** *(blocked on Wave 2 completion)*
- [x] 02-03-PLAN.md — Abstract NetworkInspectorRepository, parameterized DatabaseQueryBuilder, Sqlite/InMemory repositories, and facade wiring

### Phase 3: Network Capture & Interceptors
**Goal**: Intercept HTTP/HTTPS traffic across `dart:io`, `Dio`, and `package:http` transparently without breaking streams, clobbering pre-existing overrides, or duplicating records.
**Depends on**: Phase 2
**Requirements**: INTC-01, INTC-02, INTC-03, INTC-04, INTC-05, INTC-06, INTC-07, LOG-01, LOG-02
**Success Criteria** (what must be TRUE):
  1. Standard `dart:io` HTTP requests and responses are captured automatically via chained `HttpOverrides` without corrupting active SSL certificates, proxies, or single-subscription response streams.
  2. Developers using `Dio` or `package:http` can attach dedicated client adapters (`NetworkInspectorDioInterceptor`, `NetworkInspectorHttpClient`) to capture complete request, response, and error lifecycles.
  3. Outgoing requests tagged by client adapters are automatically deduplicated against `HttpOverrides` so each network call generates exactly one persisted record.
  4. Developers can manually log custom network events and multipart metadata via `NetworkInspector.logApi` / `logRequest` independently of automatic interception.
  5. Network timeouts, socket failures, and aborted requests are captured with full error descriptions and stack traces rather than hanging in a permanent pending state.
**Plans:** 1/3 plans complete

Plans:
**Wave 1**
- [x] 03-01-PLAN.md — Transparent dart:io HTTP capture, non-destructive stream tap transformer, and safe HttpOverrides chaining

**Wave 2** *(blocked on Wave 1 completion)*
- [ ] 03-02-PLAN.md — Dedicated Dio and package:http client adapters with synthetic header deduplication

**Wave 3** *(blocked on Wave 2 completion)*
- [ ] 03-03-PLAN.md — Error, timeout, and socket failure interception, manual logging APIs, and public barrel exports

### Phase 4: Inspector UI
**Goal**: Deliver an in-app Material 3 debugging interface for browsing, searching, filtering, inspecting, formatting, and exporting captured network traffic.
**Depends on**: Phase 3
**Requirements**: UI-01, UI-02, UI-03, UI-04, UI-05, UI-06, UI-07, UI-08, UI-09, UI-10, UI-11
**Success Criteria** (what must be TRUE):
  1. Developers can browse an indexed, infinitely scrolling list of network calls with visual HTTP method badges, status codes, duration, payload size, and error highlights.
  2. Users can search records in real time across URL, endpoint, method, status code, and payload text, and filter by HTTP method, status code ranges (2xx-5xx), duration, or error state.
  3. Detailed request inspection provides dedicated tabs for Overview, Request/Response Headers, Query Parameters, Request/Response Bodies, Multipart Info, and Error Details.
  4. JSON request/response bodies are formatted with syntax styling, collapsible raw/formatted toggle, and background isolate processing for payloads > 50KB.
  5. Developers can copy granular details or full cURL commands with one tap, or export complete formatted reports via native platform share sheet with sensitive data exclusion.
**Plans**: TBD
**UI hint**: yes

### Phase 5: Shake & Developer Experience
**Goal**: Provide frictionless invocation triggers via device shake detection and root application wrappers with lifecycle safety.
**Depends on**: Phase 4
**Requirements**: SHAKE-01, SHAKE-02, SHAKE-03, DEV-01, DEV-02
**Success Criteria** (what must be TRUE):
  1. Shaking a physical mobile device triggers the inspector screen via `sensors_plus` gravity-subtracted accelerometer detection with a 1.5s debounce and route stacking prevention.
  2. Accelerometer hardware listeners automatically pause when the host application transitions to the background, preventing battery drain.
  3. Developers can wrap their root application with `NetworkInspectorWrapper` or call `NetworkInspector.open(context)` programmatically from custom debug menus or drawer actions.
  4. In production release builds, all triggers, interceptors, and listeners gracefully compile to zero-overhead no-ops unless explicitly forced.
**Plans**: TBD
**UI hint**: yes

### Phase 6: Quality, Testing & Release
**Goal**: Validate the package with automated unit, integration, and UI widget tests, accompanied by complete developer documentation and a reference example app.
**Depends on**: Phase 5
**Requirements**: TEST-01, TEST-02, TEST-03, DOC-01
**Success Criteria** (what must be TRUE):
  1. Automated unit test suite verifies models, redaction engine, payload truncation, and SQLite repository operations using in-memory SQLite FFI with 100% pass rate.
  2. Integration tests verify non-destructive stream consumption, `HttpOverrides` chaining, Dio/http adapter capture, and deduplication against local test HTTP servers.
  3. Widget tests verify the inspector listing screen, search/filter interactions, tab navigation, and formatted JSON rendering.
  4. An interactive example Flutter application runs on iOS, Android, and Desktop showcasing automatic interception, manual logging, multipart uploads, error handling, and shake-to-open.
  5. Complete documentation (README, architecture guide, API docs) provides clear setup guides and troubleshooting instructions.
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation & Models | 3/3 | Complete    | 2026-10-31 |
| 2. SQLite Persistence | 3/3 | Complete    | 2026-11-01 |
| 3. Network Capture & Interceptors | 0/3 | Not started | - |
| 4. Inspector UI | 0/TBD | Not started | - |
| 5. Shake & Developer Experience | 0/TBD | Not started | - |
| 6. Quality, Testing & Release | 0/TBD | Not started | - |
