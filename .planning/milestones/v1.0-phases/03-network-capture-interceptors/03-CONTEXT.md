# Phase 3: Network Capture & Interceptors - Context

**Gathered:** 2026-11-01  
**Status:** Ready for planning  

<domain>
## Phase Boundary

Design, implement, and verify non-destructive HTTP/HTTPS interception across `dart:io`, `Dio`, and `package:http` without breaking single-subscription response streams, clobbering host application `HttpOverrides`, or duplicating records, complemented by a developer-friendly manual logging API (`NetworkInspector.logApi`, `logError`, and two-phase in-flight request tracking).

</domain>

<decisions>
## Implementation Decisions

### Deduplication & Request Filtering
- **D-33:** Client adapters (`NetworkInspectorDioInterceptor`, `NetworkInspectorHttpClient`) inject a synthetic UUID tracking header (`x-network-inspector-id: <uuid>`) into outgoing requests. `HttpOverrides` checks for this header; if present, it suppresses duplicate capture and strips the header before transmission over the wire so the backend server never receives it. — **Reversibility:** costly — Affects request lifecycle across all interceptor adapters and `HttpOverrides` pipeline.
- **D-34:** Client adapters prevent duplicate capture from nested or repeated registrations on the same client instance by tagging request metadata (e.g. `RequestOptions.extra` for Dio, internal request wrapper flag for `package:http`). — **Reversibility:** reversible — Internal client adapter state tracking.
- **D-35:** Retried and redirected requests (e.g., HTTP 301/302 redirects, Dio retry interceptors) are captured as distinct records with shared correlation metadata / new UUIDs rather than coalescing, ensuring developers have full visibility into intermediate redirections and retried failures. — **Reversibility:** costly — Impacts UI display and repository record structure.
- **D-36:** Configurable domain and URL pattern blacklist (`ignoredHosts` / `ignoredUrls`) in `NetworkInspectorConfig` to bypass capture early for analytics, logging services (Firebase, Sentry), or custom hostnames without modifying the underlying request. — **Reversibility:** reversible — Config filter check in interceptor ingress.

### HttpOverrides Scope & Chaining
- **D-37:** `HttpOverrides` is automatically installed during `NetworkInspector.initialize()` when `enableAutoCapture: true` (and not on Flutter Web), with public helpers for explicit control: `NetworkInspector.startAutoCapture()`, `NetworkInspector.stopAutoCapture()`, and `NetworkInspector.runZoned()` for zone-scoped interception. — **Reversibility:** costly — Facade lifecycle and global runtime state management.
- **D-38:** Safe `HttpOverrides` chaining: preserve pre-existing `HttpOverrides.current` by delegating client creation to `previous.createHttpClient(context)` (falling back to default `HttpClient(context: context)` if null) and delegating proxy lookup to `previous.findProxyFromEnvironment(url, environment)`. — **Reversibility:** one-way — Critical for preventing breaking changes to host app proxy, corporate VPN, or custom SSL configurations.
- **D-39:** Transparent two-way proxying in custom `HttpClient` / `HttpClientRequest` / `HttpClientResponse` wrappers: forward all getters and setters directly to the underlying client (including `badCertificateCallback`, `idleTimeout`, `connectionTimeout`, `userAgent`, and proxy authentication) to ensure 100% fidelity to host application configuration. — **Reversibility:** costly — Affects all `dart:io` wrapped API surfaces.
- **D-40:** Clean lifecycle restoration: calling `NetworkInspector.stopAutoCapture()` or `NetworkInspector.dispose()` restores the exact previous override (`HttpOverrides.global = _previousOverrides`), leaving zero residual hooks or leaks. — **Reversibility:** reversible — Disposal logic.

### Response Stream Buffering & Chunked/SSE Handling
- **D-41:** Non-destructive response stream tapping via `StreamTransformer.fromHandlers`: response chunks are copied into an internal byte accumulator up to `maxBodyBytes` and forwarded downstream synchronously to the host app's listener, guaranteeing zero latency introduction, zero stream backpressure corruption, and zero `StateError: Stream has already been listened to`. — **Reversibility:** one-way — Fundamental stream interception mechanism across `dart:io` and `package:http`.
- **D-42:** Progressive status updates for long-lived / infinite streams (e.g., SSE `text/event-stream` or live feeds): response status code and headers are saved immediately upon arrival; the body is captured up to `maxBodyBytes` and marked completed/truncated without waiting indefinitely for stream close (`onDone`). — **Reversibility:** costly — Repository update lifecycle and SSE support.
- **D-43:** Binary response streams (images, audio, video, pdf, zip) bypass memory buffering completely: bytes are forwarded directly downstream while accumulating only byte count, recording `[Binary data: <mime_type>, <total_bytes>]` with zero memory allocation. — **Reversibility:** reversible — Optimizes memory during large downloads.
- **D-44:** Aborted or failed response streams retain the partial body buffered so far and capture full error details (exception type, message, stack trace), marking status as `failed` rather than hanging or dropping the record. — **Reversibility:** costly — In-flight error handling and state persistence.

