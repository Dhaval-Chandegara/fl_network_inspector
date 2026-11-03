# Phase 3: Network Capture & Interceptors - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-11-01  
**Phase:** 3-Network Capture & Interceptors  
**Areas discussed:** Deduplication & Request Filtering, HttpOverrides Scope & Chaining, Response Stream Buffering & Chunked/SSE, Manual Logging API DX  

---

## Deduplication & Request Filtering

### Question 1: How should HttpOverrides detect and suppress duplicate requests initiated by client adapters (Dio/http)?

| Option | Description | Selected |
|--------|-------------|:--------:|
| Synthetic header (`x-network-inspector-id: <uuid>`) stripped before transmission | Dio/http adds UUID; HttpOverrides checks it, suppresses duplicate capture, and removes header before wire transmission so backend never sees it | ✓ |
| In-memory fingerprint matching | Match URL + Method + body hash in an in-flight cache within a 500ms window without modifying request headers | |
| You decide | Let Antigravity pick the cleanest, lowest-overhead mechanism | |

**User's choice:** Synthetic header (`x-network-inspector-id: <uuid>`) stripped before transmission  
**Notes:** Ensures robust tracking across nested layers without wire payload modifications visible to backend servers.

### Question 2: How should client adapters handle nested or duplicate interceptor registrations on the same client?

| Option | Description | Selected |
|--------|-------------|:--------:|
| Request metadata tagging | Use Dio's `RequestOptions.extra` and an internal tracking flag to prevent double-capturing if an interceptor is registered multiple times | ✓ |
| Global object identity WeakSet | Track in-flight request instances in an in-memory WeakSet/TTL cache to ensure each request instance is processed at most once | |
| You decide | Antigravity decides the most robust approach | |

**User's choice:** Request metadata tagging (Use Dio's `RequestOptions.extra` and an internal tracking flag)  
**Notes:** Prevents duplicate capture if a consumer accidentally registers `NetworkInspectorDioInterceptor` more than once.

### Question 3: When a request is automatically retried or redirected (e.g. HTTP 301/302, Dio retry interceptors), how should it be recorded?

| Option | Description | Selected |
|--------|-------------|:--------:|
| Log each attempt/redirect as a distinct record with shared parent/correlation ID or separate UUID | Developers can clearly see the initial 302/timeout and subsequent retry | ✓ |
| Coalesce into single record | Update original record with final status and response, recording retry count in metadata | |
| You decide | Antigravity decides the clearest debugging DX | |

**User's choice:** Log each attempt/redirect as a distinct record with shared parent/correlation ID or separate UUID  
**Notes:** Maximum visibility into the full network hop sequence.

### Question 4: Should the interceptors support ignoring specific domains or URL patterns (e.g., Firebase, Sentry, analytics pings) before capture?

| Option | Description | Selected |
|--------|-------------|:--------:|
| Configurable `ignoredHosts` and URL pattern blacklist in `NetworkInspectorConfig` | Bypasses capture early for analytics, logging services, or custom domains without modifying requests | ✓ |
| Header-based opt-out | `x-network-inspector-ignore: true` header attached by developer to bypass interception | |
| Capture all traffic unconditionally | No host/URL ignoring; rely solely on UI search/filtering | |
| You decide | Antigravity decides the most flexible design | |

**User's choice:** Configurable `ignoredHosts` and URL pattern blacklist in `NetworkInspectorConfig`  
**Notes:** Prevents database log noise from third-party telemetry and metrics endpoints.

---

## HttpOverrides Scope & Chaining

### Question 1: How should HttpOverrides be enabled in the application lifecycle?

| Option | Description | Selected |
|--------|-------------|:--------:|
| Automatic activation in `NetworkInspector.initialize()` when `enableAutoCapture: true`, plus explicit `startAutoCapture()` / `stopAutoCapture()` and `runZoned()` helpers | Comprehensive lifecycle and scoping options | ✓ |
| Manual opt-in only | Never set `HttpOverrides.global` automatically; require consumer app to explicitly call `NetworkInspector.startAutoCapture()` | |
| You decide | Antigravity decides the cleanest DX | |

