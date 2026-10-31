# Pitfalls Research: Flutter Network Inspector Package

**Domain:** Flutter Network Inspection, HTTP Interception & In-App Debugging Tools  
**Researched:** 2026-10-31  
**Confidence:** HIGH (Verified against Dart SDK `dart:io` stream specifications, `sqflite` platform channel internals, and prior art from Chucker, Alice, and Sentry Flutter SDKs)

---

## Critical Pitfalls

### Pitfall 1: Single-Subscription Stream Draining (`Bad state: Stream has already been listened to`)

**What goes wrong:**  
In Dart, `HttpClientResponse` (as well as `StreamedResponse.stream` in `package:http`) implements a single-subscription `Stream<List<int>>`. When an interceptor reads or listens to this stream (`response.listen()`, `await response.toBytes()`, or `await response.drain()`) to log or inspect the response body, the stream is fully drained and marked as consumed. When the host application subsequently attempts to read the response body (e.g. `await response.transform(utf8.decoder).join()` or inside a JSON serializer), Dart throws a fatal runtime exception:  
`StateError: Bad state: Stream has already been listened to`.  
Similarly, attempting to tap the `IOSink` of `HttpClientRequest` via `addStream()` without coordinating write access can deadlock or throw `StateError: StreamSink is bound to a stream`.

**Why it happens:**  
Developers coming from ecosystems with multi-reader streams or Node.js pipes assume a stream can be observed transparently. In Dart, streams are single-subscription by default to prevent unbounded memory buffering. Developers frequently try wrapping the stream with `response.asBroadcastStream()`, but this introduces severe secondary bugs:
1. If the host application has not attached its listener when chunks arrive, broadcast streams discard those chunks, causing silent payload truncation.
2. It breaks backpressure and pause/resume semantics expected by HTTP clients.
3. If an interceptor buffers the entire stream before forwarding, real-time chunked transfers (Server-Sent Events / SSE, NDJSON, media streaming) are completely stalled until the connection closes.

**How to avoid:**  
1. Implement a non-draining, dual-forwarding stream splitter using `StreamSplitter<List<int>>` from `package:async` or a dedicated custom `StreamController` that proxies the byte stream.
2. The proxy controller must remain paused until the downstream consumer (the host app) attaches its listener. Once the consumer listens, data chunks must be forwarded to the app immediately in real time, while a second branch accumulates bytes into an in-memory debug buffer up to a configured capture ceiling.
3. If the downstream consumer cancels or encounters an error, the upstream subscription must mirror that state cleanly.
4. For request streams (`HttpClientRequest`), intercept byte writes at `add()`, `write()`, and `addStream()` by forwarding directly to the underlying `IOSink` while capturing a mirrored copy.

**Warning signs:**  
- Integration tests pass when asserting on status codes and headers, but real API calls crash immediately when parsing response bodies.
- Image loaders (`Image.network`), cached network images, or file downloads fail with `Bad state: Stream has already been listened to`.
- Streaming endpoints (e.g., SSE or chunked LLM completions) hang indefinitely and only deliver text once the socket terminates.

**Phase to address:**  
Phase: Core HTTP Interception Layer (`INTC-01`).

---

### Pitfall 2: Global `HttpOverrides` Collision & Unchained Singleton Overwrites

**What goes wrong:**  
When `NetworkInspector` activates automatic capture by setting `HttpOverrides.global = InspectorHttpOverrides()`, it obliterates any previously assigned `HttpOverrides.global`. This silently destroys:
- Custom `badCertificateCallback` logic used by development and staging environments for self-signed SSL certificates or local proxy inspection.
- Proxy routing configurations (`findProxyFromEnvironment` or custom Charles/Fiddler/system proxy routing).
- APM and error tracking network hooks from packages like Sentry Flutter, Datadog, or Firebase Performance.  
Conversely, if another package or the host app initializes an `HttpOverrides` after the inspector, the inspector is overwritten and silently ceases capturing all traffic.

**Why it happens:**  
`HttpOverrides.global` is a single static mutable variable in `dart:io`. Dart does not provide an automated middleware pipeline for overrides. Naive implementations create a new subclass of `HttpOverrides` that delegates directly to `super.createHttpClient(context)`, completely bypassing any previous overrides assigned by other tools.

