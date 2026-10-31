<!-- GSD:project-start source:PROJECT.md -->

## Project

**Flutter Network Inspector Package (`flutter_network_inspector`)**

A reusable, modular, lightweight, and production-safe Flutter/Dart package that captures, stores, manages, and displays all HTTP network requests and responses made by a Flutter application. It delivers a comprehensive in-app debugging and inspection experience similar to Chucker or Charles Proxy, entirely inside the host Flutter application without external proxy dependencies.

**Core Value:** Reliably capture, persist, and inspect HTTP requests and responses directly inside a Flutter application without breaking or modifying existing network streams, degrading app performance, or leaking sensitive data.

### Constraints

- **Tech Stack**: Dart >= 3.0.0, Flutter >= 3.10.0.
- **Database**: SQLite via `sqflite` / `sqflite_common_ffi`.
- **Sensors**: `sensors_plus` for shake detection with graceful degradation when sensors are unavailable.
- **Sharing**: `share_plus` for native share sheet export.
- **Performance**: Zero UI thread blocking; asynchronous I/O; bounded payload buffers (default limit e.g. 1MB per body).
- **Security**: Complete no-op in release builds unless explicitly forced; configurable redaction of sensitive credentials.

<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->

## Technology Stack

## Executive Overview

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended | Confidence |
|------------|---------|---------|-----------------|------------|
| **Dart SDK** | `>=3.0.0 <4.0.0` | Core language runtime | Enables strict sound null-safety, records, pattern matching, and class modifiers (`sealed`, `base`, `interface`) to construct a rock-solid, type-safe network domain model (`NetworkRequest`, `NetworkResponse`, `HttpError`, `BodyType`). | HIGH |
| **Flutter SDK** | `>=3.10.0` | Cross-platform UI and plugin framework | Minimum baseline ensuring compatibility with Material 3, modern platform channel implementations, and broad backwards compatibility with consumer Flutter applications. | HIGH |
| **`sqflite`** | `^2.4.5` | Embedded database for iOS, Android, and macOS | The de facto standard SQLite plugin for Flutter (maintained by Tekartik). Backed directly by native OS SQLite engines via platform channels with zero extra native compilation overhead. Supports SQL transactions, indexed queries for sub-millisecond filtering across thousands of requests, and non-blocking batch writes (`batch.insert`, `batch.delete`). | HIGH |
| **`sqflite_common_ffi`** | `^2.4.5` | SQLite engine for Desktop (Windows/Linux) & Dart VM testing | Solves the Flutter database testing dilemma: allows headless unit tests and widget tests to run directly against real in-memory SQLite (`inMemoryDatabasePath`) using `databaseFactoryFfi` without requiring a physical device, simulator, or flaky mock layers. | HIGH |
| **`path`** | `^1.9.1` | Cross-platform filesystem path manipulation | Official Dart team package. Eliminates path delimiter bugs when constructing database and export file paths (`join(await getDatabasesPath(), 'fl_network_inspector.db')`) across Windows (`\`) and POSIX (`/`) systems. | HIGH |
| **`sensors_plus`** | `^7.1.1` | Accelerometer hardware access for shake detection | Official Flutter Community Plus plugin. Exposes `userAccelerometerEventStream()`, which isolates dynamic user motion by filtering out the constant 9.8 m/s² gravitational pull. This prevents false positive shake triggers during normal phone tilting or desk pickups. | HIGH |
| **`share_plus`** | `^13.3.1` | Native OS share sheet export | Official Flutter Community Plus plugin. Dispatches network logs, cURL reproductions, and JSON reports to native OS sharing targets (`ACTION_SEND` on Android, `UIActivityViewController` on iOS). Natively handles `sharePositionOrigin` on iPadOS and macOS desktop to prevent anchor view crashes. | HIGH |
| **`uuid`** | `^4.6.0` | RFC 4122 v4 unique identifier generation | Generates cryptographically secure, collision-free transaction IDs for every captured network request. Essential for correlating asynchronous request/response pairs and deduplicating calls across nested interceptors without relying on mutable database row IDs. | HIGH |

### Supporting Libraries (Client Adapters & Utilities)

| Library | Version Range | Purpose | When to Use | Confidence |
|---------|---------------|---------|-------------|------------|
| **`dio`** | `>=5.0.0 <6.0.0` (Latest: `5.11.1`) | Dedicated client interceptor adapter (`NetworkInspectorDioInterceptor`) | For consumer apps using `dio`. Implements `Interceptor` (`onRequest`, `onResponse`, `onError`) using modern `RequestInterceptorHandler` and `DioException` APIs. Bypasses `HttpOverrides` reliance and supports web/custom clients directly. | HIGH |
| **`http`** | `>=1.0.0 <2.0.0` (Latest: `1.6.0`) | Dedicated client adapter (`NetworkInspectorHttpClient`) | For consumer apps using official `package:http`. Implements `http.BaseClient`, intercepting `send(BaseRequest)` and returning non-destructively tapped `StreamedResponse` instances. Works across all platforms including Flutter Web. | HIGH |
| **`intl`** | `^0.20.3` | Date and timestamp formatting | Used in the UI listing and details inspector to display standardized, human-readable timestamps (`HH:mm:ss.SSS` and `yyyy-MM-dd HH:mm:ss`) and duration metrics across different locales. | HIGH |

### Development & Testing Tools

| Tool | Version | Purpose | Notes | Confidence |
|------|---------|---------|-------|------------|
| **`flutter_test`** | SDK | Unit, widget, and golden test runner | Core Flutter testing harness. Combined with `sqflite_common_ffi` to test repository queries, migrations, and UI components in headless CI. | HIGH |
| **`flutter_lints`** | `^6.0.0` | Static code analysis and linting rules | Enforces strict, idiomatic Dart and Flutter coding standards across all package modules. | HIGH |
| **`mocktail`** | `^1.0.5` | Code-gen-free test mocking | Clean null-safe mocking for database executors, client sockets, and platform channels without requiring tedious `build_runner` code generation. | HIGH |
| **`test`** | SDK / `^1.25.0` | Pure Dart unit test runner | For blazing-fast unit testing of core business logic, redaction engines, cURL generators, and stream splitter utilities without Flutter binding overhead. | HIGH |

## Installation

### For the Package `pubspec.yaml`

### CLI Quick-Add Commands

# Add Core Dependencies

# Add Client Adapter Dependencies (with permissive version bounds)

# Add Dev Dependencies

## Alternatives Considered

| Recommended | Alternative | Why Alternative Was Rejected | When to Use Alternative |
|-------------|-------------|------------------------------|-------------------------|
| **`sqflite`** | **Hive / Isar** | NoSQL object stores lack relational querying, composite indices, complex multi-column filter queries (`WHERE status_code >= 400 AND method = 'POST' AND duration > 1000`), and transactional batch pruning. Isar has suffered prolonged maintenance hiatuses, and Hive v2/v3 underwent disruptive migrations. | Use Hive/Isar for simple key-value setting persistence where query flexibility and SQL indices are unnecessary. |
| **`sqflite`** | **Drift (formerly Moor)** | Drift requires code generation (`build_runner`), adding heavy build times, code-gen version conflicts, and build configuration overhead for an embeddable debugging package. `sqflite` offers clean, zero-codegen direct control over schema, migrations, and raw indexed SQL performance. | Use Drift in large enterprise application codebases where complex domain ORM mapping and compile-time type-checked SQL queries outweigh build-time penalties. |
| **`sqflite`** | **In-Memory Ring Buffer (List/Queue)** | Logs are permanently lost on app reload or crash (making crash-debugging impossible). Heavy payload bursts cause severe memory pressure and Out-Of-Memory (OOM) app crashes. | Use an in-memory buffer only as an optional non-persistent mode (`enableDatabase: false`) or as an intermediate write-batching queue before flushing to SQLite. |
| **`sensors_plus` directly** | **`shake` / `shake_plus` packages** | Third-party wrapper packages are often abandoned, lock dependencies to older `sensors_plus` versions, and lack customizable sensitivity thresholds or cooldown timers. Calculating user acceleration magnitude directly with `sensors_plus` takes ~35 lines of pure Dart math without introducing brittle transitive dependencies. | Use `shake` only in quick prototype apps where zero customization is needed. |
| **Native Flutter UI (`dart:convert` pretty print + `SelectableText`)** | **`flutter_json_view` / `flutter_highlight`** | Third-party viewer packages often lag behind Flutter major releases, pull in heavy syntax-highlighting grammars, and cause dependency conflicts. Standard `JsonEncoder.withIndent('  ')` with a lightweight custom styled text widget provides zero-dependency, crash-free, selectable JSON rendering. | Use `flutter_highlight` if full syntax highlighting for 50+ programming languages is required. |
| **`share_plus`** | **Custom Platform Channels** | Reinventing native sharing requires writing and maintaining Android Intent (`ACTION_SEND`) and iOS (`UIActivityViewController`) platform code in Kotlin/Swift. `share_plus` is officially maintained by the Flutter Community with complete cross-platform coverage. | Only if writing a pure Dart command-line tool with no Flutter SDK binding. |

## What NOT to Use (Dangerous or Deprecated Choices)

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **`sqlite3_flutter_libs`** | Flagged as `+eol` (End Of Life) on pub.dev. Causes dependency resolution warnings and build breaks on modern Flutter Android/iOS toolchains. | Rely on `sqflite` for mobile (uses OS-provided SQLite) and `sqflite_common_ffi` for desktop/tests. |
| **`accelerometerEventStream()`** (Raw accelerometer) | Includes the static 9.8 m/s² gravity vector. When a device is held tilted or set down on a desk, the acceleration vector changes, triggering spurious shake events. | Use **`userAccelerometerEventStream()`** from `sensors_plus`, which mathematically subtracts gravity, isolating pure user-induced movement. |
| **Direct Stream Consumption (`await response.toList()`)** | Consumes the underlying single-subscription `Stream<List<int>>` on `HttpClientResponse` or `StreamedResponse`. When the host application attempts to read the response body, it crashes with `StateError: Stream has already been listened to`. | Tap the stream using a non-destructive `StreamTransformer` or byte accumulator that forwards chunks downstream while copying bytes to an inspection buffer. |
| **Storing Raw Multipart File Binaries in SQLite** | Storing 10MB–100MB video/image upload binaries directly in SQLite BLOBs causes UI thread stutter, massive database bloat, disk quota exhaustion, and app crashes. | Capture **multipart metadata only** (file name, parameter name, MIME type, file byte size, and optional local file path). Discard raw bytes. |
| **Unbounded Payload Buffering** | Large file downloads (e.g. 50MB PDFs or ZIPs) read entirely into RAM crash the app with Out-Of-Memory (OOM) errors. | Enforce a strict configurable capture limit (e.g., default `1 MB` / `1,048,576 bytes`). Truncate and mark `[Body truncated at 1MB]` when exceeded. |
| **`HttpOverrides.global = InspectorHttpOverrides()` without Chaining** | Silently overwrites pre-existing `HttpOverrides` configured by the host app (e.g., custom enterprise proxy settings, SSL pinning bypasses, or corporate VPN routing), causing host app network failures. | Always preserve the pre-existing override: capture `final previous = HttpOverrides.current;` and delegate unmatched client creation to `previous`. |
| **Direct `Share.share()` on iPadOS without Anchor** | On iPadOS, presenting a `UIActivityViewController` without an anchor point throws an unhandled `NSGenericException` crash: `Your application has presented a UIActivityViewController... without providing an anchor view`. | Always pass `sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size` retrieved from the triggering widget's `BuildContext`. |
| **Code Generation Dependencies (`build_runner`, `freezed`, `json_serializable`) in Package Dependencies** | Forces consumers to align code generator versions, increases package maintenance burden, and dramatically slows clean build times. | Use hand-crafted, immutable Dart 3 data classes with clean `toMap()` and `fromMap()` serializers. |

## Stack Patterns by Platform & Environment Variant

### 1. Mobile Production / Debugging (iOS & Android)

* **Storage:** Native `sqflite` using device SQLite engine.
* **Interception:** Global `HttpOverrides` chaining + optional `Dio` / `http` client adapters.
* **Shake Detection:** Active via `sensors_plus` `userAccelerometerEventStream()`.
* **Export:** Native share sheets via `share_plus`.
* **Production Guard:** When `kReleaseMode` is active and `enabled: false` (default), all interceptors, listeners, and database initializations return instantly as no-ops.

### 2. Desktop Platforms (macOS, Windows, Linux)

* **Storage:** Initialize FFI database factory before opening databases:
* **Shake Detection:** Gracefully disabled (hardware accelerometer unavailable on desktop). Fallback to keyboard shortcut or explicit UI trigger (`NetworkInspector.open(context)`).
* **Export:** `share_plus` desktop share or file-save fallback.

### 3. Flutter Web

* **Interception:** `dart:io` and `HttpOverrides` do **not** exist on Flutter Web. Interception on Web must rely exclusively on `NetworkInspectorDioInterceptor` and `NetworkInspectorHttpClient`.
* **Storage:** SQLite is not natively supported without WASM setup. The package should offer an in-memory repository fallback when running on Web (`kIsWeb`).
* **Shake Detection:** Disabled.

### 4. Headless Unit & Widget Testing (`flutter test`)

* **Storage Configuration:**
* Tests execute against isolated, blazing-fast in-memory databases (`inMemoryDatabasePath`), validating genuine SQL schemas, indices, and pruning triggers with zero mocks.

## Version Compatibility Matrix

| Package | Version Range | Compatible With | Notes & Constraints |
|---------|---------------|-----------------|---------------------|
| `dart` | `>=3.0.0 <4.0.0` | Flutter `>=3.10.0` | Required for class modifiers and pattern matching. |
| `flutter` | `>=3.10.0` | Dart 3.x | Target compatibility for modern Flutter applications. |
| `sqflite` | `^2.4.5` | Android API 16+, iOS 12+, macOS 10.14+ | Requires no external C library setup on mobile. |
| `sqflite_common_ffi` | `^2.4.5` | Dart 3.x, Windows, Linux, macOS | Used for desktop and test execution. |
| `path` | `^1.9.1` | Dart 3.x | Standard path utility across all platforms. |
| `sensors_plus` | `^7.1.1` | Android API 21+, iOS 12+ | Safe sensor streams with gravity isolation. |
| `share_plus` | `^13.3.1` | Android API 21+, iOS 12+, macOS 10.14+ | Requires `sharePositionOrigin` on iPadOS. |
| `dio` | `>=5.0.0 <6.0.0` | Dio 5.x | Uses `RequestInterceptorHandler` & `DioException`. |
| `http` | `>=1.0.0 <2.0.0` | http 1.x | Subclasses `http.BaseClient`. |
| `uuid` | `^4.6.0` | Pure Dart (Any) | Zero external dependencies; RFC 4122 v4 UUIDs. |
| `intl` | `^0.20.3` | Dart 3.x | Standard internationalization and date formatting. |
| `mocktail` | `^1.0.5` | Dart 3.x (Dev only) | Reflection-free, code-generation-free test mocks. |

## Sources & Documentation Lookup

- **pub.dev Official Registry:**
- **Dart & Flutter Official Documentation:**
- **Known Pitfall Post-Mortems:**

<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->

## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->

## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->

## Project Skills

No project skills found. Add skills to any of: `.agents/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->

## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-fast` for a trivial task inline, with no subagents and no PLAN.md
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->

## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
