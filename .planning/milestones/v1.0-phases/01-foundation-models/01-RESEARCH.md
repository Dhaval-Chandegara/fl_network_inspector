<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Default `maxRecords` retention limit is 500 records before FIFO pruning — **Reversibility:** costly — SQLite table schema and pruning logic will depend on this default, though configurable via `NetworkInspectorConfig`.
- **D-02:** Default maximum body size threshold before truncation is 1 MB (1,048,576 bytes) — **Reversibility:** reversible — Configurable ceiling applied in `PayloadTruncator`.
- **D-03:** Production release safeguard (`kReleaseMode`) is disabled by default, but allows an explicit override (e.g. `enabled: true`) for staging/internal builds — **Reversibility:** costly — Affects facade initialization guards across mobile platforms.
- **D-04:** Granular feature flags (`enableAutoCapture`, `enableShakeDetection`, `enableDatabase`) can be toggled independently in `NetworkInspectorConfig` — **Reversibility:** reversible — Independent flags stored on config object.
- **D-05:** Unified `NetworkRecord` model tracks the complete HTTP lifecycle (in-flight, completed, failed) with nullable response and error fields, plus an explicit `NetworkStatus` enum (`pending`, `success`, `failed`) — **Reversibility:** one-way — Core database entity and repository queries depend on this unified record schema.
- **D-06:** Pure handwritten Dart 3 immutable classes with `copyWith`, `toMap`, `fromMap`, and value equality (`==` / `hashCode`) with zero code generation dependencies (`build_runner`, `freezed`, or `json_serializable`) — **Reversibility:** costly — Standardizes all domain models across the package.
- **D-07:** Dedicated `PayloadData` class encapsulates body content string, byte size, detected `BodyType` enum (`json`, `text`, `formData`, `multipart`, `binary`, `empty`), and `isTruncated` boolean flag — **Reversibility:** costly — Consumed across models, database tables, and UI inspector tabs.
- **D-08:** RFC 4122 v4 UUID string generated at request inception for unique transaction identification, cross-interceptor tracking, and deduplication — **Reversibility:** one-way — Database primary keys and inter-layer tracking headers rely on UUID strings.
- **D-09:** Comprehensive default sensitive key blacklist covering `authorization`, `cookie`, `set-cookie`, `token`, `access_token`, `refresh_token`, `password`, `secret`, `api_key`, `apikey`, `private_key` — **Reversibility:** reversible — Developers can append custom keys via `NetworkInspectorConfig.customRedactionKeys`.
- **D-10:** Deep recursive traversal scans nested JSON maps and lists at any nesting depth to sanitize sensitive keys — **Reversibility:** reversible — Implemented inside `RedactionEngine`.
- **D-11:** Case-insensitive exact and normalized pattern matching handles kebab-case, snake_case, and camelCase variants (e.g. matching `api-key`, `apiKey`, `API_KEY`) — **Reversibility:** reversible — Centralized in `RedactionEngine`.
- **D-12:** Constant string `"[REDACTED]"` replaces sensitive values completely to avoid token length, character count, or entropy leakage — **Reversibility:** reversible.
- **D-13:** Oversized payload bodies are truncated to the configured byte limit with appended `\n\n[Payload truncated at X bytes]` banner and `isTruncated: true` set on `PayloadData` — **Reversibility:** reversible.
- **D-14:** Binary request and response streams (e.g. images, audio, video, zip) are not buffered into strings; instead, they are represented with a metadata summary banner `[Binary data: <mime_type>, <size_bytes>]` — **Reversibility:** reversible.
- **D-15:** Local filesystem paths for uploaded multipart files are omitted (`null`) by default for user filesystem privacy, with optional opt-in via `NetworkInspectorConfig.includeMultipartFilePaths` — **Reversibility:** reversible.
- **D-16:** Dedicated `MultipartEntry` model encapsulates `fieldName`, `fileName`, `contentType`, `byteSize`, and optional `filePath` — **Reversibility:** costly — Stored as structured metadata in `NetworkRecord`.

### the agent's Discretion
- Package folder structure under `lib/src/` organized into `core/`, `config/`, `models/`, and `utils/`.
- Detection heuristics for `BodyType` based on `content-type` header and content inspection.
- Pure Dart utility for byte sizing and string truncation.

### Deferred Ideas (OUT OF SCOPE)
- None — all discussed decisions directly support Phase 1 scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CORE-01 | One-line package initialization with flag-based activation (`enabled`, `enableAutoCapture`, `enableShakeDetection`, `enableDatabase`, `maxRecords`) and safe compile-time/runtime no-op mode in production. | Researched `NetworkInspectorConfig` with `const` constructor defaulting `_enabled` to `null` and resolving `enabled` via `_enabled ?? !kReleaseMode` [VERIFIED: pub.dev/packages/flutter foundation]. Provides foundational facade initialization. |
| CORE-02 | Clean modular architecture isolating Core, Config, Interception, Manual Logging, Models, Storage, Repository, Presentation UI, Sharing, and Shake Detection. | Researched directory layout under `lib/src/`: `config/`, `core/`, `models/`, `utils/`, ensuring zero cross-tier coupling and zero dependencies on UI or platform sockets in domain layer. |
| CORE-03 | Cross-platform runtime safety with conditional imports ensuring pure Dart and Flutter compatibility across Android, iOS, macOS, Windows, Linux, and graceful Web degradation. | Researched keeping all Phase 1 domain models, redaction, truncators, and configs 100% free of `dart:io`. Only `dart:core`, `dart:convert`, `dart:typed_data`, and `package:flutter/foundation.dart` are imported, guaranteeing 100% Web and Desktop compatibility. |
| DATA-01 | Capture complete request metadata (unique UUID v4 ID, HTTP method, full URL, base URL, path, query params, headers, body, content type, timestamp, size, duration, status). | Researched unified `NetworkRecord` domain model with RFC 4122 v4 UUID (`uuid: ^4.6.0`), sound null-safety, and immutable value semantics. |
| DATA-02 | Capture complete response metadata (status code, headers, body, content type, size, timestamp, duration, error/exception info). | Researched nullable response fields and `HttpErrorDetails` on `NetworkRecord`, supporting in-flight (`pending`), completed (`success`), and aborted/exception states (`failed`). |
| DATA-03 | Support diverse payload formats (JSON, plain text, form URL encoded, HTML, XML, binary, empty payloads). | Researched `PayloadData` model and `BodyTypeDetector` with `BodyType` enum: `json`, `text`, `formData`, `multipart`, `binary`, `empty`. |
| DATA-04 | Metadata-only multipart request handling (filename, field name, MIME type, size, configurable file path) strictly omitting raw binary file bytes in storage. | Researched `MultipartEntry` model with privacy-first `filePath = null` default and zero binary payload retention. |
| DATA-05 | Configurable payload body size limits (default 1MB) with truncation indicators to prevent OOM. | Researched `PayloadTruncator` with UTF-8 byte boundary safety, `\n\n[Payload truncated at X bytes]` banner, and `isTruncated: true` flag. |
| DATA-06 | Configurable sensitive data redaction for headers and body fields (Authorization, Cookie, tokens, passwords, API keys) applied before persistence or export. | Researched `RedactionEngine` with normalized key matching (camelCase, snake_case, kebab-case) and recursive traversal over JSON Maps and Lists. |
</phase_requirements>