**How to avoid:**  
1. Implement override chaining: Capture `final existingOverrides = HttpOverrides.current;` during initialization.
2. In `InspectorHttpOverrides`, delegate both `createHttpClient(context)` and `findProxyFromEnvironment(url, environment)` to `existingOverrides` when non-null, falling back to `super` only when null.
3. When wrapping the resulting `HttpClient`, ensure that any pre-configured properties (e.g., `badCertificateCallback`, `userAgent`, `idleTimeout`, `autoUncompress`, `connectionFactory`) set by previous overrides are preserved on the underlying client.
4. Provide explicit client-level adapters (`NetworkInspectorDioInterceptor`, `NetworkInspectorHttpClient`) so developers can opt out of global `HttpOverrides` completely if their project enforces strict network client isolation.

**Warning signs:**  
- Enabling the inspector suddenly causes API calls on dev environments to fail with `HandshakeException: Certificate verify failed`.
- Corporate proxy tools (Charles, Proxyman) stop capturing traffic once the inspector is initialized.
- Sentry or Datadog stops logging network breadcrumbs or network failure telemetry.

**Phase to address:**  
Phase: Core HTTP Interception Layer (`INTC-01`, `INTC-02`).

---

### Pitfall 3: Double Interception & Duplicate Log Flooding

**What goes wrong:**  
When a developer adds a dedicated client adapter (such as `dio.interceptors.add(NetworkInspectorDioInterceptor())` or uses `NetworkInspectorHttpClient(http.Client())`) while ALSO having automatic capture enabled (`enableAutoCapture: true` via `HttpOverrides.global`), every single HTTP call made through Dio or `package:http` is intercepted and logged **twice** in the SQLite database.  
The inspector UI displays duplicate entries with identical endpoints and near-identical timestamps, inflating storage, cluttering the listing screen, and causing race conditions on update calls.

**Why it happens:**  
On mobile and desktop (`dart:io`), Dio's default adapter (`IOHttpClientAdapter`) and `package:http`'s default `Client()` use `dart:io.HttpClient` under the hood. When `HttpOverrides.global` is set, `dart:io.HttpClient` routes all requests through the low-level inspector wrapper. The higher-level Dio interceptor catches the request first, and the low-level `HttpOverrides` catches the exact same request a few milliseconds later at the socket creation layer.

**How to avoid:**  
1. Implement request tagging via an internal tracking header or request context property (e.g., `x-fl-inspector-id: <uuid>`).
2. When `NetworkInspectorDioInterceptor` or `NetworkInspectorHttpClient` processes an outgoing request, it generates a unique ID, tags the request, and logs the transaction.
3. When the low-level `InspectorHttpClient` in `HttpOverrides` intercepts an outgoing request, it checks for the presence of `x-fl-inspector-id`:
   - If present, it strips the internal header (so it is never transmitted over the wire) and passes the socket stream through directly without creating a second record in SQLite.
   - If absent, it treats the request as an untracked `dart:io` request and creates a new transaction entry.

**Warning signs:**  
- Every API endpoint appears twice in the inspector listing screen.
- Total recorded network request counts are exactly 2x the actual server-side traffic.
- Requests show conflicting statuses (e.g., one entry completed with 200 OK, another entry remains in "Pending").

**Phase to address:**  
Phase: Interceptor Adapters & Deduplication (`INTC-03`, `INTC-04`, `INTC-05`).

---

### Pitfall 4: Out-Of-Memory (OOM) Crashes and Jetsam Kills on Large Payloads & File Uploads

**What goes wrong:**  
The host application crashes abruptly with an OS jetsam kill on iOS (`EXC_RESOURCE -> High Memory`) or `OutOfMemoryError` on Android when downloading large files (PDFs, media files, firmware, app updates) or uploading multipart documents/images.

**Why it happens:**  
Interceptors naively accumulate entire streams in RAM (`List<int> bytes = []`), convert the binary buffer to a Dart string (`utf8.decode(bytes)` or `base64Encode(bytes)`), and insert that string into SQLite.  
For a 30MB file, this creates multiple concurrent copies in memory:
1. Native socket byte buffer.
2. In-memory Dart `List<int>` accumulator.
3. Decoded/base64 Dart `String` (UTF-16 in Dart memory, taking 2x bytes).
4. Platform Channel IPC serialization buffer to `sqflite`.
5. SQLite write cache.  
A 30MB file can trigger a 150MB+ heap spike, instantly exceeding iOS app memory limits (~150–300MB on standard devices). Furthermore, storing raw multipart file bytes in SQLite causes the local database to rapidly expand into gigabytes, corrupting or slowing down the app.