**User's choice:** Automatic activation in `NetworkInspector.initialize()` when `enableAutoCapture: true`, plus explicit helpers  
**Notes:** Zero-configuration default with fine-grained control when needed.

### Question 2: How should pre-existing HttpOverrides be chained and preserved?

| Option | Description | Selected |
|--------|-------------|:--------:|
| Delegate client creation to `previous.createHttpClient(context)` and proxy lookup to `previous.findProxyFromEnvironment(url, environment)` | Preserves corporate proxy settings, custom SSL certs, and VPN configs | ✓ |
| Wrap newly instantiated `HttpClient(context: context)` and only delegate `findProxyFromEnvironment` | Ignores previous custom client factories but retains proxy settings | |
| You decide | Antigravity decides the most reliable chaining architecture | |

**User's choice:** Delegate client creation to `previous.createHttpClient(context)` and proxy lookup to `previous.findProxyFromEnvironment(url, environment)`  
**Notes:** Critical safety pattern preventing host application network breakages.

### Question 3: How should HttpClient delegator handle SSL certificates and configuration properties (e.g., badCertificateCallback, timeouts)?

| Option | Description | Selected |
|--------|-------------|:--------:|
| Full transparent proxying | Forward all getters/setters including `badCertificateCallback`, timeouts, and proxy authentication directly to the inner client so host behavior is 100% identical | ✓ |
| Enhanced security callback | Transparently forward user callback, but also intercept and log SSL handshake rejections as error records with certificate details | |
| You decide | Antigravity decides the safest, most transparent approach | |

**User's choice:** Full transparent proxying  
**Notes:** Ensures identical runtime behavior with zero interference with custom SSL certificates or timeouts.

### Question 4: How should HttpOverrides be cleaned up when stopAutoCapture() or NetworkInspector.dispose() is called?

| Option | Description | Selected |
|--------|-------------|:--------:|
| Restore exact previous override (`HttpOverrides.global = _previousOverrides`) on stop/dispose | Leaves zero residual hooks when uninstalled or stopped | ✓ |
| Keep wrapper active but toggle internal pass-through flag | Avoids modifying global static state again; subsequent calls bypass logging | |
| You decide | Antigravity decides the cleanest lifecycle contract | |

**User's choice:** Restore exact previous override (`HttpOverrides.global = _previousOverrides`) on stop/dispose  
**Notes:** Clean teardown leaving no dangling references.

---

## Response Stream Buffering & Chunked/SSE

### Question 1: How should single-subscription response streams be intercepted non-destructively?

| Option | Description | Selected |
|--------|-------------|:--------:|
| StreamTransformer proxy forwarding chunks transparently while buffering up to `maxBodyBytes` | Preserves exact single-subscription stream semantics and backpressure with zero host app impact | ✓ |
| Convert to StreamController.broadcast stream | Allows multiple listeners, but changes stream semantics and may affect backpressure | |
| You decide | Antigravity decides the safest streaming pattern | |

**User's choice:** StreamTransformer proxy forwarding chunks transparently while buffering up to `maxBodyBytes`  
**Notes:** Prevents `StateError: Stream has already been listened to`.

### Question 2: How should long-lived or infinite streams (e.g., SSE text/event-stream, live feeds) be captured?

| Option | Description | Selected |
|--------|-------------|:--------:|
| Progressive status update | Save status code & headers immediately upon arrival; mark body captured/truncated once `maxBodyBytes` reached or on stream done, avoiding indefinite pending state for SSE | ✓ |
| Strict onDone completion | Only finalize and record response body when stream emits `done` or closes | |
| You decide | Antigravity decides the best balance for stream inspection | |

**User's choice:** Progressive status update  
**Notes:** Immediate visibility for streaming and SSE connections.

### Question 3: How should detected binary response streams (images, audio, video, pdf, zip) be handled during streaming?