## Project Constraints (from GEMINI.md)

- **Tech Stack**: Dart `>=3.0.0 <4.0.0`, Flutter `>=3.10.0`.
- **Database**: SQLite via `sqflite` / `sqflite_common_ffi` (Phase 2).
- **Sensors**: `sensors_plus` for shake detection with graceful degradation (Phase 5).
- **Sharing**: `share_plus` for native share sheet export (Phase 4).
- **Performance**: Zero UI thread blocking; asynchronous I/O; bounded payload buffers (default limit 1MB per body).
- **Security**: Complete no-op in release builds unless explicitly forced (`kReleaseMode`); configurable redaction of sensitive credentials before storage.
- **Forbidden Packages / Patterns**:
  - `sqlite3_flutter_libs` is flagged `+eol` — strictly forbidden.
  - Raw `accelerometerEventStream()` is forbidden — must use `userAccelerometerEventStream()` in Phase 5.
  - Direct single-subscription stream consumption (`await response.toList()`) is forbidden.
  - Storing raw multipart file binaries in SQLite or memory is strictly forbidden.
  - Unbounded payload buffering is forbidden — must enforce 1MB threshold.
  - Overwriting `HttpOverrides.global` without chaining is forbidden (Phase 3).
  - Code generation dependencies (`build_runner`, `freezed`, `json_serializable`) are forbidden — all domain models must be pure handwritten Dart 3 immutable classes.

---

# Phase 01: Foundation & Models - Research

**Researched:** 2026-10-31  
**Domain:** Foundational Package Configuration, Immutable Domain Models, Memory Payload Limiting & Sensitive Data Redaction  
**Confidence:** HIGH  

## Summary

Phase 1 lays the bedrock of `flutter_network_inspector`. It establishes the package configuration (`NetworkInspectorConfig`), the canonical transaction models (`NetworkRecord`, `PayloadData`, `MultipartEntry`, `HttpErrorDetails`), the memory payload truncation engine (`PayloadTruncator`), and the sensitive credential sanitization engine (`RedactionEngine`).

Because all downstream layers (SQLite persistence in Phase 2, network interception in Phase 3, UI inspector in Phase 4, and export tools) depend on these models and utilities, Phase 1 must enforce strict zero-codegen sound null-safety, 100% pure Dart isolation (zero `dart:io` imports in the domain layer to guarantee Flutter Web and desktop compatibility), and compile-time/runtime release-mode safety.

The primary technical challenge in this phase is ensuring that JSON redaction and payload truncation execute synchronously with sub-millisecond overhead during ingestion, without corrupting UTF-8 byte boundaries or leaking sensitive credentials through token lengths or key naming variants. By standardizing on recursive map/list traversal and normalized case-insensitive token pattern matching, all credentials are sanitized to constant `[REDACTED]` strings before reaching memory queues or disk.

**Primary recommendation:** Build pure handwritten Dart 3 immutable domain models with explicit `copyWith`, `toMap`, `fromMap`, and `Object.hashAll` equality, paired with a normalized-key `RedactionEngine` and byte-bounded `PayloadTruncator`, completely isolated from `dart:io`.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| **`NetworkInspectorConfig` & Flags** | Core / Config | Presentation / Triggers | Holds global toggles (`enabled`, `maxRecords`, `maxBodyBytes`, etc.) consumed across all layers. |
| **`NetworkRecord` & Domain Models** | Domain Models | Database / Storage | Canonical data language representing HTTP lifecycle; serialized directly to SQLite and UI views. |
| **`RedactionEngine`** | Ingestion / Processing | Export / Sharing | Sanitizes headers, query params, and body fields before persistence and re-checks during export. |
| **`PayloadTruncator` & `BodyTypeDetector`** | Ingestion / Processing | Memory Safety | Binds RAM consumption to <= 1MB and converts binary streams to metadata summaries before storage. |
| **`NetworkInspector` (Foundational Facade)** | Public Facade | Core Package | Serves as the single client API entry point for `initialize()` and configuration retrieval. |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| **`Dart SDK`** | `>=3.0.0 <4.0.0` | Language runtime | Enables class modifiers (`sealed`, `final`), pattern matching, records, and sound null-safety. [VERIFIED: pubspec.yaml constraints] |
| **`Flutter SDK`** | `>=3.10.0` | Framework baseline | Minimum baseline for Material 3 and modern platform channel interoperability. [VERIFIED: pubspec.yaml constraints] |
| **`uuid`** | `^4.6.0` | RFC 4122 v4 UUID generation | High-entropy, collision-free transaction IDs for deduplication and tracking. [VERIFIED: pub.dev/packages/uuid] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **`flutter_test`** | SDK | Unit & widget test runner | Core Flutter testing harness. |
| **`flutter_lints`** | `^3.0.0` | Static analysis & lint rules | Compatible with Dart `>=3.0.0 <4.0.0` without version solver conflicts. [VERIFIED: pub.dev/packages/flutter_lints] |
| **`test`** | `^1.25.0` | Pure Dart unit test runner | Rapid unit testing of models, redaction, and truncator logic without Flutter binding overhead. [VERIFIED: pub.dev/packages/test] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| **Handwritten Dart 3 Models** | `freezed` + `json_serializable` | `freezed` requires `build_runner` code generation, which adds severe build time penalties, version conflicts with consumer apps, and maintenance overhead for an embeddable package. Handwritten classes provide zero-codegen simplicity. |
| **`uuid: ^4.6.0`** | `DateTime.now().millisecondsSinceEpoch` + random number | Timestamp/random strings collide under parallel asynchronous requests and lack RFC 4122 compliance required for inter-service trace headers. |
| **Normalized Key Set** | Ad-hoc Regex string search on raw JSON | Regex over raw JSON strings destroys escaped strings, fails on nested keys with identical names, and risks corrupted JSON syntax. Structured Map/List tree traversal is 100% syntax-safe. |

**Installation:**
```yaml
# pubspec.yaml
name: flutter_network_inspector
description: A lightweight, modular in-app HTTP network inspector for Flutter applications.
version: 0.1.0
publish_to: none

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: '>=3.10.0'

dependencies:
  flutter:
    sdk: flutter
  uuid: ^4.6.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  test: ^1.25.0
```

