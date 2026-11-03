# Flutter Network Inspector Package (`flutter_network_inspector`)

## What This Is

A reusable, modular, lightweight, and production-safe Flutter/Dart package that captures, stores, manages, and displays all HTTP network requests and responses made by a Flutter application. It delivers a comprehensive in-app debugging and inspection experience similar to Chucker or Charles Proxy, entirely inside the host Flutter application without external proxy dependencies.

## Core Value

Reliably capture, persist, and inspect HTTP requests and responses directly inside a Flutter application without breaking or modifying existing network streams, degrading app performance, or leaking sensitive data.

## Current Milestone: v1.1 Pub.dev Release Preparation

**Goal:** Prepare the package for publication on pub.dev under `fl_network_inspector` v1.0.0, achieving maximum pana score, complete public documentation, clean packaging, and verified dry-run.

**Target features:**
- Package rename to `fl_network_inspector` and version bump to `1.0.0`
- Complete public API documentation (`///` doc comments) across all exported symbols
- Complete code formatting (`dart format`) and zero analysis issues
- Configure `.pubignore` to prevent leaking internal files/artifacts
- Polish README, CHANGELOG, pubspec metadata, and example project
- Verify with `dart pub publish --dry-run` and pana score readiness

## Requirements

### Validated

- ✓ **CORE-01**: One-line package initialization with flag-based activation (`enabled`, `enableAutoCapture`, `enableShakeDetection`, `enableDatabase`, `maxRecords`) and safe no-op mode in production. — v1.0
- ✓ **CORE-02**: Clean modular architecture with independent modules (core, config, interception, manual logging, models, database, repository, services, inspector UI, sharing, shake detection). — v1.0
- ✓ **CORE-03**: Cross-platform runtime safety with conditional imports ensuring pure Dart and Flutter compatibility across Android, iOS, macOS, Windows, Linux, and Web. — v1.0
- ✓ **INTC-01**: Automatic HTTP interception via `HttpOverrides` and custom `HttpClient` / `HttpClientRequest` / `HttpClientResponse` wrappers without breaking original streams. — v1.0
- ✓ **INTC-02**: Safe `HttpOverrides` chaining that preserves pre-existing overrides without silently overriding or replacing them. — v1.0
- ✓ **INTC-03**: Dedicated client adapter for `Dio` (`NetworkInspectorDioInterceptor`). — v1.0
- ✓ **INTC-04**: Dedicated client adapter for `package:http` (`NetworkInspectorHttpClient`). — v1.0
- ✓ **INTC-05**: Duplicate request prevention across nested or chained interceptors. — v1.0
- ✓ **INTC-06**: Internal synthetic tracking header stripped before wire transmission. — v1.0
- ✓ **INTC-07**: Error, timeout, and socket failure interception with stack traces. — v1.0
- ✓ **LOG-01**: Public static manual logging API (`NetworkInspector.logApi` and `NetworkInspector.logRequest`) supporting headers, query params, bodies, status code, timing, errors, and multipart metadata. — v1.0
- ✓ **DATA-01**: Complete request metadata capture (unique ID, HTTP method, full URL, base URL, path, query params, headers, body, content type, timestamp, size, duration, status). — v1.0
- ✓ **DATA-02**: Support for multiple request/response body types (JSON, plain text, form URL encoded, HTML, XML, binary, empty). — v1.0
- ✓ **DATA-03**: Safe multipart handling capturing metadata only (file name, parameter name, MIME type, file size, optional file path) without storing raw file bytes in SQLite. — v1.0
- ✓ **DATA-04**: Configurable request/response body capture size limits to prevent excessive memory and database consumption. — v1.0
- ✓ **DATA-05**: Configurable redaction rules for sensitive headers and body fields (e.g., Authorization, Cookie, tokens, passwords, API keys). — v1.0
- ✓ **DB-01**: Local SQLite database architecture using asynchronous non-blocking operations with indexed columns for search and filtering. — v1.0
- ✓ **DB-02**: Automatic database cleanup based on configurable maximum record counts and retention limits. — v1.0
- ✓ **DB-03**: Database schema versioning, automated migrations, and graceful error handling. — v1.0
- ✓ **DB-04**: Abstracted repository/database layer decoupling the storage engine from business logic. — v1.0
- ✓ **UI-01**: API listing screen displaying method, endpoint/URL, status code, duration, timestamp, size, and visual status indicators (success, failure, error). — v1.0
- ✓ **UI-02**: Efficient batch pagination / infinite scrolling on the listing screen avoiding full-table memory loading. — v1.0
- ✓ **UI-03**: Multi-parameter search (URL, endpoint, method, status code, payload content). — v1.0
- ✓ **UI-04**: Robust filtering by HTTP method, status code range, success/failure, date range, and duration range. — v1.0
- ✓ **UI-05**: Sorting by newest, oldest, duration (fastest/slowest), and status code. — v1.0
- ✓ **UI-06**: Clear-all captured records action with confirmation. — v1.0
- ✓ **UI-07**: API details screen with organized tabs: Overview, Request Headers, Query Parameters, Request Body, Response Headers, Response Body, Multipart Info, and Error Details. — v1.0
- ✓ **UI-08**: Formatted JSON visualization with pretty-printing, raw/formatted toggle, and syntax-friendly display. — v1.0
- ✓ **UI-09**: Copy actions for URL, headers, query parameters, request body, and response body. — v1.0
- ✓ **UI-10**: cURL command generator with terminal-ready escaping. — v1.0
- ✓ **UI-11**: Report generation and export via native platform share sheet with sensitive data exclusion options. — v1.0
- ✓ **SHAKE-01**: Device shake detection to open the inspector with configurable sensitivity and independent toggle. — v1.0
- ✓ **SHAKE-02**: Debounce timer (1.5s) and route stacking prevention for shake detection. — v1.0
- ✓ **SHAKE-03**: Lifecycle-aware sensor listener pausing hardware sampling when app is backgrounded. — v1.0
- ✓ **DEV-01**: Global programmatic opening method (`NetworkInspector.open([context])`) with automatic fallback to `NetworkInspector.navigatorKey`. — v1.0
- ✓ **DEV-02**: `NetworkInspectorWrapper` widget with `builder` mode for root MaterialApp wrapping. — v1.0
- ✓ **TEST-01**: Comprehensive automated unit test suite (models, redaction, database, truncation) with in-memory SQLite FFI. — v1.0
- ✓ **TEST-02**: Interception integration tests verifying non-destructive streaming, HttpOverrides chaining, and client adapters. — v1.0
- ✓ **TEST-03**: UI widget tests for listing screen, search/filter interactions, detail tabs, and JSON formatting. — v1.0
- ✓ **DOC-01**: Complete documentation, architecture guide, API reference, and a fully functional example Flutter application. — v1.0