**How to avoid:**  
1. **Configurable byte ceiling:** Enforce a hard body capture threshold (default: 1MB per request/response). If `contentLength` exceeds this limit, or once the accumulated byte counter crosses 1MB, stop buffering body bytes, record a truncated placeholder (`"[Payload exceeded 1MB limit - Truncated]"`), and stream remaining bytes directly to the application without retention.
2. **MIME type filtering:** Automatically bypass body accumulation for binary MIME types (`image/*`, `video/*`, `audio/*`, `application/octet-stream`, `application/pdf`, `application/zip`). Only record metadata (file name, content-type, size).
3. **Metadata-only multipart inspection:** For `multipart/form-data`, parse and record part headers (parameter name, file name, MIME type, file size) but NEVER store raw binary payloads in the database.

**Warning signs:**  
- App crashes whenever a user selects a photo/video from the gallery or downloads a large PDF.
- Xcode Instruments or Android Studio Memory Profiler shows vertical memory spikes during network requests.
- Database file (`.db`) size balloons by tens of megabytes after a single upload.

**Phase to address:**  
Phase: Data Management & Payload Truncation (`DATA-03`, `DATA-04`).

---

### Pitfall 5: UI Thread Jank & Frame Drops from Unbuffered SQLite Writes and Platform Channel Overhead

**What goes wrong:**  
The app drops frames (stuttering animations, janky scrolling, or 100–300ms UI freezes) during heavy network bursts—most notably during app startup when 15 to 30 parallel requests are fired for bootstrap data, remote config, user profile, analytics, and assets.

**Why it happens:**  
1. In Flutter, `sqflite` operations communicate with native iOS/Android engines over the platform `MethodChannel`. Every single call serializes data on the UI isolate.
2. If every network request immediately triggers multiple unbatched SQLite operations (`db.insert` on start, `db.update` on header receipt, `db.update` on completion, `db.delete` for auto-cleanup), dozens of platform channel messages and individual disk syncs (`fsync`) flood the main thread.
3. Without Write-Ahead Logging (`WAL`), SQLite takes an exclusive write lock on every operation, resulting in `SqliteException(5): database is locked` when multiple concurrent requests attempt to write simultaneously.
4. Heavy JSON formatting or string manipulation performed synchronously on the UI thread compounds isolate lockup.

**How to avoid:**  
1. **Enable WAL mode:** Immediately upon database initialization, execute `PRAGMA journal_mode = WAL;` and `PRAGMA synchronous = NORMAL;` to allow concurrent readers and a writer.
2. **In-memory write queue / debounce buffer:** Accumulate pending transaction inserts and updates in an in-memory queue. Flush the queue in batches using `batch.commit(noResult: true)` either every 250ms or when the buffer reaches 20 items.
3. **Decouple transaction metadata from payload storage:** Store lightweight transaction summary fields (`id, method, url, status, duration, timestamp, size`) in a primary `transactions` table, and heavy payload bodies (`request_body, response_body, headers`) in a separate `transaction_payloads` table (1-to-1 foreign key). Listing queries (`SELECT * FROM transactions`) then touch only compact, fixed-width rows without reading megabytes of payload overflow pages.
4. **Asynchronous cleanup:** Never trigger `DELETE FROM transactions...` synchronously inside an insert call. Schedule retention cleanup as a background periodic task or run it once on app launch.

**Warning signs:**  
- Flutter DevTools Performance view displays red frame bars and spikes in `StandardMethodCodec` during network calls.
- SQLite throws `database is locked` exceptions under concurrent API load.
- Startup time of the host app increases significantly when network inspection is enabled.

**Phase to address:**  
Phase: Database Storage & Persistence Layer (`DB-01`, `DB-02`).

---

### Pitfall 6: Plaintext Sensitive Credential Storage & Leaks in Reports and Share Sheets

**What goes wrong:**  
Sensitive security credentials—including OAuth `Authorization: Bearer <token>` headers, session cookies, `X-Api-Key` tokens, passwords, refresh tokens, credit card details, and customer PII—are recorded in plaintext in the SQLite database and exported into plaintext JSON/HAR files shared via the native share sheet.

**Why it happens:**  
Developers treat debug tools as harmless internal utilities. However:
- Mobile device databases (`/data/data/<pkg>/databases/` on Android, `Library/Application Support/` on iOS) can be extracted via backup utilities (`adb backup`), rooted/jailbroken devices, or local file extraction.
- QA engineers and developers routinely export network inspection logs to Slack, Jira, or GitHub issues to file bug reports, inadvertently exposing live production credentials to unauthorized personnel.
- Sanitization implemented only cosmetically in UI widgets (e.g., masking tokens with `***` on screen) leaves the underlying database and exported files completely exposed.