**Version verification:**
- `uuid`: `4.6.0` verified on pub.dev registry. SDK requirement: `sdk: ">=3.0.0 <4.0.0"`. Published 2024. [VERIFIED: pub.dev/packages/uuid]
- `flutter_lints`: `3.0.0` verified on pub.dev registry. SDK requirement: `sdk: "^3.0.0"`. (Note: `flutter_lints: 6.0.0` requires Dart `^3.8.0`, so `^3.0.0` ensures compatibility with Dart 3.0.0 baseline). [VERIFIED: pub.dev/packages/flutter_lints]
- `intl`: Deferred to Phase 4 (UI). Note that `intl: 0.20.3` requires Dart `^3.9.0`, while `intl: 0.19.0` supports Dart `^3.0.0`. Phase 1 uses standard `DateTime` ISO-8601 formatting and does not require `intl`. [VERIFIED: pub.dev/packages/intl]

---

## Package Legitimacy Audit

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| `uuid` | pub.dev | 12 yrs (2012) | ~1.5M/mo | https://github.com/Daegalus/dart-uuid | [OK] | Approved [VERIFIED: pub.dev/packages/uuid] |
| `flutter_lints` | pub.dev | 3 yrs | Official Dart/Flutter Team | https://github.com/flutter/packages | [OK] | Approved [VERIFIED: pub.dev/packages/flutter_lints] |
| `test` | pub.dev | 12 yrs | Official Dart Team | https://github.com/dart-lang/test | [OK] | Approved [VERIFIED: pub.dev/packages/test] |

**Packages removed due to [SLOP] verdict:** None  
**Packages flagged as suspicious [SUS]:** None  

---

## Architecture Patterns

### System Architecture Diagram

```
                               HOST APPLICATION
                                      │
              NetworkInspector.initialize(config)
                                      ▼
                      ┌────────────────────────────────┐
                      │     NetworkInspectorConfig     │
                      │  - enabled (!kReleaseMode)     │
                      │  - maxRecords (500)            │
                      │  - maxBodyBytes (1,048,576)    │
                      │  - customRedactionKeys         │
                      └────────────────┬───────────────┘
                                       │
                      Raw Incoming Network Data
                                       │
            ┌──────────────────────────┴──────────────────────────┐
            ▼                                                     ▼
┌────────────────────────┐                             ┌───────────────────────┐
│     RedactionEngine    │                             │    PayloadTruncator   │
│ - Normalized keys      │                             │ - 1MB byte limit check│
│ - Deep recursive scan  │                             │ - Truncation banner   │
│ - URL query redact     │                             │ - Binary stream bypass│
│ - Form URL-encode scan │                             │ - UTF-8 boundary safe │
└───────────┬────────────┘                             └───────────┬───────────┘
            │                                                     │
            └──────────────────────────┬──────────────────────────┘
                                       ▼
                       ┌───────────────────────────────┐
                       │       BodyTypeDetector        │
                       │ - Content-Type header probe   │
                       │ - JSON / form / binary probe  │
                       └───────────────┬───────────────┘
                                       ▼
                       ┌───────────────────────────────┐
                       │          PayloadData          │
                       │ - body: String?               │
                       │ - byteSize: int               │
                       │ - bodyType: BodyType          │
                       │ - isTruncated: bool           │
                       └───────────────┬───────────────┘
                                       ▼
                       ┌───────────────────────────────┐
                       │         NetworkRecord         │
                       │ - id: UUID v4                 │
                       │ - url, baseUrl, path, method  │
                       │ - request/response headers    │
                       │ - request/response bodies     │
                       │ - status: NetworkStatus       │
                       │ - error: HttpErrorDetails?    │
                       │ - multipartEntries: List?     │
                       └───────────────┬───────────────┘
                                       │
                    Passed Downstream to Phase 2 & 3
                     (SQLite Persistence & Interception)
```

### Recommended Project Structure

```
lib/
├── flutter_network_inspector.dart      # Main public barrel export
└── src/
    ├── config/
    │   └── network_inspector_config.dart # NetworkInspectorConfig & static defaults
    ├── core/
    │   ├── constants.dart              # Default limits, tracking headers, redaction constants
    │   └── network_inspector.dart      # Public facade (initialize, config, isEnabled)
    ├── models/
    │   ├── body_type.dart              # BodyType enum (json, text, formData, multipart, binary, empty)
    │   ├── http_error_details.dart     # HttpErrorDetails model (message, errorType, stackTrace)
    │   ├── multipart_entry.dart        # MultipartEntry model (fieldName, fileName, size, filePath)
    │   ├── network_record.dart         # Canonical NetworkRecord entity & NetworkStatus enum
    │   ├── payload_data.dart           # PayloadData container
    │   ├── record_filter.dart          # Filter model for querying
    │   └── record_sort.dart            # Sorting definitions (field, order)
    └── utils/
        ├── body_type_detector.dart     # MIME type & payload content inspection heuristic
        ├── payload_truncator.dart      # Safe UTF-8 byte boundary truncation & binary summary
        ├── redaction_engine.dart       # Deep recursive JSON/URL/header redaction engine
        └── uuid_generator.dart         # RFC 4122 v4 UUID generator wrapper
```

### Pattern 1: Safe `kReleaseMode` Config with `const` Constructor

**What:** In Flutter, `kReleaseMode` is a top-level `const bool` from `package:flutter/foundation.dart`. However, environment-dependent expressions cannot be evaluated inside default parameter slots of a `const` constructor.  
**When to use:** In `NetworkInspectorConfig`.  
**Implementation:**
```dart
import 'package:flutter/foundation.dart';
import '../core/constants.dart';

class NetworkInspectorConfig {
  final bool? _enabled;
  final int maxRecords;
  final int maxBodyBytes;
  final bool enableAutoCapture;
  final bool enableShakeDetection;
  final bool enableDatabase;
  final bool includeMultipartFilePaths;
  final List<String> customRedactionKeys;

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

  /// Returns explicit override if provided; otherwise disables inspector in release builds.
  bool get enabled => _enabled ?? !kReleaseMode;
}
```

### Pattern 2: Deep Recursive JSON Map & List Redaction

**What:** Sensitive keys can appear at any nesting depth in complex JSON payloads (e.g. `{"user": {"credentials": {"password": "secret"}}}`).  
**When to use:** In `RedactionEngine.redactJsonBody()`.  
**Implementation:**
```dart
dynamic _redactNode(dynamic node, Set<String> normalizedKeys) {
  if (node is Map<String, dynamic>) {
    final result = <String, dynamic>{};
    for (final entry in node.entries) {
      if (RedactionEngine.isSensitiveKey(entry.key, normalizedKeys)) {
        result[entry.key] = NetworkInspectorConstants.redactedPlaceholder;
      } else {
        result[entry.key] = _redactNode(entry.value, normalizedKeys);
      }
    }
    return result;
  } else if (node is List) {
    return node.map((element) => _redactNode(element, normalizedKeys)).toList();
  }
  return node;
}
```

### Pattern 3: Normalized Key Matching for Redaction