| Option | Description | Selected |
|--------|-------------|:--------:|
| Pure byte counting without buffering | Forward stream immediately while accumulating byte count; record `[Binary data: <mime_type>, <total_bytes>]` with zero memory allocation | ✓ |
| Buffer first 64KB snapshot | Store small binary sample for image/hex preview, then truncate | |
| You decide | Antigravity decides the optimal memory/feature balance | |

**User's choice:** Pure byte counting without buffering  
**Notes:** Zero memory pressure or OOM risk during large file downloads.

### Question 4: If a response stream aborts or throws an error mid-transmission, how should the captured record reflect it?

| Option | Description | Selected |
|--------|-------------|:--------:|
| Retain partial body buffered so far + record full error details | Developers see any error message payload received before the connection dropped, with status marked as `failed` | ✓ |
| Discard partial body on stream error and store only error details | Prevents malformed/partial JSON payloads from being stored | |
| You decide | Antigravity decides the best troubleshooting pattern | |

**User's choice:** Retain partial body buffered so far + record full error details  
**Notes:** Preserves valuable diagnostic payload data even if connection is severed mid-stream.

---

## Manual Logging API DX

### Question 1: What workflows should the manual logging API support?

| Option | Description | Selected |
|--------|-------------|:--------:|
| Dual API: One-shot `logApi(...)` for completed calls + Two-phase `startRequest(...)` tracker returning a handle for in-flight requests | Supports GraphQL, gRPC, custom SDKs with exact duration timing | ✓ |
| One-shot `logApi(...)` only | Simple static method taking all request/response parameters once call completes | |
| You decide | Antigravity decides the most versatile API ergonomics | |

**User's choice:** Dual API: One-shot `logApi(...)` for completed calls + Two-phase `startRequest(...)` tracker  
**Notes:** Accommodates both retrospective logging and active lifecycle tracking.

### Question 2: What payload body types should the manual logging API accept for request/response bodies?

| Option | Description | Selected |
|--------|-------------|:--------:|
| Flexible `Object?` input | Accepts `Map`, `List`, `String`, `Uint8List`, automatically encodes JSON, detects `BodyType`, and applies redaction & truncation | ✓ |
| Strict typed input | `String?` or raw `List<int>?` only, requiring developer to encode before passing | |
| You decide | Antigravity decides the best developer ergonomics | |

**User's choice:** Flexible `Object?` input  
**Notes:** Frictionless logging experience without requiring manual `jsonEncode`.

### Question 3: How should standalone error logging (LOG-02) behave when called independently?

| Option | Description | Selected |
|--------|-------------|:--------:|
| Standalone & linked error logging | `NetworkInspector.logError(...)` creates a standalone failed record if no `id` provided, or updates an existing transaction if `id` is supplied; tracker also provides `onError` | ✓ |
| Tracker/logApi only | Errors can only be logged as part of `logApi(error: ...)` or `tracker.onError(...)` | |
| You decide | Antigravity decides the most useful error logging contract | |

**User's choice:** Standalone & linked error logging  
**Notes:** Enables logging socket errors or caught exceptions directly with minimal boilerplate.

### Question 4: How should manual logging methods behave when NetworkInspector is disabled (e.g., in production release mode)?

| Option | Description | Selected |
|--------|-------------|:--------:|
| Zero-overhead no-op | Methods return immediately with zero JSON encoding, string formatting, or memory allocations; `startRequest()` returns a no-op tracker | ✓ |
| Fallback to console debugPrint | Print minimal one-line log to console when disabled, skipping database | |
| You decide | Antigravity decides the safest production behavior | |

**User's choice:** Zero-overhead no-op  
**Notes:** Strict adherence to production safety and zero-overhead performance constraints.

---

## the agent's Discretion

- Internal class hierarchy and naming for `dart:io` wrappers (`InspectorHttpClient`, `InspectorHttpClientRequest`, `InspectorHttpClientResponse`).
- Stream transformation and chunk accumulation buffer mechanics.
- Header string normalization and case-insensitive check for `x-network-inspector-id`.
- Implementation details of `NetworkRequestTracker` and no-op tracker.

## Deferred Ideas

- None — discussion stayed entirely within Phase 3 scope.