### Active

(None currently active — milestone v1.0 shipped)

### Out of Scope

- **Raw multipart file binary storage in SQLite** — Excluded to prevent database bloat, disk exhaustion, and UI thread stutter. Only metadata is stored.
- **Request / Response interception modification or mock server** — The package acts strictly as an inspector and logger; modifying live payloads or mocking responses (man-in-the-middle tampering) is out of scope for v1.
- **External desktop proxy daemon / Charles Proxy emulation server** — The inspector is fully self-contained in-app; running a standalone desktop proxy server is excluded.
- **Network bandwidth throttling / network simulation** — Out of scope; inspection and logging only.
- **Remote cloud sync / telemetry export** — All data is local-first on the user device SQLite.

## Context

- Target ecosystem: Flutter and Dart applications running on mobile platforms (Android, iOS) with cross-platform capability (macOS, Windows, Linux, Web where supported by SQLite/sensors).
- Target audience: Flutter mobile application developers, QA engineers, and mobile architects debugging network issues in development and staging environments.
- Similar prior art: Chucker (Android/Flutter), Charles Proxy, Alice, Flipper Network Plugin, Talker Flutter.
- Known pitfalls to address:
  - Breaking Dart `Stream<List<int>>` when intercepting `HttpClientRequest` and `HttpClientResponse`.
  - Overwriting other global `HttpOverrides`.
  - Recording duplicate entries when Dio/http adapters and global HttpOverrides are both active.
  - UI jank during heavy network bursts from unbuffered SQLite writes.
  - Memory leaks or app crashes from capturing massive file downloads/uploads.

## Constraints

- **Tech Stack**: Dart >= 3.0.0, Flutter >= 3.10.0.
- **Database**: SQLite via `sqflite` / `sqflite_common_ffi`.
- **Sensors**: `sensors_plus` for shake detection with graceful degradation when sensors are unavailable.
- **Sharing**: `share_plus` for native share sheet export.
- **Performance**: Zero UI thread blocking; asynchronous I/O; bounded payload buffers (default limit e.g. 1MB per body).
- **Security**: Complete no-op in release builds unless explicitly forced; configurable redaction of sensitive credentials.
- **OS Modernization**: Android 16 Edge-to-Edge window insets and 16KB uncompressed ELF page-alignment compatibility.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Dart `HttpOverrides` + wrapper streams | Captures all `dart:io` requests transparently without changing application business logic | ✓ Good |
| Dedicated Dio Interceptor & Http Client Adapter | Provides explicit, rock-solid capture for popular HTTP clients and web-safe setups | ✓ Good |
| Clean Architecture & Repository Pattern | Decouples database storage, network interception, and UI inspection | ✓ Good |
| Metadata-only multipart capture | Prevents massive SQLite growth and out-of-memory errors on large uploads | ✓ Good |
| SQLite with indexing and auto-cleanup | Ensures high-performance querying and bounded storage over long debugging sessions | ✓ Good |
| Singleton `NetworkInspector.navigatorKey` | Eliminates ancestor context traps during shake detection in MaterialApp | ✓ Good |
| Dynamic insets padding | Solves Android 16 edge-to-edge system navigation overlaps | ✓ Good |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-11-03 after v1.0 milestone completion*