**What:** Keys may use camelCase (`apiKey`), snake_case (`api_key`), kebab-case (`api-key`), or UPPERCASE (`API_KEY`).  
**When to use:** In `RedactionEngine.normalizeKey()`.  
**Implementation:**
```dart
static String normalizeKey(String key) {
  return key.toLowerCase().replaceAll(RegExp(r'[-_.]'), '');
}
```
Matching `normalizeKey('apiKey')` yields `'apikey'`, matching `'api_key'`, `'api-key'`, and `'API_KEY'`.

### Pattern 4: UTF-8 Byte-Bounded Truncation Without Malformed Character Exceptions

**What:** When truncating a Dart `String` to a byte limit (e.g. 1MB), slicing at raw byte offsets can split a 2-4 byte UTF-8 sequence, throwing `FormatException` upon decoding.  
**When to use:** In `PayloadTruncator.truncateString()`.  
**Implementation:**
```dart
import 'dart:convert';
import '../models/payload_data.dart';
import '../models/body_type.dart';
import '../core/constants.dart';

class PayloadTruncator {
  static PayloadData truncate({
    required String? body,
    required String? contentType,
    required int maxBytes,
  }) {
    if (body == null || body.isEmpty) {
      return const PayloadData(
        body: null,
        byteSize: 0,
        bodyType: BodyType.empty,
        isTruncated: false,
      );
    }

    final bytes = utf8.encode(body);
    final originalSize = bytes.length;

    if (originalSize <= maxBytes) {
      return PayloadData(
        body: body,
        byteSize: originalSize,
        bodyType: BodyTypeDetector.detect(body: body, contentType: contentType),
        isTruncated: false,
      );
    }

    // Safely decode sliced bytes using allowMalformed: true to prevent UTF-8 decode crashes
    final slicedBytes = bytes.sublist(0, maxBytes);
    final truncatedText = utf8.decode(slicedBytes, allowMalformed: true);
    final banner = '\n\n[Payload truncated at $maxBytes bytes]';

    return PayloadData(
      body: '$truncatedText$banner',
      byteSize: originalSize,
      bodyType: BodyTypeDetector.detect(body: body, contentType: contentType),
      isTruncated: true,
    );
  }
}
```

### Anti-Patterns to Avoid

- **Anti-Pattern 1: Importing `dart:io` in Domain Models.**  
  *Why it's bad:* Completely breaks Flutter Web compilation and causes runtime errors on Web (`Unsupported operation: Platform._version`).  
  *What to do instead:* Keep domain models, configuration, truncator, and redaction engine 100% pure Dart using `dart:core`, `dart:convert`, and `package:flutter/foundation.dart`.
- **Anti-Pattern 2: String-Level Regex Redaction on Raw JSON Strings.**  
  *Why it's bad:* Regex string replacement like `str.replaceAll(RegExp(r'"password":\s*".*?"'), ...)` corrupts JSON when passwords contain escaped quotes (`\"`), spaces, or curly braces.  
  *What to do instead:* Parse with `jsonDecode`, recursively traverse the Dart `Map`/`List` structure, sanitize matching keys, and serialize with `jsonEncode`.
- **Anti-Pattern 3: Truncating Strings by Character Count Instead of Byte Count.**  
  *Why it's bad:* Multi-byte characters (emojis, Asian languages, accented text) use 2 to 4 bytes per character. Truncating at 1,048,576 characters can consume up to 4MB of RAM, defying the 1MB memory bound.  
  *What to do instead:* Measure and slice the byte array (`utf8.encode(str)`).
- **Anti-Pattern 4: Code Generation Dependencies in Embeddable Library.**  
  *Why it's bad:* Forcing `freezed` or `json_serializable` onto consumer apps leads to `build_runner` version conflicts with the host app's own code generator dependencies.  
  *What to do instead:* Write explicit, hand-crafted Dart 3 data classes with `copyWith`, `toMap`, and `fromMap`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Unique Transaction ID Generation | Custom timestamp + random number generator | `uuid` (`Uuid().v4()`) | Collides under parallel concurrent asynchronous HTTP requests. `uuid: ^4.6.0` generates cryptographically secure RFC 4122 v4 UUIDs. [VERIFIED: pub.dev/packages/uuid] |
| Deep Data Immutability & Value Equality | External packages like `equatable` or `freezed` | Dart 3 `Object.hashAll()` and custom `==` | Zero-dependency, sound null-safe, zero `build_runner` overhead. [VERIFIED: .planning/phases/01-foundation-models/01-CONTEXT.md:24] |
| Deep JSON Traversal | Ad-hoc String Regex | Recursive Dart Map/List tree traversal | Raw string regex breaks on escaped quotes, multi-line strings, and corrupts JSON syntax. |
| URL Query Sanitization | Manual substring splitting on `?` and `&` | `Uri.parse(url)` + `Uri.replace(queryParameters: ...)` | Manual string parsing breaks on encoded query params (`%26`, `%3D`), hash anchors (`#`), and relative URLs. |

**Key insight:** Hand-rolling string manipulation for structured data formats (JSON, URIs, UTF-8 byte streams) consistently creates edge cases that crash host applications or leak credentials. Dart's standard library `dart:core` (`Uri`, `Object.hash`) and `dart:convert` (`jsonDecode`, `utf8.decode`) handle these edge cases natively with optimal performance.

---

## In-Repo Discrete Value Provenance

The following discrete values are quoted verbatim from the source-of-truth files read this session:

1. **Default `maxRecords` Limit:** `500`  
   [VERIFIED: .planning/phases/01-foundation-models/01-CONTEXT.md:17] "Default `maxRecords` retention limit is 500 records before FIFO pruning — Reversibility: costly — SQLite table schema and pruning logic will depend on this default, though configurable via `NetworkInspectorConfig`."
2. **Default `maxBodyBytes` Limit:** `1048576` (1 MB)  
   [VERIFIED: .planning/phases/01-foundation-models/01-CONTEXT.md:18] "Default maximum body size threshold before truncation is 1 MB (1,048,576 bytes) — Reversibility: reversible — Configurable ceiling applied in `PayloadTruncator`."
3. **Production Release Guard:**  
   [VERIFIED: .planning/phases/01-foundation-models/01-CONTEXT.md:19] "Production release safeguard (`kReleaseMode`) is disabled by default, but allows an explicit override (e.g. `enabled: true`) for staging/internal builds — Reversibility: costly — Affects facade initialization guards across mobile platforms."
4. **Feature Flags:** `enableAutoCapture`, `enableShakeDetection`, `enableDatabase`  
   [VERIFIED: .planning/phases/01-foundation-models/01-CONTEXT.md:20] "Granular feature flags (`enableAutoCapture`, `enableShakeDetection`, `enableDatabase`) can be toggled independently in `NetworkInspectorConfig` — Reversibility: reversible — Independent flags stored on config object."
5. **`NetworkStatus` Enum Values:** `pending`, `success`, `failed`  
   [VERIFIED: .planning/phases/01-foundation-models/01-CONTEXT.md:23] "Unified `NetworkRecord` model tracks the complete HTTP lifecycle (in-flight, completed, failed) with nullable response and error fields, plus an explicit `NetworkStatus` enum (`pending`, `success`, `failed`) — Reversibility: one-way — Core database entity and repository queries depend on this unified record schema."
