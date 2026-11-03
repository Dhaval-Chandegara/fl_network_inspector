---
phase: 03-network-capture-interceptors
reviewed: 2026-11-01T11:22:00Z
depth: standard
files_reviewed: 18
files_reviewed_list:
  - lib/src/interceptor/stream/stream_tap_transformer.dart
  - lib/src/interceptor/io/http_overrides_manager.dart
  - lib/src/interceptor/io/inspector_http_client.dart
  - lib/src/interceptor/io/inspector_http_client_request.dart
  - lib/src/interceptor/io/inspector_http_client_response.dart
  - lib/src/interceptor/platform/http_capture_platform.dart
  - lib/src/interceptor/platform/http_capture_stub.dart
  - lib/src/interceptor/platform/http_capture_io.dart
  - lib/src/config/network_inspector_config.dart
  - lib/src/core/constants.dart
  - lib/src/core/network_inspector.dart
  - lib/src/interceptor/dio/network_inspector_dio_interceptor.dart
  - lib/src/interceptor/http/network_inspector_http_client.dart
  - lib/flutter_network_inspector.dart
  - lib/src/logging/network_request_tracker.dart
  - lib/src/logging/network_request_tracker_impl.dart
  - lib/src/logging/no_op_network_request_tracker.dart
  - lib/src/logging/manual_logger.dart
findings:
  critical: 3
  warning: 5
  info: 4
  total: 12
status: issues_found
---

# Phase 3: Code Review Report

**Reviewed:** 2026-11-01T11:22:00Z  
**Depth:** standard  
**Files Reviewed:** 18  
**Status:** issues_found  

## Summary

Phase 03 implementation delivers comprehensive network capture interceptors across `dart:io` (`HttpOverrides`), dedicated `Dio` 5.x interceptor, `package:http` adapter, and manual request logging pipelines. The architecture succeeds in isolating platform-specific I/O behind conditional exports and provides robust test coverage for standard flows.

However, an adversarial audit uncovered **3 Critical (Blocker)** issues, **5 Warnings**, and **4 Info** items:
1. `InspectorHttpClient.open` hardcodes `scheme: 'http'`, converting all TLS/HTTPS connections into unencrypted plain HTTP on port 443.
2. Binary-encoded request payloads in `ManualLogger.processPayload` bypass `RedactionEngine` entirely, persisting plaintext passwords, tokens, and credentials.
3. Stream tapping in `InspectorHttpClientResponse`, `NetworkInspectorHttpClient`, and `InspectorHttpClientRequest` fails to propagate truncation indicators (`[Payload truncated at X bytes]`), marks truncated bodies as `isTruncated: false`, and records truncated buffer lengths instead of actual `totalBytes`.
4. Secondary issues include request content-type corruption during response completion, missing suppression checks in `abort()`, deferred header stripping in `close()`, and missing duration metrics in linked error logging.

---

## Critical Issues

### CR-01: Hardcoded HTTP Scheme in `InspectorHttpClient.open` Forces Plaintext and Breaks TLS Connections