**How to avoid:**  
1. **Pre-persistence redaction:** Redact sensitive fields *before* writing to SQLite. Sensitive values must never hit persistent disk storage in plaintext.
2. **Zero-config default header rules:** Automatically redact standard authentication and session headers by default (`authorization`, `cookie`, `set-cookie`, `proxy-authorization`, `x-api-key`, `x-auth-token`).
3. **Configurable body redaction:** Provide a pattern matcher for JSON bodies and form-urlencoded bodies to redact common keys (`password`, `secret`, `token`, `access_token`, `refresh_token`, `credit_card`, `cvv`, `ssn`).
4. **URL query parameter redaction:** Inspect request URIs and redact matching query parameter values (e.g. `?token=...`, `?key=...`, `?secret=...`).
5. **Export confirmation & sanitization pass:** Before writing an export file for `share_plus`, perform a second-pass security audit and present a confirmation dialog to the developer showing what redactions are applied.
6. **Production no-op:** Enforce a hard compile-time or runtime guard that completely disables the inspector in release mode (`kReleaseMode`) unless explicitly enabled by an intentional override flag.

**Warning signs:**  
- Opening the SQLite file in a DB browser reveals live JWT tokens or user passwords.
- Exported HAR or JSON files shared on bug trackers contain valid authorization headers.
- Security audits or static analysis tools flag plaintext credential storage in app data directories.

**Phase to address:**  
Phase: Configuration, Redaction & Security (`DATA-05`, `CORE-01`, `UI-10`).

---

### Pitfall 7: Zombie "Pending" Requests on Network Drops, Handshake Failures, or Timeouts

**What goes wrong:**  
When an API request fails before receiving a response—such as due to a socket drop (`SocketException`), DNS lookup failure, SSL handshake error, or client-side timeout—the inspector entry remains permanently stuck in a "Pending" state with a spinning indicator. No status code, duration, or error stack trace is ever recorded.

**Why it happens:**  
Interceptors record the beginning of an HTTP transaction when `openUrl()` or `request.close()` is called, but rely exclusively on `HttpClientResponse` listeners or response completion callbacks to record completion. If an exception occurs in the socket connection, SSL handshake, or during request writing, the response callback is never executed. If the interceptor does not wrap the invocation in a comprehensive `try/catch` and `catchError` block, the exception bypasses completion logging.

**How to avoid:**  
1. Wrap the entire request lifecycle—socket opening, body writing, connection closure, and response streaming—in comprehensive error-handling guards.
2. When an exception occurs at any point in the pipeline:
   - Calculate elapsed duration from request start.
   - Update the transaction record in SQLite with status `failed` (or status code `0`).
   - Store the error message, exception type, and stack trace in dedicated database columns.
   - Re-throw the original exception immediately to ensure the host application's error-handling logic operates without interference.

**Warning signs:**  
- Switching a device into Airplane mode during an API call leaves requests permanently stuck in "Pending".
- Network timeout errors do not show up in the inspector's Error Details tab.
- Developers cannot diagnose why a connection failed because the error was dropped by the inspector.

**Phase to address:**  
Phase: Core HTTP Interception Layer & Error Management (`INTC-01`, `DATA-01`).

---

### Pitfall 8: Dart Platform Boundaries & Flutter Web Compilation Failures (`dart:io` Import Pitfall)

**What goes wrong:**  
Adding the package to a multi-platform Flutter app that targets Flutter Web causes `flutter run -d chrome` or `flutter build web` to fail immediately with compilation errors:  
`Error: Not found: 'dart:io'` or runtime crashes with `Unsupported operation: Platform._operatingSystem`.

**Why it happens:**  
`dart:io`, `HttpOverrides`, and standard mobile `sqflite` are native-only libraries and do not exist in the Flutter Web compilation target. Unconditionally importing any file that references `dart:io` breaks the Web compiler, even if the code path is never executed at runtime.

**How to avoid:**  
1. **Conditional imports:** Use Dart conditional imports for platform-specific interception logic:
   ```dart
   import 'http_interceptor_stub.dart'
       if (dart.library.io) 'http_interceptor_io.dart'
       if (dart.library.html) 'http_interceptor_web.dart';
   ```