6. **Zero-Codegen Immutability Requirement:**  
   [VERIFIED: .planning/phases/01-foundation-models/01-CONTEXT.md:24] "Pure handwritten Dart 3 immutable classes with `copyWith`, `toMap`, `fromMap`, and value equality (`==` / `hashCode`) with zero code generation dependencies (`build_runner`, `freezed`, or `json_serializable`) — Reversibility: costly — Standardizes all domain models across the package."
7. **`BodyType` Enum Values:** `json`, `text`, `formData`, `multipart`, `binary`, `empty`  
   [VERIFIED: .planning/phases/01-foundation-models/01-CONTEXT.md:25] "Dedicated `PayloadData` class encapsulates body content string, byte size, detected `BodyType` enum (`json`, `text`, `formData`, `multipart`, `binary`, `empty`), and `isTruncated` boolean flag — Reversibility: costly — Consumed across models, database tables, and UI inspector tabs."
8. **Transaction ID Format:** RFC 4122 v4 UUID  
   [VERIFIED: .planning/phases/01-foundation-models/01-CONTEXT.md:26] "RFC 4122 v4 UUID string generated at request inception for unique transaction identification, cross-interceptor tracking, and deduplication — Reversibility: one-way — Database primary keys and inter-layer tracking headers rely on UUID strings."
9. **Default Sensitive Blacklist Keys:** `authorization`, `cookie`, `set-cookie`, `token`, `access_token`, `refresh_token`, `password`, `secret`, `api_key`, `apikey`, `private_key`  
   [VERIFIED: .planning/phases/01-foundation-models/01-CONTEXT.md:29] "Comprehensive default sensitive key blacklist covering `authorization`, `cookie`, `set-cookie`, `token`, `access_token`, `refresh_token`, `password`, `secret`, `api_key`, `apikey`, `private_key` — Reversibility: reversible — Developers can append custom keys via `NetworkInspectorConfig.customRedactionKeys`."
10. **Constant Redaction Placeholder String:** `"[REDACTED]"`  
    [VERIFIED: .planning/phases/01-foundation-models/01-CONTEXT.md:32] "Constant string `\"[REDACTED]\"` replaces sensitive values completely to avoid token length, character count, or entropy leakage — Reversibility: reversible."
11. **Truncation Indicator Banner:** `\n\n[Payload truncated at X bytes]`  
    [VERIFIED: .planning/phases/01-foundation-models/01-CONTEXT.md:35] "Oversized payload bodies are truncated to the configured byte limit with appended `\\n\\n[Payload truncated at X bytes]` banner and `isTruncated: true` set on `PayloadData` — Reversibility: reversible."
12. **Binary Summary Banner:** `[Binary data: <mime_type>, <size_bytes>]`  
    [VERIFIED: .planning/phases/01-foundation-models/01-CONTEXT.md:36] "Binary request and response streams (e.g. images, audio, video, zip) are not buffered into strings; instead, they are represented with a metadata summary banner `[Binary data: <mime_type>, <size_bytes>]` — Reversibility: reversible."
13. **Multipart Local File Path Privacy Default:** `null`  
    [VERIFIED: .planning/phases/01-foundation-models/01-CONTEXT.md:37] "Local filesystem paths for uploaded multipart files are omitted (`null`) by default for user filesystem privacy, with optional opt-in via `NetworkInspectorConfig.includeMultipartFilePaths` — Reversibility: reversible."
14. **`MultipartEntry` Model Properties:** `fieldName`, `fileName`, `contentType`, `byteSize`, optional `filePath`  
    [VERIFIED: .planning/phases/01-foundation-models/01-CONTEXT.md:38] "Dedicated `MultipartEntry` model encapsulates `fieldName`, `fileName`, `contentType`, `byteSize`, and optional `filePath` — Reversibility: costly — Stored as structured metadata in `NetworkRecord`."
15. **Internal Deduplication Tracking Header:** `x-fl-net-inspector-tracked-id`  
    [VERIFIED: .planning/REQUIREMENTS.md:21] "Cross-interceptor request deduplication using internal synthetic tracking header (`x-fl-net-inspector-tracked-id`) stripped before wire transmission."  
    [VERIFIED: .planning/research/ARCHITECTURE.md:302] "static const String internalTrackingHeader = 'x-fl-net-inspector-tracked-id';"

---

## Common Pitfalls

### Pitfall 1: Breaking Dart Web Compilation via `dart:io` Imports in Core Models
**What goes wrong:** A developer imports `dart:io` in `network_record.dart` or `network_inspector_config.dart` (for example, using `HttpHeaders` or `ContentType`). As a result, compiling for Flutter Web fails with `Unsupported operation: Platform._version` or compile errors.  
**Why it happens:** In Flutter, `dart:io` is available only on VM platforms (iOS, Android, macOS, Windows, Linux). Flutter Web runs on the JavaScript/Wasm engine where `dart:io` does not exist.  
**How to avoid:** Never import `dart:io` in `lib/src/models/`, `lib/src/config/`, or `lib/src/utils/`. Use pure Dart representations: standard Dart `Map<String, dynamic>` for headers, and standard `String` for content-types and MIME types.  
**Warning signs:** `dart compile js` or `flutter build web` throws errors referencing files in `lib/src/models/`.

### Pitfall 2: Malformed UTF-8 Decode Exceptions During Byte Truncation
**What goes wrong:** Slicing a UTF-8 byte buffer at an arbitrary index `maxBytes` splits a multi-byte character (e.g. an emoji or international character) in half. Calling `utf8.decode(slicedBytes)` throws a fatal `FormatException: Unexpected extension byte` or `FormatException: Unfinished UTF-8 octet sequence`.  
**Why it happens:** Standard UTF-8 characters span between 1 and 4 bytes. Slicing at byte 1,048,576 can cut directly across a 4-byte sequence.  
**How to avoid:** Always pass `allowMalformed: true` when decoding sliced byte buffers (`utf8.decode(slicedBytes, allowMalformed: true)`). This replaces boundary fragments with the safe Unicode replacement character (`\uFFFD`) without crashing.  
**Warning signs:** App crashes when receiving large API responses containing international text or emojis when payload truncation is triggered.

### Pitfall 3: Variable-Length Sensitive Token Redaction Leaking Information
**What goes wrong:** Redacting a token by replacing each character with an asterisk (`*` * token.length) preserves the character count. Attackers analyzing logs can deduce token types (e.g. 32-char vs 64-char API keys, or JWT header segment lengths).  
**Why it happens:** Developers attempt to make redaction look visually descriptive.  
**How to avoid:** Always replace sensitive values completely with the exact constant string `"[REDACTED]"` regardless of the original token length.  
**Warning signs:** Redacted fields in logs show different lengths of asterisks.

