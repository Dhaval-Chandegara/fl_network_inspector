# Phase 1: Foundation & Models - Context

**Gathered:** 2026-10-31  
**Status:** Ready for planning  

<domain>
## Phase Boundary

Establish foundational package configuration (`NetworkInspectorConfig`), immutable network transaction domain models (`NetworkRecord`, `PayloadData`, `MultipartEntry`, `HttpErrorDetails`), memory payload truncator (`PayloadTruncator`), and sensitive data redaction engine (`RedactionEngine`) with cross-platform Dart/Flutter compatibility and zero-overhead release mode guards.

</domain>

<decisions>
## Implementation Decisions

### Configuration & Defaults
- **D-01:** Default `maxRecords` retention limit is 500 records before FIFO pruning — **Reversibility:** costly — SQLite table schema and pruning logic will depend on this default, though configurable via `NetworkInspectorConfig`.
- **D-02:** Default maximum body size threshold before truncation is 1 MB (1,048,576 bytes) — **Reversibility:** reversible — Configurable ceiling applied in `PayloadTruncator`.
- **D-03:** Production release safeguard (`kReleaseMode`) is disabled by default, but allows an explicit override (e.g. `enabled: true`) for staging/internal builds — **Reversibility:** costly — Affects facade initialization guards across mobile platforms.
- **D-04:** Granular feature flags (`enableAutoCapture`, `enableShakeDetection`, `enableDatabase`) can be toggled independently in `NetworkInspectorConfig` — **Reversibility:** reversible — Independent flags stored on config object.

### Domain Models & Immutability
- **D-05:** Unified `NetworkRecord` model tracks the complete HTTP lifecycle (in-flight, completed, failed) with nullable response and error fields, plus an explicit `NetworkStatus` enum (`pending`, `success`, `failed`) — **Reversibility:** one-way — Core database entity and repository queries depend on this unified record schema.
- **D-06:** Pure handwritten Dart 3 immutable classes with `copyWith`, `toMap`, `fromMap`, and value equality (`==` / `hashCode`) with zero code generation dependencies (`build_runner`, `freezed`, or `json_serializable`) — **Reversibility:** costly — Standardizes all domain models across the package.
- **D-07:** Dedicated `PayloadData` class encapsulates body content string, byte size, detected `BodyType` enum (`json`, `text`, `formData`, `multipart`, `binary`, `empty`), and `isTruncated` boolean flag — **Reversibility:** costly — Consumed across models, database tables, and UI inspector tabs.
- **D-08:** RFC 4122 v4 UUID string generated at request inception for unique transaction identification, cross-interceptor tracking, and deduplication — **Reversibility:** one-way — Database primary keys and inter-layer tracking headers rely on UUID strings.

### Sensitive Data Redaction
- **D-09:** Comprehensive default sensitive key blacklist covering `authorization`, `cookie`, `set-cookie`, `token`, `access_token`, `refresh_token`, `password`, `secret`, `api_key`, `apikey`, `private_key` — **Reversibility:** reversible — Developers can append custom keys via `NetworkInspectorConfig.customRedactionKeys`.
- **D-10:** Deep recursive traversal scans nested JSON maps and lists at any nesting depth to sanitize sensitive keys — **Reversibility:** reversible — Implemented inside `RedactionEngine`.
- **D-11:** Case-insensitive exact and normalized pattern matching handles kebab-case, snake_case, and camelCase variants (e.g. matching `api-key`, `apiKey`, `API_KEY`) — **Reversibility:** reversible — Centralized in `RedactionEngine`.
- **D-12:** Constant string `"[REDACTED]"` replaces sensitive values completely to avoid token length, character count, or entropy leakage — **Reversibility:** reversible.

### Payload Truncation & Multipart Handling
- **D-13:** Oversized payload bodies are truncated to the configured byte limit with appended `\n\n[Payload truncated at X bytes]` banner and `isTruncated: true` set on `PayloadData` — **Reversibility:** reversible.
- **D-14:** Binary request and response streams (e.g. images, audio, video, zip) are not buffered into strings; instead, they are represented with a metadata summary banner `[Binary data: <mime_type>, <size_bytes>]` — **Reversibility:** reversible.
- **D-15:** Local filesystem paths for uploaded multipart files are omitted (`null`) by default for user filesystem privacy, with optional opt-in via `NetworkInspectorConfig.includeMultipartFilePaths` — **Reversibility:** reversible.
- **D-16:** Dedicated `MultipartEntry` model encapsulates `fieldName`, `fileName`, `contentType`, `byteSize`, and optional `filePath` — **Reversibility:** costly — Stored as structured metadata in `NetworkRecord`.

### the agent's Discretion
- Package folder structure under `lib/src/` organized into `core/`, `config/`, `models/`, and `utils/`.
- Detection heuristics for `BodyType` based on `content-type` header and content inspection.
- Pure Dart utility for byte sizing and string truncation.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Package Specifications & Guidelines
- `.planning/PROJECT.md` — Overall product goals, constraints, and architecture.
- `.planning/REQUIREMENTS.md` — Checkable requirements: `CORE-01..03` and `DATA-01..06`.
- `.planning/research/STACK.md` — Verified Dart/Flutter libraries (`uuid: ^4.6.0`, `intl: ^0.20.3`) and SDK version boundaries (`sdk: '>=3.0.0 <4.0.0'`).
- `.planning/research/ARCHITECTURE.md` § Layer 1 & 3 — Facade design, `NetworkRecord` domain hierarchy, and `RedactionEngine`.
- `.planning/research/PITFALLS.md` § Pitfall 4 & 6 — Out-of-memory prevention (1MB limits) and plaintext credential leak mitigations.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Greenfield codebase; foundational models and utilities created in this phase will become the reusable core for Phase 2 (SQLite) and Phase 3 (Interception).

### Established Patterns
- Pure sound null-safe Dart 3 classes with immutable value semantics.
- Zero-codegen architecture ensuring rapid consumer compilation without `build_runner` version conflicts.

### Integration Points
- `NetworkInspectorConfig` is passed into `NetworkInspector.initialize()`.
- `NetworkRecord` is consumed by `NetworkInspectorRepository` (Phase 2), `HttpOverrides` / Dio interceptor (Phase 3), and UI widgets (Phase 4).
- `RedactionEngine` and `PayloadTruncator` run synchronously in the ingestion pipeline before disk persistence.

</code_context>

<specifics>
## Specific Ideas

- The public configuration class should provide clean static defaults (e.g. `const NetworkInspectorConfig()`) with named parameters for easy customization.
- Models should provide standard `toMap()` and `fromMap()` methods compatible with SQLite column types and JSON serialization.

</specifics>

<deferred>
## Deferred Ideas

- None — all discussed decisions directly support Phase 1 scope.

</deferred>

---

*Phase: 1-Foundation & Models*  
*Context gathered: 2026-10-31*