**Classification:** BLOCKER  
**File:** [lib/src/interceptor/io/inspector_http_client.dart:100-104](file:///Users/dhavalchandegara/projects/fl_network_inspector/lib/src/interceptor/io/inspector_http_client.dart#L100-L104)  
**Issue:**  
`InspectorHttpClient.open(method, host, port, path)` implements the core `HttpClient.open` contract by constructing a synthetic `Uri`:
```dart
const defaultPort = 80;
final uri = Uri(scheme: 'http', host: host, port: port == defaultPort ? null : port, path: path);
return openUrl(method, uri);
```
This forces `scheme: 'http'` unconditionally. When host application code or third-party libraries invoke `client.open('GET', 'secure.example.com', 443, '/api')` or helper methods `client.get(host, 443, path)`, `client.post(host, 443, path)`, etc., the client initiates an unencrypted plaintext HTTP connection to port 443 rather than an HTTPS/TLS connection. This causes handshake failures against TLS servers and exposes credentials/traffic if communicating over cleartext.

In `dart:io`, `HttpClientRequest` already has a `Uri get uri;` getter. `open()` must delegate directly to `_inner.open()` rather than reconstructing an invalid HTTP URI.

**Fix:**
```dart
  @override
  Future<HttpClientRequest> open(String method, String host, int port, String path) async {
    final startTimestamp = DateTime.now();
    try {
      final request = await _inner.open(method, host, port, path);
      return InspectorHttpClientRequest(request, method, request.uri, _config);
    } catch (e, st) {
      if (NetworkInspector.isEnabled) {
        final uri = Uri(scheme: 'https', host: host, port: port, path: path);
        if (!_isIgnored(uri)) {
          final engine = RedactionEngine(customKeys: _config.customRedactionKeys);
          final failedRecord = NetworkRecord(
            id: UuidGenerator.v4(),
            url: engine.redactUrl(uri.toString()),
            baseUrl: '${uri.scheme}://${uri.authority}',
            path: uri.path,
            method: method.toUpperCase(),
            requestQueryParams: engine.redactQueryParams(uri.queryParameters),
            requestTimestamp: startTimestamp,
            durationMs: DateTime.now().difference(startTimestamp).inMilliseconds,
            status: NetworkStatus.failed,
            error: HttpErrorDetails(
              errorType: e.runtimeType.toString(),
              message: e.toString(),
              stackTrace: st.toString(),
            ),
          );
          unawaited(NetworkInspector.repository?.save(failedRecord));
        }
      }
      rethrow;
    }
  }
```

---

### CR-02: `ManualLogger.processPayload` Bypasses Redaction for Byte Buffers

**Classification:** BLOCKER  
**File:** [lib/src/logging/manual_logger.dart:68-76](file:///Users/dhavalchandegara/projects/fl_network_inspector/lib/src/logging/manual_logger.dart#L68-L76)  
**Issue:**  
When an application logs a request or response body as raw bytes (`Uint8List` or `List<int>`, e.g., `utf8.encode(jsonBody)`), `ManualLogger.processPayload` executes:
```dart
if (rawBody is Uint8List || rawBody is List<int>) {
  final bytes = rawBody is Uint8List ? rawBody : Uint8List.fromList(rawBody as List<int>);
  final effectiveMime = contentType ?? 'application/octet-stream';
  return PayloadTruncator.truncateBytes(
    bytes: bytes,
    contentType: effectiveMime,
    maxBytes: config.maxBodyBytes,
  );
}
```
`PayloadTruncator.truncateBytes` decodes textual and JSON mime types to string, but does **not** perform redaction. The resulting `PayloadData` is returned immediately without passing through `engine.redactBody(truncated.body, effectiveMime)`. Consequently, sensitive fields (passwords, auth tokens, API keys) passed as byte buffers to `NetworkInspector.logApi`, `NetworkInspector.startRequest`, or `NetworkInspector.logError` are persisted in the database unredacted.

**Fix:**
```dart
    // 1. Raw byte buffer (Uint8List or List<int>)
    if (rawBody is Uint8List || rawBody is List<int>) {
      final bytes = rawBody is Uint8List ? rawBody : Uint8List.fromList(rawBody as List<int>);
      final effectiveMime = contentType ?? 'application/octet-stream';
      final truncated = PayloadTruncator.truncateBytes(
        bytes: bytes,
        contentType: effectiveMime,
        maxBytes: config.maxBodyBytes,
      );
      final redacted = engine.redactBody(truncated.body, effectiveMime);
      return truncated.copyWith(body: redacted);
    }
```

---

### CR-03: Truncated Response and Request Streams Lose Total Byte Count, Truncation Banner, and Truncation State

**Classification:** BLOCKER  
**Files:**
- [lib/src/interceptor/io/inspector_http_client_response.dart:181-191, 209](file:///Users/dhavalchandegara/projects/fl_network_inspector/lib/src/interceptor/io/inspector_http_client_response.dart#L181-L191)
- [lib/src/interceptor/http/network_inspector_http_client.dart:189-207](file:///Users/dhavalchandegara/projects/fl_network_inspector/lib/src/interceptor/http/network_inspector_http_client.dart#L189-L207)
- [lib/src/interceptor/io/inspector_http_client_request.dart:46-57, 237-248](file:///Users/dhavalchandegara/projects/fl_network_inspector/lib/src/interceptor/io/inspector_http_client_request.dart#L46-L57)

**Issue:**  
1. In `InspectorHttpClientResponse._onResponseComplete`: `createStreamTapTransformer` pre-slices the buffer to `config.maxBodyBytes`. When `bufferedBytes` is passed to `PayloadTruncator.truncateBytes(bytes: bufferedBytes, maxBytes: maxBytes)`, `bufferedBytes.length <= maxBytes` is always true. `truncateBytes` therefore evaluates `isTruncated = false`, does **not** append `[Payload truncated at X bytes]`, and reports `byteSize = bufferedBytes.length`. The `isTruncated` and `totalBytes` parameters provided by `createStreamTapTransformer` are completely ignored for non-binary content, and `responseSize` is recorded as the truncated byte length (e.g. 1MB) instead of the true stream length (e.g. 10MB).
2. In `NetworkInspectorHttpClient`: While `isTruncated` is passed to `copyWith`, `truncateBytes` was called on `bufferedBytes` (already sliced to `maxBodyBytes`), so `truncated.body` has no truncation banner, and `responseSize` is set to `responsePayload.byteSize` (capped at 1MB) rather than `totalBytes`.
3. In `InspectorHttpClientRequest`: `_bufferChunk` discards chunks once `_accumulatedBodyBytes >= maxBodyBytes` without tracking `totalBytes` or `isTruncated`. When `close()` runs, `_bodyBytes.toBytes()` length is `<= maxBodyBytes`, causing `isTruncated` to be false, omitting the truncation banner, and recording `requestSize` as `maxBodyBytes`.

**Fix:**
In `inspector_http_client_response.dart`:
```dart
      } else {
        final decodedText = utf8.decode(bufferedBytes, allowMalformed: true);
        final finalBody = isTruncated
            ? '$decodedText${PayloadTruncator.formatTruncationBanner(config.maxBodyBytes)}'
            : decodedText;
        final redactedBody = engine.redactBody(finalBody, contentType);
        responsePayload = PayloadData(
          body: redactedBody,
          byteSize: totalBytes,
          bodyType: BodyTypeDetector.detect(body: finalBody, contentType: contentType),
          isTruncated: isTruncated,
        );
      }
```
And set `responseSize: totalBytes`. Apply equivalent handling in `network_inspector_http_client.dart` and track `_totalBodyBytes` and `_isBodyTruncated` in `InspectorHttpClientRequest`.

---

## Warnings

### WR-01: `requestContentType` Corruption in `InspectorHttpClientResponse`

**Classification:** WARNING  
**File:** [lib/src/interceptor/io/inspector_http_client_response.dart:129, 204, 297](file:///Users/dhavalchandegara/projects/fl_network_inspector/lib/src/interceptor/io/inspector_http_client_response.dart#L129)  
**Issue:**  
`InspectorHttpClientResponse` does not accept `requestContentType` in its constructor:
1. In `_saveProgressiveInitialRecord` (line 129), it assigns `requestContentType: _inner.headers.contentType?.mimeType`, erroneously setting the request content type to the **response's** MIME type.
2. In `_onResponseComplete` (line 204) and `_onResponseError` (line 297), it hardcodes `requestContentType: requestPayload != null ? 'application/json' : null`, mislabeling form-urlencoded, plain text, and XML request payloads as JSON.

**Fix:**  
Pass `final String? requestContentType;` from `InspectorHttpClientRequest` into `InspectorHttpClientResponse` and use it across all record constructors.

---

### WR-02: `InspectorHttpClientRequest.abort()` Omits Deduplication and URL Blacklist Checks

**Classification:** WARNING  
**File:** [lib/src/interceptor/io/inspector_http_client_request.dart:120-181](file:///Users/dhavalchandegara/projects/fl_network_inspector/lib/src/interceptor/io/inspector_http_client_request.dart#L120-L181)  
**Issue:**  
In `InspectorHttpClientRequest.abort()`:
```dart
if (!_isSuppressed && NetworkInspector.isEnabled) {
```
`_isSuppressed` is only initialized to `true` inside `close()`. When an in-flight request is aborted before `close()` finishes:
1. It does not check for synthetic tracking headers (`x-network-inspector-id` / `x-fl-net-inspector-tracked-id`), creating duplicate failed records when higher-level clients (Dio, package:http) abort a request.
2. It does not check `_isIgnored(_url)`, causing aborted requests to blacklisted hosts or URLs to be saved into storage.

**Fix:**  
Execute a shared suppression check (`_checkSuppression()`) inside `abort()` before persisting the failed record:
```dart
  @override
  void abort([Object? exception, StackTrace? stackTrace]) {
    _evaluateSuppression();
    if (!_isSuppressed && NetworkInspector.isEnabled) {
      ...
```

---

### WR-03: Deferred Deduplication Check and Late Synthetic Header Stripping in `InspectorHttpClientRequest`

**Classification:** WARNING  
**File:** [lib/src/interceptor/io/inspector_http_client_request.dart:186-213](file:///Users/dhavalchandegara/projects/fl_network_inspector/lib/src/interceptor/io/inspector_http_client_request.dart#L186-L213)  
**Issue:**  
Deduplication header detection and `_inner.headers.removeAll(...)` are deferred entirely to `close()`.
1. In `dart:io`, as soon as body data is written via `add()` or `write()`, HTTP headers are committed and flushed to the underlying TCP socket. If `bufferOutput` is disabled or chunk buffers exceed socket capacity, calling `headers.removeAll()` in `close()` throws an `HttpException: Headers have already been sent` or fails to prevent the header from going out on the wire.
2. Because `_isSuppressed` is `false` during body writes, `_bufferChunk` allocates and buffers bytes into memory for requests that will ultimately be discarded.

**Fix:**  
Evaluate suppression and strip synthetic tracking headers eagerly on the first invocation of `add()`, `write()`, `addStream()`, or `close()`.

---

### WR-04: Linked `logError` Fails to Set `responseTimestamp` and `durationMs`

**Classification:** WARNING  
**File:** [lib/src/logging/manual_logger.dart:264-273](file:///Users/dhavalchandegara/projects/fl_network_inspector/lib/src/logging/manual_logger.dart#L264-L273)  
**Issue:**  
When `ManualLogger.logError` updates an existing transaction (e.g., started with `NetworkInspector.startRequest`):
```dart
final updated = existing.copyWith(
  status: NetworkStatus.failed,
  error: errorDetails,
  responseStatusCode: statusCode ?? existing.responseStatusCode,
  responseHeaders: sanitizedRespHeaders ?? existing.responseHeaders,
  responseBody: responsePayload ?? existing.responseBody,
  responseContentType: findContentType(headers) ?? existing.responseContentType,
  responseSize: responsePayload?.byteSize ?? existing.responseSize,
);
```
It fails to supply `responseTimestamp` and `durationMs`. For pending records where these fields are null, the completed failure record is left with `durationMs: null` and `responseTimestamp: null`.

**Fix:**
```dart
final now = DateTime.now();
final updated = existing.copyWith(
  status: NetworkStatus.failed,
  error: errorDetails,
  responseStatusCode: statusCode ?? existing.responseStatusCode,
  responseHeaders: sanitizedRespHeaders ?? existing.responseHeaders,
  responseBody: responsePayload ?? existing.responseBody,
  responseContentType: findContentType(headers) ?? existing.responseContentType,
  responseSize: responsePayload?.byteSize ?? existing.responseSize,
  responseTimestamp: now,
  durationMs: now.difference(existing.requestTimestamp).inMilliseconds,
);
```

---

### WR-05: Dead Conditional `config.includeMultipartFilePaths ? null : null`

**Classification:** WARNING  
**Files:**
- [lib/src/interceptor/dio/network_inspector_dio_interceptor.dart:104](file:///Users/dhavalchandegara/projects/fl_network_inspector/lib/src/interceptor/dio/network_inspector_dio_interceptor.dart#L104)
- [lib/src/interceptor/http/network_inspector_http_client.dart:89](file:///Users/dhavalchandegara/projects/fl_network_inspector/lib/src/interceptor/http/network_inspector_http_client.dart#L89)

**Issue:**  
Both client adapters populate `MultipartEntry.filePath` using:
`filePath: config.includeMultipartFilePaths ? null : null,`
Both branches evaluate to `null`. If underlying client representations (`MultipartFile`) do not expose the source file path, omit the ternary condition or set `filePath: null` with an explanatory comment.

**Fix:**  
Remove the dead ternary and set `filePath: null` (or inspect `f.isAsync` / underlying file if available).

---

## Info

### IN-01: Inaccurate Multipart Byte Size Calculation in `ManualLogger`
**Classification:** INFO  
**File:** [lib/src/logging/manual_logger.dart:84](file:///Users/dhavalchandegara/projects/fl_network_inspector/lib/src/logging/manual_logger.dart#L84)  
**Issue:** `ManualLogger.processPayload` sets `byteSize: utf8.encode(summary).length` (22 bytes) for multipart payloads instead of summing `entry.byteSize` across all entries.  
**Fix:** Calculate `byteSize: multipartList.fold<int>(0, (sum, e) => sum + e.byteSize)`.

### IN-02: String Coercion of Null `StackTrace` in `NetworkInspectorDioInterceptor`
**Classification:** INFO  
**File:** [lib/src/interceptor/dio/network_inspector_dio_interceptor.dart:317](file:///Users/dhavalchandegara/projects/fl_network_inspector/lib/src/interceptor/dio/network_inspector_dio_interceptor.dart#L317)  
**Issue:** `err.stackTrace.toString()` produces the literal string `"null"` when `err.stackTrace` is null.  
**Fix:** Use `stackTrace: err.stackTrace?.toString()`.

### IN-03: Binary MIME Type Classification Logic Duplicated Across 4 Files
**Classification:** INFO  
**Files:**
- `lib/src/interceptor/io/inspector_http_client_response.dart:89`
- `lib/src/interceptor/http/network_inspector_http_client.dart:273`
- `lib/src/utils/payload_truncator.dart:118`
- `lib/src/utils/body_type_detector.dart:20`  
**Issue:** Identical MIME prefix/substring checks are copy-pasted across 4 modules.  
**Fix:** Consolidate into `BodyTypeDetector.isBinaryMime(String? mime)`.

### IN-04: Missing Completion Guard on `NetworkRequestTrackerImpl`
**Classification:** INFO  
**File:** [lib/src/logging/network_request_tracker_impl.dart:95-220](file:///Users/dhavalchandegara/projects/fl_network_inspector/lib/src/logging/network_request_tracker_impl.dart#L95-L220)  
**Issue:** `onResponse` and `onError` do not check an `_isCompleted` boolean flag; duplicate invocations will overwrite existing records.  
**Fix:** Add `bool _isCompleted = false;` guard at the start of `onResponse` and `onError`.

---

_Reviewed: 2026-11-01T11:22:00Z_  
_Reviewer: the agent (gsd-code-reviewer)_  
_Depth: standard_