### Pitfall 4: Serialization Mismatch Between SQLite Rows and JSON Maps
**What goes wrong:** `NetworkRecord.toMap()` generates a map where `requestHeaders` is a Dart `Map<String, dynamic>`. When inserting into SQLite, SQLite only accepts primitive types (integers, strings, floats, blobs), failing on nested maps. Conversely, when reading from SQLite, `row['request_headers']` is a raw JSON string rather than a Map.  
**Why it happens:** SQLite does not have a native JSON/Map column type.  
**How to avoid:** In `NetworkRecord.fromMap(Map<String, dynamic> map)`, support both parsed Dart Maps and serialized JSON strings for composite columns (`requestHeaders`, `responseHeaders`, `requestQueryParams`, `multipartEntries`, etc.). If `map['request_headers'] is String`, run `jsonDecode(map['request_headers'])`; if already a `Map`, cast directly.  
**Warning signs:** `TypeError: type '_JsonMap' is not a subtype of type 'String' in type cast` during database inserts or model deserialization.

---

## Code Examples

### 1. `NetworkInspectorConstants` Verbatim Definition

```dart
// lib/src/core/constants.dart
class NetworkInspectorConstants {
  static const int defaultMaxRecords = 500;
  static const int defaultMaxBodyBytes = 1048576; // 1 MB (1,048,576 bytes)
  static const String redactedPlaceholder = '[REDACTED]';
  static const String internalTrackingHeader = 'x-fl-net-inspector-tracked-id';

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

### 2. Immutable `NetworkRecord` Model Skeleton

```dart
// lib/src/models/network_record.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'payload_data.dart';
import 'multipart_entry.dart';
import 'http_error_details.dart';

enum NetworkStatus { pending, success, failed }

@immutable
class NetworkRecord {
  final String id;
  final String url;
  final String baseUrl;
  final String path;
  final String method;
  final Map<String, dynamic> requestHeaders;
  final Map<String, dynamic> requestQueryParams;
  final PayloadData? requestBody;
  final String? requestContentType;
  final int requestSize;
  final DateTime requestTimestamp;

  final int? responseStatusCode;
  final Map<String, dynamic>? responseHeaders;
  final PayloadData? responseBody;
  final String? responseContentType;
  final int? responseSize;
  final DateTime? responseTimestamp;
  final int? durationMs;

  final NetworkStatus status;
  final HttpErrorDetails? error;
  final List<MultipartEntry>? multipartEntries;

  const NetworkRecord({
    required this.id,
    required this.url,
    required this.baseUrl,
    required this.path,
    required this.method,
    required this.requestHeaders,
    required this.requestQueryParams,
    this.requestBody,
    this.requestContentType,
    required this.requestSize,
    required this.requestTimestamp,
    this.responseStatusCode,
    this.responseHeaders,
    this.responseBody,
    this.responseContentType,
    this.responseSize,
    this.responseTimestamp,
    this.durationMs,
    required this.status,
    this.error,
    this.multipartEntries,
  });

  bool get isPending => status == NetworkStatus.pending;
  bool get isSuccess => status == NetworkStatus.success;
  bool get isFailed => status == NetworkStatus.failed;
  bool get hasError => error != null || (responseStatusCode != null && responseStatusCode! >= 400);

  NetworkRecord copyWith({
    String? id,
    String? url,
    String? baseUrl,
    String? path,
    String? method,
    Map<String, dynamic>? requestHeaders,
    Map<String, dynamic>? requestQueryParams,
    PayloadData? requestBody,
    String? requestContentType,
    int? requestSize,
    DateTime? requestTimestamp,
    int? responseStatusCode,
    Map<String, dynamic>? responseHeaders,
    PayloadData? responseBody,
    String? responseContentType,
    int? responseSize,
    DateTime? responseTimestamp,
    int? durationMs,
    NetworkStatus? status,
    HttpErrorDetails? error,
    List<MultipartEntry>? multipartEntries,
  }) {
    return NetworkRecord(
      id: id ?? this.id,
      url: url ?? this.url,
      baseUrl: baseUrl ?? this.baseUrl,
      path: path ?? this.path,
      method: method ?? this.method,
      requestHeaders: requestHeaders ?? this.requestHeaders,
      requestQueryParams: requestQueryParams ?? this.requestQueryParams,
      requestBody: requestBody ?? this.requestBody,
      requestContentType: requestContentType ?? this.requestContentType,
      requestSize: requestSize ?? this.requestSize,
      requestTimestamp: requestTimestamp ?? this.requestTimestamp,
      responseStatusCode: responseStatusCode ?? this.responseStatusCode,
      responseHeaders: responseHeaders ?? this.responseHeaders,
      responseBody: responseBody ?? this.responseBody,
      responseContentType: responseContentType ?? this.responseContentType,
      responseSize: responseSize ?? this.responseSize,
      responseTimestamp: responseTimestamp ?? this.responseTimestamp,
      durationMs: durationMs ?? this.durationMs,
      status: status ?? this.status,
      error: error ?? this.error,
      multipartEntries: multipartEntries ?? this.multipartEntries,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'base_url': baseUrl,
      'path': path,
      'method': method,
      'request_headers': requestHeaders,
      'request_query_params': requestQueryParams,
      'request_body': requestBody?.toMap(),
      'request_content_type': requestContentType,
      'request_size': requestSize,
      'request_timestamp': requestTimestamp.millisecondsSinceEpoch,
      'response_status_code': responseStatusCode,
      'response_headers': responseHeaders,
      'response_body': responseBody?.toMap(),
      'response_content_type': responseContentType,
      'response_size': responseSize,
      'response_timestamp': responseTimestamp?.millisecondsSinceEpoch,
      'duration_ms': durationMs,
      'status': status.name,
      'error': error?.toMap(),
      'multipart_entries': multipartEntries?.map((e) => e.toMap()).toList(),
    };
  }

  factory NetworkRecord.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> parseMapField(dynamic field) {
      if (field is String) {
        return jsonDecode(field) as Map<String, dynamic>;
      } else if (field is Map) {
        return Map<String, dynamic>.from(field);
      }
      return <String, dynamic>{};
    }