### Manual Logging API DX
- **D-45:** Dual manual logging API: one-shot `NetworkInspector.logApi(...)` for completed calls + two-phase `NetworkInspector.startRequest(...)` returning a `NetworkRequestTracker` handle with `.onResponse(...)` and `.onError(...)` for tracking GraphQL, gRPC, WebSockets, or custom SDKs with exact timing. — **Reversibility:** costly — Public API facade and tracker contract.
- **D-46:** Flexible body parameter accepting `Object?` (such as `Map`, `List`, `String`, `Uint8List`): automatically detects `BodyType`, stringifies/encodes JSON, applies `RedactionEngine` and `PayloadTruncator`, and extracts multipart metadata if applicable. — **Reversibility:** reversible — Public helper input preprocessing.
- **D-47:** Standalone & linked error logging: `NetworkInspector.logError(...)` creates a standalone `failed` record if called independently, or updates an existing transaction if an `id` is supplied. — **Reversibility:** costly — Error logging facade contract.
- **D-48:** Complete zero-overhead no-op when `!NetworkInspector.isEnabled`: all manual logging methods return immediately without model allocations, JSON serialization, or database calls; `startRequest()` returns a lightweight no-op tracker instance. — **Reversibility:** costly — Production release performance guarantee.

### the agent's Discretion
- Internal class hierarchy and naming for `dart:io` wrappers (`InspectorHttpClient`, `InspectorHttpClientRequest`, `InspectorHttpClientResponse`).
- Stream transformation and chunk accumulation buffer mechanics.
- Header string normalization and case-insensitive check for `x-network-inspector-id`.
- Implementation details of `NetworkRequestTracker` and no-op tracker.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Package Specifications & Guidelines
- `.planning/PROJECT.md` — Project core value, constraints, and architecture.
- `.planning/REQUIREMENTS.md` § Interception & Network Capture (`INTC-01` through `INTC-07`, `LOG-01`, `LOG-02`).
- `.planning/research/STACK.md` § Supporting Libraries (Dio 5.x, http 1.x) & Pitfalls (Direct Stream Consumption, HttpOverrides chaining).
- `.planning/research/ARCHITECTURE.md` § Layer 1 & 4 — Interceptor adapters, stream proxies, and public facade.
- `.planning/research/PITFALLS.md` § Pitfall 3 (Broken single-subscription streams) & Pitfall 5 (HttpOverrides clobbering).
- `.planning/phases/01-foundation-models/01-CONTEXT.md` — Phase 1 locked decisions (`D-01` through `D-16`): `NetworkRecord`, `PayloadData`, UUID generator, `RedactionEngine`, `PayloadTruncator`.
- `.planning/phases/02-sqlite-persistence/02-CONTEXT.md` — Phase 2 locked decisions (`D-17` through `D-32`): `NetworkInspectorRepository`, write buffer queue coalescing.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `NetworkInspector` (`lib/src/core/network_inspector.dart`): Facade initialized with `repository` and `config`, provides lifecycle points for interceptor installation.
- `NetworkInspectorConfig` (`lib/src/config/network_inspector_config.dart`): Config holding `enabled`, `enableAutoCapture`, `maxBodyBytes`, `customRedactionKeys`. Needs additions for `ignoredHosts` and `ignoredUrls`.
- `NetworkRecord` (`lib/src/models/network_record.dart`): Domain model capturing request, response, error, multipart, timing, and status.
- `RedactionEngine` (`lib/src/utils/redaction_engine.dart`): Sanitizes sensitive keys in headers and bodies.
- `PayloadTruncator` (`lib/src/utils/payload_truncator.dart`): Truncates payloads exceeding `maxBodyBytes`.
- `BodyTypeDetector` (`lib/src/utils/body_type_detector.dart`): Detects content type (`json`, `text`, `formData`, `multipart`, `binary`, `empty`).
- `UuidGenerator` (`lib/src/utils/uuid_generator.dart`): RFC 4122 v4 UUID generator for request IDs.
- `NetworkInspectorRepository` (`lib/src/repository/network_inspector_repository.dart`): Consumes `save(record)` and coalesces pending/completed updates.

### Established Patterns
- Pure Dart 3 immutable domain models with sound null safety.
- Defensive error isolation: interceptor logging must never crash or throw unhandled exceptions into consumer application network streams.
- Zero-codegen architecture.
- Web-safe fallbacks (`kIsWeb` guards around `dart:io` imports).

### Integration Points
- `NetworkInspector.initialize()` initializes and activates `HttpOverrides` if `enableAutoCapture` is true.
- `NetworkInspectorDioInterceptor` plugs into Dio client `interceptors.add(...)`.
- `NetworkInspectorHttpClient` wraps `http.BaseClient` for `package:http`.
- `NetworkInspector.logApi(...)`, `startRequest(...)`, and `logError(...)` connect external calls into `repository.save(...)`.

</code_context>

<specifics>
## Specific Ideas

- The synthetic header `x-network-inspector-id` should be defined as a package constant (`NetworkInspectorConstants.headerInspectorId = 'x-network-inspector-id'`) and automatically stripped by `HttpOverrides` before request execution.
- `NetworkRequestTracker` returned by `startRequest()` should implement an interface allowing a `NoOpNetworkRequestTracker` when disabled, keeping production overhead to zero.

</specifics>

<deferred>
## Deferred Ideas

- None — all decisions directly clarify Phase 3 scope.

</deferred>

---

*Phase: 3-Network Capture & Interceptors*  
*Context gathered: 2026-11-01*
