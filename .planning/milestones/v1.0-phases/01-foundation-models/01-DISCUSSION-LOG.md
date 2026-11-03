# Phase 1: Foundation & Models - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-10-31  
**Phase:** 1-Foundation & Models  
**Areas discussed:** Configuration & Defaults, Domain Models & Immutability, Sensitive Data Redaction, Payload Truncation & Multipart Handling  

---

## Configuration & Defaults

| Option | Description | Selected |
|--------|-------------|----------|
| 500 records | Balanced capacity for standard debugging sessions without storage bloat | ✓ |
| 200 records | Lightweight, minimal memory and storage footprint | |
| 1000 records | Extended history for heavy background sync testing | |

**User's choice:** 500 records  
**Notes:** Sets baseline FIFO auto-pruning threshold in SQLite storage.

| Option | Description | Selected |
|--------|-------------|----------|
| 1 MB (1,048,576 bytes) | Industry standard balance capturing full JSON responses while preventing OOM crashes | ✓ |
| 500 KB | Conservative limit optimized for constrained devices | |
| 2 MB | Higher ceiling for data-heavy endpoints | |

**User's choice:** 1 MB  
**Notes:** Hard truncation ceiling preventing OOM spikes from massive responses.

| Option | Description | Selected |
|--------|-------------|----------|
| Disabled in release by default, but allow explicit override | Default `kReleaseMode` no-op with option to enable for staging | ✓ |
| Strict compile-time kill-switch | Complete removal in release mode with zero override allowed | |

**User's choice:** Disabled in release by default, but allow explicit override  
**Notes:** Allows QA/internal enterprise builds running release mode to test network inspection when explicitly passed `enabled: true`.

| Option | Description | Selected |
|--------|-------------|----------|
| Granular toggles | `enableAutoCapture`, `enableShakeDetection`, `enableDatabase` can be toggled independently | ✓ |
| All-or-nothing master switch | Preset profiles only | |

**User's choice:** Granular toggles  
**Notes:** Provides maximum developer flexibility for different testing environments.

---

## Domain Models & Immutability

| Option | Description | Selected |
|--------|-------------|----------|
| Unified `NetworkRecord` | Single model tracking complete lifecycle (in-flight, completed, failed) with nullable response/error fields | ✓ |
| Split models | Separate `NetworkRequest` and `NetworkResponse` objects linked by transaction ID | |

**User's choice:** Unified `NetworkRecord`  
**Notes:** Simplifies database representation, state management, and UI rendering.

| Option | Description | Selected |
|--------|-------------|----------|
| Pure handwritten Dart 3 | Immutable classes with `copyWith`, `toMap`, `fromMap` (zero code generation dependencies) | ✓ |
| Freezed / json_serializable | Code generation | |

**User's choice:** Pure handwritten Dart 3  
**Notes:** Eliminates `build_runner` overhead, dependency conflicts, and slow compile times for package consumers.

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated `PayloadData` class | Encapsulates content string, byte size, detected `BodyType` enum, and truncation flag | ✓ |
| Raw string / map directly | String or dynamic map directly in record | |

**User's choice:** Dedicated `PayloadData` class  
**Notes:** Clean abstraction for both request and response payload management.

| Option | Description | Selected |
|--------|-------------|----------|
| RFC 4122 v4 UUID | Collision-free string ID generated at request inception for tracking and deduplication | ✓ |
| Auto-increment integer | SQLite sequence derived integer ID | |

**User's choice:** RFC 4122 v4 UUID  
**Notes:** Enables tagging requests before database insertion and tracking across interceptors.

---

## Sensitive Data Redaction

| Option | Description | Selected |
|--------|-------------|----------|
| Comprehensive defaults | `authorization`, `cookie`, `set-cookie`, `token`, `access_token`, `refresh_token`, `password`, `secret`, `api_key`, `apikey`, `private_key` | ✓ |
| Minimal defaults | `authorization`, `password`, `cookie` only | |

**User's choice:** Comprehensive defaults  
**Notes:** Safe out-of-the-box security preventing accidental token leaks.

| Option | Description | Selected |
|--------|-------------|----------|
| Deep recursive traversal | Traverse nested JSON maps and lists to redact sensitive keys at any nesting depth | ✓ |
| Shallow top-level traversal | Redact only root JSON keys | |

**User's choice:** Deep recursive traversal  
**Notes:** Essential for securing nested JSON payloads (e.g. `{ "data": { "token": "..." } }`).

| Option | Description | Selected |
|--------|-------------|----------|
| Case-insensitive & normalized match | Matches `apiKey`, `api_key`, `API-KEY` | ✓ |
| Strict case-sensitive match | Exact string match only | |

**User's choice:** Case-insensitive & normalized match  
**Notes:** Prevents bypasses due to header or JSON key casing variations.

| Option | Description | Selected |
|--------|-------------|----------|
| Constant string `"[REDACTED]"` | Complete replacement preventing token length or entropy leakage | ✓ |
| Partial mask | Show first and last 2 characters | |

**User's choice:** Constant string `"[REDACTED]"`  
**Notes:** Completely sanitizes sensitive data from disk and share exports.

---

## Payload Truncation & Multipart Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Suffix banner + metadata flag | Append `\n\n[Payload truncated at 1MB]` and set `isTruncated: true` in PayloadData | ✓ |
| Silent cut-off | Truncate string silently and rely strictly on boolean flag | |

**User's choice:** Suffix banner + metadata flag  
**Notes:** Clear visual feedback in both UI and raw log exports.

| Option | Description | Selected |
|--------|-------------|----------|
| Metadata summary banner | Do not buffer binary streams into strings; record `[Binary data: <mime_type>, <size_bytes>]` | ✓ |
| Base64 encoding | Base64 encode up to limit | |

**User's choice:** Metadata summary banner  
**Notes:** Prevents massive memory allocation and database bloat for images/videos.

| Option | Description | Selected |
|--------|-------------|----------|
| Opt-in via config (`includeMultipartFilePaths: false`) | Protects user filesystem privacy by default | ✓ |
| Always include file paths | Always capture local filesystem paths | |

**User's choice:** Opt-in via config  
**Notes:** Protects sensitive local file paths from leaking into logs or exports.

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated `MultipartEntry` model | Captures `fieldName`, `fileName`, `contentType`, `byteSize`, and optional `filePath` | ✓ |
| Generic key-value map | Inside request body string | |

**User's choice:** Dedicated `MultipartEntry` model  
**Notes:** Clean, structured presentation in UI and reliable serialization.

---

## the agent's Discretion

- Concrete package structure under `lib/src/` with clear directory boundaries (`core`, `config`, `models`, `utils`).
- Automated MIME type detection heuristics for identifying JSON, XML, HTML, and binary payloads.

## Deferred Ideas

- None — discussion stayed within Phase 1 scope.