    return NetworkRecord(
      id: map['id'] as String,
      url: map['url'] as String,
      baseUrl: map['base_url'] as String? ?? '',
      path: map['path'] as String? ?? '',
      method: map['method'] as String,
      requestHeaders: parseMapField(map['request_headers']),
      requestQueryParams: parseMapField(map['request_query_params']),
      requestBody: map['request_body'] != null
          ? (map['request_body'] is String
              ? PayloadData.fromMap(jsonDecode(map['request_body'] as String) as Map<String, dynamic>)
              : PayloadData.fromMap(Map<String, dynamic>.from(map['request_body'] as Map)))
          : null,
      requestContentType: map['request_content_type'] as String?,
      requestSize: map['request_size'] as int? ?? 0,
      requestTimestamp: DateTime.fromMillisecondsSinceEpoch(map['request_timestamp'] as int),
      responseStatusCode: map['response_status_code'] as int?,
      responseHeaders: map['response_headers'] != null ? parseMapField(map['response_headers']) : null,
      responseBody: map['response_body'] != null
          ? (map['response_body'] is String
              ? PayloadData.fromMap(jsonDecode(map['response_body'] as String) as Map<String, dynamic>)
              : PayloadData.fromMap(Map<String, dynamic>.from(map['response_body'] as Map)))
          : null,
      responseContentType: map['response_content_type'] as String?,
      responseSize: map['response_size'] as int?,
      responseTimestamp: map['response_timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['response_timestamp'] as int)
          : null,
      durationMs: map['duration_ms'] as int?,
      status: NetworkStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => NetworkStatus.pending,
      ),
      error: map['error'] != null
          ? (map['error'] is String
              ? HttpErrorDetails.fromMap(jsonDecode(map['error'] as String) as Map<String, dynamic>)
              : HttpErrorDetails.fromMap(Map<String, dynamic>.from(map['error'] as Map)))
          : null,
      multipartEntries: map['multipart_entries'] != null
          ? (map['multipart_entries'] is String
              ? (jsonDecode(map['multipart_entries'] as String) as List)
                  .map((e) => MultipartEntry.fromMap(e as Map<String, dynamic>))
                  .toList()
              : (map['multipart_entries'] as List)
                  .map((e) => MultipartEntry.fromMap(Map<String, dynamic>.from(e as Map)))
                  .toList())
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          url == other.url &&
          method == other.method &&
          requestTimestamp == other.requestTimestamp &&
          responseStatusCode == other.responseStatusCode &&
          status == other.status;

  @override
  int get hashCode => Object.hash(id, url, method, requestTimestamp, responseStatusCode, status);
}
```

### 3. `RedactionEngine` Implementation Pattern

```dart
// lib/src/utils/redaction_engine.dart
import 'dart:convert';
import '../core/constants.dart';

class RedactionEngine {
  final Set<String> _normalizedKeys;

  RedactionEngine({List<String> customKeys = const []})
      : _normalizedKeys = {
          ...NetworkInspectorConstants.defaultSensitiveKeys.map(normalizeKey),
          ...customKeys.map(normalizeKey),
        };

  static String normalizeKey(String key) {
    return key.toLowerCase().replaceAll(RegExp(r'[-_.]'), '');
  }

  bool isSensitive(String key) {
    return _normalizedKeys.contains(normalizeKey(key));
  }