2. **Graceful no-op on Web:** On Web, `HttpOverrides` does not exist. Automatic capture must cleanly no-op, and documentation must instruct Web developers to use `NetworkInspectorDioInterceptor` (which works on Web via Dio's `BrowserHttpClientAdapter`) or manual logging.
3. **Storage abstraction:** Abstract the repository layer so that on Web, if SQLite is unavailable, it gracefully defaults to an in-memory buffer or indexedDB rather than crashing the application.

**Warning signs:**  
- `flutter build web` fails with compile-time missing import errors.
- Package works on Android/iOS but crashes when running unit tests that do not mock `dart:io`.

**Phase to address:**  
Phase: Architecture & Core Platform Abstraction (`CORE-01`, `CORE-02`, `INTC-01`).

---

### Pitfall 9: Rapid Multi-Shake Screen Stacking & Sensor Background Battery Drain

**What goes wrong:**  
1. Shaking the device vigorously fires 5 or 6 rapid accelerometer events within 500ms, pushing 5 identical `NetworkInspector` screens on top of each other. The user has to tap the back button 5 times to return to their app.
2. Shaking while the app is in the middle of a screen transition or before `MaterialApp` is mounted causes `Navigator operation requested with a context that does not include a Navigator`.
3. The accelerometer sensor subscription remains active when the app is placed in the background, draining device battery.

**Why it happens:**  
Accelerometer streams fire events at high frequencies (20–60Hz). Naive shake detectors trigger a `Navigator.push` on every threshold breach without checking if the inspector route is already active or enforcing a debounce cooldown. Furthermore, failure to hook into `WidgetsBindingObserver` lifecycle states keeps hardware sensors polling indefinitely.

**How to avoid:**  
1. **Route deduplication:** Maintain an internal `_isInspectorOpen` flag or verify whether `ModalRoute.of(context)?.settings.name == NetworkInspectorView.routeName`.
2. **Debounce threshold:** Enforce a minimum 1.5-second cooldown timer after a shake event before allowing another trigger.
3. **Lifecycle awareness:** Implement `WidgetsBindingObserver` in the shake manager. Pause or cancel the `sensors_plus` stream on `AppLifecycleState.paused` or `hidden`, and resume listening only on `AppLifecycleState.resumed`.
4. **Fallback navigation mechanisms:** Never rely solely on shake detection. Always provide programmatic opening (`NetworkInspector.open(context)`) and an optional floating debug bubble for simulator or desktop use.

**Warning signs:**  
- Shaking device creates a stuttering cascade of route push animations.
- Back button navigation feels broken because multiple inspector screens are layered.
- Battery usage reports show high background sensor utilization.

**Phase to address:**  
Phase: Shake Detection & Navigation Management (`SHAKE-01`, `NAV-01`).

---

### Pitfall 10: UI Thread Freezes from Synchronous JSON Pretty-Printing & Monolithic Text Rendering

**What goes wrong:**  
Tapping on a captured request with a large JSON response (e.g. a 2MB catalog or paginated response) causes the inspector details screen to freeze for 2 to 5 seconds. The entire Flutter UI becomes unresponsive, and scrolling drops to single-digit frame rates or crashes.

**Why it happens:**  
1. Executing `JsonEncoder.withIndent('  ').convert(json.decode(body))` on the main UI isolate for large strings blocks the event loop for thousands of milliseconds.
2. Passing a 30,000-line formatted string into a standard Flutter `SelectableText` or `Text` widget forces the text engine (Impeller/Skia) to calculate line breaks, layout, and glyph metrics for the entire string simultaneously, consuming hundreds of megabytes of RAM.

**How to avoid:**  
1. **Background isolate formatting:** Run JSON decoding and indentation in a background isolate via `compute()` or `Isolate.run()`.
2. **Size guards:** For payloads larger than a configurable threshold (e.g., > 200KB), disable automatic pretty-printing by default. Display a warning card: `"Large payload (X KB). Displaying raw view. Tap to format in background"`.
3. **Virtualized rendering:** Implement virtualized or line-based rendering for formatted JSON, or use a collapsible tree view widget that renders only currently expanded nodes.
4. **Copy optimization:** Copying large payloads to the clipboard should operate directly on the raw string without re-formatting on the UI thread.

**Warning signs:**  
- 3+ second pause when switching to the "Response Body" tab on large responses.
- Memory usage jumps by 100MB when opening the response body view.
- Flutter DevTools shows massive CPU spikes in `Paragraph.layout` and `JsonEncoder.convert`.

**Phase to address:**  
Phase: Inspector UI & JSON Visualization (`UI-07`, `UI-08`).

---

## Technical Debt Patterns

Shortcuts that seem reasonable during initial development but create severe long-term stability and performance problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| **Monolithic Transactions Table (Storing bodies in main table)** | Single table, zero SQL joins, simple schema. | Rows balloon from 500 bytes to 500KB. Querying the listing screen loads megabytes of body blobs into RAM, causing severe UI jank. | **Never.** Split into `transactions` (summary index) and `transaction_payloads` (bodies) from Day 1. |
| **Full Table Reloading (`SELECT *`) on Every Request** | Trivial state management; simple `setState()` after DB query. | As database reaches 500+ records, every single network request triggers a full table scan and deserialization, freezing the UI. | **Never.** Use indexed pagination (`LIMIT 50 OFFSET X`) and query summary columns only. |
| **Naive Regex-Based JSON Redaction** | Avoids parsing and re-encoding JSON strings. | Corrupts valid JSON if replacement breaks syntax or escaping; misses nested or renamed keys; fails completely on URL-encoded data. | **Never.** Parse structured data or walk JSON keys safely. |
| **Global Mutable Static State Without Test Reset Hooks** | Quick access anywhere across the package. | State leaks across automated unit and integration test runs, causing nondeterministic test failures and state pollution. | Acceptable only if accompanied by explicit `@visibleForTesting static void reset()` methods. |
| **Using `asBroadcastStream()` on `HttpClientResponse`** | Two lines of code to allow multiple listeners. | Chunks emitted before the host application attaches are permanently dropped; alters backpressure and connection closing behavior. | **Never.** Use a coordinated proxy controller or `StreamSplitter` that waits for downstream subscription. |
| **Running Auto-Cleanup Synchronously on Every Insert** | Keeps database row count strictly bounded at all times. | Every network call executes a blocking subquery (`DELETE WHERE id NOT IN...`), creating massive write amplification and lock contention. | **Never.** Batch cleanups periodically or run during app launch / idle periods. |

---

## Integration Gotchas

Common mistakes when integrating with Flutter networking libraries and system packages.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| **Dio (`NetworkInspectorDioInterceptor`)** | Instantiating interceptors inside short-lived repositories, or combining with `HttpOverrides` without deduplication headers. | Register interceptor once on a shared singleton `Dio` instance. Inject an internal `x-fl-inspector-id` header so low-level `HttpOverrides` ignores it. |
| **`package:http` (`NetworkInspectorHttpClient`)** | Wrapping `http.Client()` but only overriding `get` / `post`, missing `send(BaseRequest)` for `StreamedRequest` / `MultipartRequest`. | Override the core `send(BaseRequest)` method in `http.BaseClient` to intercept all request types uniformly, including streaming and multipart. |
| **Dart `dart:io.HttpClient` & `HttpOverrides`** | Overwriting `HttpOverrides.global` without chaining `HttpOverrides.current`, breaking proxies and certificate callbacks. | Capture `HttpOverrides.current` and delegate both `createHttpClient` and `findProxyFromEnvironment` to the previous override. |
| **`sensors_plus` Shake Detection** | Keeping accelerometer stream active when app is minimized or suspended. | Implement `WidgetsBindingObserver` and pause/cancel sensor subscriptions on `AppLifecycleState.paused` or `hidden`. |
| **`share_plus` Export & Sharing** | Exporting raw SQLite database file directly or sharing unredacted HAR/JSON files. | Generate an in-memory, fully sanitized HAR or JSON export, and display a redaction confirmation dialog before presenting the share sheet. |
| **`sqflite` / `sqflite_common_ffi`** | Running SQLite operations without Write-Ahead Logging (`WAL`), causing database lock errors during concurrent requests. | Execute `PRAGMA journal_mode = WAL;` and `PRAGMA synchronous = NORMAL;` immediately upon opening the database. |
| **Flutter Web (`dart:html` / `fetch`)** | Directly importing `dart:io` in shared files, causing compile errors during `flutter build web`. | Use conditional imports (`if (dart.library.io)`) to isolate `dart:io` code, and provide explicit client adapters for Web. |

---

## Performance Traps

Patterns that work in basic demo apps but fail in real-world applications under load.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| **Synchronous Disk Flushes on Every Request** | UI stutters and dropped frames during rapid API calls (e.g. app launch). | In-memory write buffer / debounce queue committed with `batch.commit(noResult: true)`. | > 5 concurrent requests |
| **Unbounded Payload Buffering in Memory** | App terminated abruptly by OS memory manager (iOS Jetsam / Android OOM). | Cap payload capture at 1MB; truncate and stream remaining bytes without buffering. | > 10MB file download or upload |
| **Full Table Scan on Inspector Listing** | 2–5 second freeze when navigating to the inspector screen. | Use indexed pagination (`LIMIT 50 OFFSET X`) and select only summary columns. | > 200 records in SQLite |
| **Monolithic JSON Pretty-Printing on UI Thread** | Complete UI lockup for multiple seconds when viewing response body. | Format in background isolate (`compute`); disable auto-formatting for payloads > 200KB. | > 200KB JSON response |
| **Synchronous Auto-Cleanup Subqueries on Insert** | High write latency and disk I/O contention on every network request. | Run cleanup periodically (e.g. every 50 requests) or during app startup/idle times. | > 500 records in SQLite |

---

## Security Mistakes

Domain-specific security vulnerabilities beyond standard web security.

| Mistake | Risk | Prevention |
|---------|------|------------|
| **Plaintext Storage of Auth Tokens & Credentials in SQLite** | Credentials extracted via ADB backups, rooted devices, or physical device access. | Redact sensitive headers (`Authorization`, `Cookie`) and configured keys BEFORE writing to SQLite. |
| **Unredacted Log Export via Share Sheet** | Developers or QA leak customer PII, session cookies, and production tokens to Slack or Jira. | Apply automated export sanitization and display a redaction summary confirmation modal. |
| **Inspector Active in Production Release Builds** | Attackers or reverse-engineers access full network telemetry inside the published app. | Automatically compile to a complete no-op in `kReleaseMode` unless an explicit force flag is provided. |
| **Query Parameter Credential Leakage** | Tokens passed in URL queries (e.g. `?token=...`, `?api_key=...`) recorded unmasked. | Parse and sanitize URI query parameters using the same redaction rules applied to headers. |
| **Accumulation of Unencrypted Temp Files in App Cache** | Exported HAR/JSON files accumulate in app temporary directory accessible by other tools. | Delete exported temporary files immediately after the share sheet closes or on next app launch. |

---

## UX Pitfalls

Common user experience flaws in mobile debugging and inspection packages.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| **Multiple Inspector Screens Pushed on Rapid Shake** | Shaking opens 4–5 stacked screens; user must press back multiple times. | Debounce shake events (1.5s) and check if route is already active. |
| **Accidental Shake Triggering** | Inspector pops up while walking, running, or picking up the phone. | Calibrate threshold (default ~2.5G) and allow users to customize sensitivity or toggle shake off. |
| **No Visual Indication of Truncated Payloads** | Developer assumes backend returned incomplete or corrupted JSON. | Display a prominent warning banner: `[Truncated: Payload exceeds 1MB limit. Displaying first 1MB]`. |
| **Loss of Active Search and Filters on Screen Exit** | Developer sets filters, inspects a request, navigates back, and must re-enter filters. | Persist filter and search state in memory during the active application session. |
| **Unresponsive Search on Large Datasets** | Typing in search bar causes UI stutter on large datasets. | Debounce search input (300ms) and execute queries against indexed SQLite columns. |

---

## "Looks Done But Isn't" Checklist

Critical edge cases that appear complete during manual smoke tests but fail in production or edge environments.

- [ ] **HTTP Interception:** Aborted requests, socket timeouts, DNS failures, and SSL handshake exceptions must transition out of "Pending" into "Failed" with full duration and error details recorded.
- [ ] **HttpOverrides Chaining:** Pre-existing proxies (Charles, Proxyman, system proxy) and custom `badCertificateCallback` handlers must remain fully functional when the inspector is active.
- [ ] **Stream Handling:** Chunked transfer encoding, Server-Sent Events (SSE), and media streaming must deliver chunks immediately to the host app without waiting for connection termination.
- [ ] **Payload Redaction:** Both `application/json` and `application/x-www-form-urlencoded` payloads, as well as URL query parameters, must be properly sanitized against configured redaction rules.
- [ ] **SQLite Concurrency:** Firing 50 rapid parallel network requests must not trigger `database is locked` or drop UI frames below 60 FPS.
- [ ] **Shake Detection:** Accelerometer listeners must pause when the app is backgrounded to eliminate battery drain, and rapid shaking must never push duplicate screens.
- [ ] **Cross-Platform Compilation:** Running `flutter build web` must complete without compilation errors or missing `dart:io` symbol failures.

---

## Recovery Strategies

When pitfalls occur despite prevention, how to resolve them with minimal architectural friction.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| **Stream Already Listened To Exception** | HIGH | Refactor the response wrapper to use `StreamSplitter` or a non-draining proxy controller; ensure downstream app retains primary control of the stream. |
| **HttpOverrides Collision / Overwrite** | MEDIUM | Introduce `ChainedHttpOverrides` delegating to `HttpOverrides.current`; provide explicit Dio and http client interceptors as non-global alternatives. |
| **Database Lock Contention & UI Jank** | MEDIUM | Enable WAL mode (`PRAGMA journal_mode = WAL;`); introduce an in-memory write buffer committing in periodic batches with `batch.commit(noResult: true)`. |
| **Memory Leak / OOM on File Transfers** | HIGH | Add upfront `Content-Length` and MIME-type guards; enforce a 1MB capture ceiling; refactor multipart handling to store metadata only. |
| **Duplicate Requests in SQLite** | LOW | Inject internal tracing headers (`x-fl-inspector-id`); configure `HttpOverrides` to skip logging requests already tagged by Dio or http client adapters. |
| **Sensitive Data Leakage in Export** | MEDIUM | Move redaction logic to the ingestion pipeline (pre-DB); add a second-pass sanitization filter before generating share sheet files. |

---

## Pitfall-to-Phase Mapping

How roadmap phases must address and verify these pitfalls.

| Pitfall | Prevention Phase | Verification Strategy |
|---------|------------------|-----------------------|
| **Single-Subscription Stream Draining** | Phase: Core HTTP Interception Layer (`INTC-01`) | Integration tests verifying that `response.listen()`, `response.transform()`, and SSE streaming succeed without `StateError`. |
| **HttpOverrides Collision & Overwrites** | Phase: Core HTTP Interception Layer (`INTC-01`, `INTC-02`) | Test chaining with pre-existing custom `HttpOverrides`; verify proxy and `badCertificateCallback` continue to execute. |
| **Duplicate Logging Across Interceptors** | Phase: Interceptor Adapters & Deduplication (`INTC-03`, `INTC-04`, `INTC-05`) | Test with both `HttpOverrides` and `NetworkInspectorDioInterceptor` active; verify exactly 1 database record is created. |
| **OOM on Large Payloads & Multipart Bloat** | Phase: Data Management & Payload Truncation (`DATA-03`, `DATA-04`) | Test uploading 25MB multipart file and downloading 50MB file; verify memory usage remains flat and payload is truncated. |
| **SQLite Lock Contention & UI Jank** | Phase: Database Storage & Persistence Layer (`DB-01`, `DB-02`) | Stress test firing 50 concurrent requests; verify 0 frame drops and 0 `database is locked` exceptions. |
| **Plaintext Sensitive Credential Leaks** | Phase: Configuration, Redaction & Security (`DATA-05`, `CORE-01`, `UI-10`) | Verify `Authorization` headers and configured JSON keys are stored as `***REDACTED***` in SQLite file and exports. |
| **Zombie "Pending" Requests on Error** | Phase: Core HTTP Interception Layer & Error Management (`INTC-01`, `DATA-01`) | Simulate offline socket exception and timeout; verify transaction is recorded as `failed` with stack trace. |
| **Flutter Web Compilation Failure** | Phase: Architecture & Core Platform Abstraction (`CORE-01`, `CORE-02`, `INTC-01`) | CI test running `flutter build web` to ensure zero compilation or missing import errors. |
| **Rapid Shake Screen Stacking & Battery Drain** | Phase: Shake Detection & Navigation Management (`SHAKE-01`, `NAV-01`) | Widget test simulating 5 rapid shake events within 500ms (assert only 1 route); verify sensor pauses on app lifecycle background. |
| **UI Freeze on Viewing Large JSON** | Phase: Inspector UI & JSON Visualization (`UI-07`, `UI-08`) | Render 2MB JSON response in UI; verify frame rate remains at 60 FPS and formatting executes in background isolate. |

---

## Sources

- **Dart SDK `dart:io` Specification:** `HttpClient`, `HttpClientRequest`, `HttpClientResponse`, and `HttpOverrides` API documentation (`https://api.dart.dev/stable/dart-io/`). Confidence: HIGH.
- **Dart Async Stream Semantics:** `StreamSplitter`, `StreamController`, and single-subscription stream guarantees (`https://api.dart.dev/stable/dart-async/`). Confidence: HIGH.
- **Sqflite Platform Channel & WAL Documentation:** Write-Ahead Logging, batch operations, and transaction management (`https://pub.dev/packages/sqflite`). Confidence: HIGH.
- **Chucker Flutter & Alice Issue Trackers:** Known issues regarding `Stream has already been listened to`, duplicate Dio logging, and memory leaks on large downloads (`https://pub.dev/packages/chucker_flutter`, `https://pub.dev/packages/flutter_alice`). Confidence: MEDIUM.
- **Sentry Flutter SDK HttpOverrides Chaining Pattern:** Preserving pre-existing `HttpOverrides` via delegation (`https://github.com/getsentry/sentry-dart`). Confidence: HIGH.
- **Flutter Web Platform Limitations:** Unsupported `dart:io` operations on Web target (`https://docs.flutter.dev/platform-integration/web/faq`). Confidence: HIGH.

---
*Pitfalls research for: Flutter Network Inspector Package (`flutter_network_inspector`)*  
*Researched: 2026-10-31*