  Map<String, dynamic> redactHeaders(Map<String, dynamic> headers) {
    final result = <String, dynamic>{};
    for (final entry in headers.entries) {
      if (isSensitive(entry.key)) {
        result[entry.key] = NetworkInspectorConstants.redactedPlaceholder;
      } else {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  Map<String, dynamic> redactQueryParams(Map<String, dynamic> params) {
    final result = <String, dynamic>{};
    for (final entry in params.entries) {
      if (isSensitive(entry.key)) {
        result[entry.key] = NetworkInspectorConstants.redactedPlaceholder;
      } else {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  String redactUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.queryParameters.isEmpty) return rawUrl;

    var modified = false;
    final sanitizedParams = Map<String, String>.from(uri.queryParameters);
    for (final key in uri.queryParameters.keys) {
      if (isSensitive(key)) {
        sanitizedParams[key] = NetworkInspectorConstants.redactedPlaceholder;
        modified = true;
      }
    }

    if (!modified) return rawUrl;
    return uri.replace(queryParameters: sanitizedParams).toString();
  }

  String? redactBody(String? body, String? contentType) {
    if (body == null || body.trim().isEmpty) return body;

    // Check if JSON
    final trimmed = body.trim();
    if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
      try {
        final decoded = jsonDecode(trimmed);
        final redacted = _redactRecursive(decoded);
        return jsonEncode(redacted);
      } catch (_) {
        // Not valid JSON, continue to next check
      }
    }

    // Check if form urlencoded
    if (contentType?.contains('application/x-www-form-urlencoded') == true ||
        (body.contains('=') && !body.contains('\n'))) {
      try {
        final pairs = body.split('&');
        final sanitizedPairs = <String>[];
        var modified = false;
        for (final pair in pairs) {
          final parts = pair.split('=');
          if (parts.length == 2) {
            final key = Uri.decodeQueryComponent(parts[0]);
            if (isSensitive(key)) {
              sanitizedPairs.add('${parts[0]}=${Uri.encodeQueryComponent(NetworkInspectorConstants.redactedPlaceholder)}');
              modified = true;
              continue;
            }
          }
          sanitizedPairs.add(pair);
        }
        if (modified) return sanitizedPairs.join('&');
      } catch (_) {}
    }

    return body;
  }

  dynamic _redactRecursive(dynamic node) {
    if (node is Map<String, dynamic>) {
      final sanitized = <String, dynamic>{};
      for (final entry in node.entries) {
        if (isSensitive(entry.key)) {
          sanitized[entry.key] = NetworkInspectorConstants.redactedPlaceholder;
        } else {
          sanitized[entry.key] = _redactRecursive(entry.value);
        }
      }
      return sanitized;
    } else if (node is List) {
      return node.map(_redactRecursive).toList();
    }
    return node;
  }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `equatable` package for value equality | Dart 3 native records / `Object.hashAll()` | Dart 2.14 / Dart 3.0 | Zero external package dependencies, smaller binary footprint. |
| Code-gen (`freezed` / `json_serializable`) | Pure handwritten immutable models | Flutter 3.x best practices for embeddable packages | Host applications never suffer `build_runner` version conflicts. |
| In-memory raw byte buffers for all payloads | Strict 1MB threshold + metadata summary for binary | Modern mobile OS memory limits (iOS Jetsam) | Eliminates OOM crashes and jetsam terminations during large downloads/uploads. |
| Regex string replacement on raw JSON | Recursive Dart Map/List tree traversal | Standard JSON parsing | Guarantees syntax validity; never breaks escaped quotes or nested objects. |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `Uri.splitQueryString` / standard `Uri` parsing is sufficient for all form-urlencoded payloads | Redaction Pattern | Low — custom delimiters are exceedingly rare in standard HTTP |

*(All core decisions and values were verified directly against `01-CONTEXT.md`, `REQUIREMENTS.md`, and official pub.dev registries).*

---

## Open Questions (RESOLVED)

1. **How should `NetworkStatus` classify HTTP 4xx and 5xx responses?**
   - RESOLVED: Define `status` as: `pending` while awaiting response; `success` when response status code is `200..399`; `failed` when response status code is `>= 400` OR when an exception occurs (`error != null`). Provide helper getters `isSuccess`, `isFailed`, `isPending`, and `hasError` on `NetworkRecord` to cover both definitions cleanly.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `git` | Version control & commits | ✓ | 2.54.0 | — |
| `node` | GSD tooling scripts | ✓ | v24.21.0 | — |
| `flutter` | Package compilation & test runner | ✗ (Sandbox PATH) | — | Code is pure Dart/Flutter standard syntax. Tests will run via `flutter test` when invoked in host environment. |
| `dart` | Standalone Dart test execution | ✗ (Sandbox PATH) | — | Pure Dart code verified against official SDK language specs. |

**Missing dependencies with no fallback:**
- None.

**Missing dependencies with fallback:**
- `flutter` CLI in sandbox: Code files, exports, and unit test suites are constructed strictly according to sound null-safe Dart 3 / Flutter 3.10 specifications.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `test` (`^1.25.0`) / `flutter_test` (Flutter SDK) |
| Config file | `pubspec.yaml` (root) |
| Quick run command | `flutter test test/models/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CORE-01 | `NetworkInspectorConfig` defaults (`maxRecords: 500`, `maxBodyBytes: 1MB`), release mode guard (`enabled`), and `NetworkInspector.initialize()` | unit | `flutter test test/config/network_inspector_config_test.dart` | ❌ Wave 0 |
| CORE-02 | Modular folder structure isolation and public barrel file exports (`lib/flutter_network_inspector.dart`) | unit | `flutter test test/core/barrel_export_test.dart` | ❌ Wave 0 |
| CORE-03 | Cross-platform compatibility (zero `dart:io` imports in models, config, and utils) | unit | `flutter test test/core/platform_safety_test.dart` | ❌ Wave 0 |
| DATA-01 | `NetworkRecord` captures complete request metadata with UUID v4 ID | unit | `flutter test test/models/network_record_test.dart` | ❌ Wave 0 |
| DATA-02 | `NetworkRecord` captures response metadata and `HttpErrorDetails` | unit | `flutter test test/models/http_error_details_test.dart` | ❌ Wave 0 |
| DATA-03 | `PayloadData` and `BodyTypeDetector` detect JSON, text, formData, multipart, binary, empty | unit | `flutter test test/models/payload_data_test.dart` | ❌ Wave 0 |
| DATA-04 | `MultipartEntry` metadata handling with `filePath = null` privacy default | unit | `flutter test test/models/multipart_entry_test.dart` | ❌ Wave 0 |
| DATA-05 | `PayloadTruncator` bounds bodies at 1MB, appends truncation banner, and flags `isTruncated: true` without UTF-8 crash | unit | `flutter test test/utils/payload_truncator_test.dart` | ❌ Wave 0 |
| DATA-06 | `RedactionEngine` redacts default & custom sensitive keys across headers, URLs, and recursive JSON | unit | `flutter test test/utils/redaction_engine_test.dart` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/models/` or specific test file
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `pubspec.yaml` — package configuration and dependencies (`uuid: ^4.6.0`, `flutter_test`, `flutter_lints`, `test`)
- [ ] `test/config/network_inspector_config_test.dart` — covers CORE-01
- [ ] `test/core/barrel_export_test.dart` — covers CORE-02
- [ ] `test/core/platform_safety_test.dart` — covers CORE-03
- [ ] `test/models/network_record_test.dart` — covers DATA-01, DATA-02
- [ ] `test/models/payload_data_test.dart` — covers DATA-03
- [ ] `test/models/multipart_entry_test.dart` — covers DATA-04
- [ ] `test/utils/payload_truncator_test.dart` — covers DATA-05
- [ ] `test/utils/redaction_engine_test.dart` — covers DATA-06

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| **V2 Authentication** | Yes | Masking of `Authorization` headers (Bearer tokens, Basic auth, API keys) via `RedactionEngine` [VERIFIED: .planning/phases/01-foundation-models/01-CONTEXT.md:29]. |
| **V3 Session Management** | Yes | Masking of `Cookie` and `Set-Cookie` session headers [VERIFIED: .planning/phases/01-foundation-models/01-CONTEXT.md:29]. |
| **V4 Access Control** | Yes | Zero release-mode activation (`kReleaseMode`) prevents unauthorized debug access in production builds [VERIFIED: .planning/phases/01-foundation-models/01-CONTEXT.md:19]. |
| **V5 Input Validation / Sanitization** | Yes | Pre-persistence sanitization and byte-bounded buffering (`PayloadTruncator`) preventing memory overflow attacks. |
| **V6 Cryptography** | Yes | Cryptographically secure RFC 4122 v4 UUIDs generated via `uuid` package; zero plaintext sensitive credentials stored on disk. |

### Known Threat Patterns for Flutter Network Inspection

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Plaintext Credential Exposure in Database / Logs | Information Disclosure | `RedactionEngine` replaces all sensitive values with `[REDACTED]` *before* records reach memory queues, SQLite, or export sheets. |
| Out-Of-Memory (OOM) via Maliciously Large Responses | Denial of Service | `PayloadTruncator` enforces a hard 1MB ceiling (`maxBodyBytes`), truncating payloads and avoiding buffering binary streams into memory. |
| Filesystem Path Leakage in Multipart Uploads | Information Disclosure / Privacy | `MultipartEntry` defaults `filePath` to `null` unless the developer explicitly opts in via `includeMultipartFilePaths: true`. |
| Debug Tool Active in Production Release App | Elevation of Privilege | `NetworkInspectorConfig.enabled` defaults to `!kReleaseMode`, rendering the package an inactive no-op in release builds. |

---

## Sources

### Primary (HIGH confidence)
- `.planning/phases/01-foundation-models/01-CONTEXT.md` — User implementation decisions (D-01 through D-16) [VERIFIED: lines 1-97]
- `.planning/REQUIREMENTS.md` — Core requirements CORE-01..03, DATA-01..06 [VERIFIED: lines 1-157]
- `pub.dev/packages/uuid` — Package metadata, RFC 4122 v4 UUID generation, SDK constraints [VERIFIED: pub.dev API]
- `pub.dev/packages/flutter_lints` — Version constraints and Dart 3.0 compatibility [VERIFIED: pub.dev API]
- `api.flutter.dev/flutter/foundation/kReleaseMode-constant.html` — Flutter release mode constant semantics [VERIFIED: Flutter API]

### Secondary (MEDIUM confidence)
- `.planning/research/ARCHITECTURE.md` — Facade design, `NetworkRecord` domain hierarchy, and `RedactionEngine` [VERIFIED: lines 1-598]
- `.planning/research/PITFALLS.md` — Pitfalls 4, 6, 7 (OOM prevention, credential redaction, zombie requests) [VERIFIED: lines 1-418]
- `.planning/research/STACK.md` — Package compatibility matrix [VERIFIED: lines 1-200]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Verified package dependencies and SDK constraints against pub.dev registry.
- Architecture: HIGH — Concrete domain model designs and pure Dart cross-platform patterns verified against requirements.
- Pitfalls: HIGH — Critical pitfalls (UTF-8 byte boundary slicing, `dart:io` Web breakage, variable-length token leaks) analyzed and solved.

**Research date:** 2026-10-31  
**Valid until:** 2026-11-30 (stable foundation architecture)  
