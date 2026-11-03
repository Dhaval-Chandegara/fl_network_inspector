# Phase 3: Network Capture & Interceptors - Pattern Map

**Mapped:** 2026-11-01  
**Files analyzed:** 26  
**Analogs found:** 26 / 26  

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `pubspec.yaml` | config | file-I/O | `pubspec.yaml` | exact |
| `lib/flutter_network_inspector.dart` | config (barrel) | transform | `lib/flutter_network_inspector.dart` | exact |
| `lib/src/core/constants.dart` | config / utility | request-response | `lib/src/core/constants.dart` | exact |
| `lib/src/config/network_inspector_config.dart` | config | request-response | `lib/src/config/network_inspector_config.dart` | exact |
| `lib/src/core/network_inspector.dart` | controller (facade) | request-response | `lib/src/core/network_inspector.dart` | exact |
| `lib/src/interceptor/platform/http_capture_platform.dart` | config (conditional export) | request-response | `lib/src/storage/platform/ffi_init.dart` | exact |
| `lib/src/interceptor/platform/http_capture_stub.dart` | utility (no-op stub) | request-response | `lib/src/storage/platform/ffi_init_stub.dart` | exact |
| `lib/src/interceptor/platform/http_capture_io.dart` | controller / middleware | request-response | `lib/src/storage/platform/ffi_init_io.dart` | exact |
| `lib/src/interceptor/stream/stream_tap_transformer.dart` | utility / middleware | streaming | `lib/src/repository/write_buffer_queue.dart` & `lib/src/utils/payload_truncator.dart` | role-match |
| `lib/src/interceptor/io/http_overrides_manager.dart` | middleware / controller | request-response | `lib/src/core/network_inspector.dart` | role-match |
| `lib/src/interceptor/io/inspector_http_client.dart` | middleware (client proxy) | request-response | `lib/src/repository/in_memory_network_inspector_repository.dart` | role-match |
| `lib/src/interceptor/io/inspector_http_client_request.dart` | middleware (request wrapper) | streaming / request-response | `lib/src/repository/write_buffer_queue.dart` & `lib/src/utils/redaction_engine.dart` | role-match |
| `lib/src/interceptor/io/inspector_http_client_response.dart` | middleware (response wrapper) | streaming | `lib/src/repository/write_buffer_queue.dart` & `lib/src/models/network_record.dart` | role-match |
| `lib/src/interceptor/dio/network_inspector_dio_interceptor.dart` | middleware (client adapter) | request-response | `lib/src/utils/redaction_engine.dart` & `lib/src/core/network_inspector.dart` | role-match |
| `lib/src/interceptor/http/network_inspector_http_client.dart` | middleware (client adapter) | streaming / request-response | `lib/src/repository/in_memory_network_inspector_repository.dart` | role-match |
| `lib/src/logging/network_request_tracker.dart` | service / interface | request-response | `lib/src/repository/network_inspector_repository.dart` | exact |
| `lib/src/logging/network_request_tracker_impl.dart` | service / controller | request-response | `lib/src/models/network_record.dart` & `lib/src/repository/network_inspector_repository.dart` | role-match |
| `lib/src/logging/no_op_network_request_tracker.dart` | utility / service | request-response | `lib/src/storage/platform/ffi_init_stub.dart` | exact |
| `lib/src/logging/manual_logger.dart` | service / utility | request-response | `lib/src/utils/payload_truncator.dart` & `lib/src/utils/redaction_engine.dart` | role-match |
| `test/interceptor/stream_tap_transformer_test.dart` | test | streaming | `test/repository/write_buffer_queue_test.dart` | exact |
| `test/interceptor/http_overrides_chaining_test.dart` | test | request-response | `test/config/network_inspector_config_test.dart` | exact |
| `test/interceptor/inspector_http_client_test.dart` | test | request-response | `test/repository/in_memory_repository_test.dart` | exact |
| `test/interceptor/deduplication_test.dart` | test | request-response | `test/repository/write_buffer_queue_test.dart` | exact |
| `test/interceptor/dio_interceptor_test.dart` | test | request-response | `test/config/network_inspector_config_test.dart` | role-match |
| `test/interceptor/http_client_adapter_test.dart` | test | streaming | `test/config/network_inspector_config_test.dart` | role-match |
| `test/logging/manual_logging_test.dart` | test | request-response | `test/utils/payload_truncator_test.dart` | exact |

---

## Pattern Assignments

### 1. `pubspec.yaml` (config, file-I/O)

**Analog:** `pubspec.yaml`

**Core Pattern** (lines 10-17):
```yaml
dependencies:
  flutter:
    sdk: flutter
  uuid: ^4.6.0
  sqflite: ^2.4.5
  sqflite_common_ffi: ^2.4.5
  path: ^1.9.1
  dio: ">=5.0.0 <6.0.0"
  http: ">=1.0.0 <2.0.0"
```

---

### 2. `lib/flutter_network_inspector.dart` (config, transform)

**Analog:** `lib/flutter_network_inspector.dart`

**Imports and Re-Export Pattern** (lines 1-35):
```dart
/// Flutter Network Inspector
library flutter_network_inspector;

// Configuration
export 'src/config/network_inspector_config.dart';

// Core Facade & Constants
export 'src/core/constants.dart';
export 'src/core/network_inspector.dart';

// Repository & Storage
export 'src/repository/in_memory_network_inspector_repository.dart';
export 'src/repository/network_inspector_repository.dart';
export 'src/repository/sqlite_network_inspector_repository.dart';

// Domain Models
export 'src/models/body_type.dart';
export 'src/models/http_error_details.dart';
export 'src/models/multipart_entry.dart';
export 'src/models/network_record.dart';
export 'src/models/network_status.dart';
export 'src/models/payload_data.dart';
export 'src/models/record_filter.dart';
export 'src/models/record_sort.dart';

// Utilities
export 'src/utils/body_type_detector.dart';
export 'src/utils/payload_truncator.dart';
export 'src/utils/redaction_engine.dart';
export 'src/utils/uuid_generator.dart';

// Interceptor Adapters & Manual Logging (New in Phase 3)
export 'src/interceptor/dio/network_inspector_dio_interceptor.dart';
export 'src/interceptor/http/network_inspector_http_client.dart';
export 'src/logging/network_request_tracker.dart';
```

---

### 3. `lib/src/core/constants.dart` (config / utility, request-response)

**Analog:** `lib/src/core/constants.dart`

**Constant Declaration Pattern** (lines 1-31):
```dart
/// Package-wide constants for flutter_network_inspector.
abstract final class NetworkInspectorConstants {
  const NetworkInspectorConstants._();

  /// Default maximum records retained in local storage (D-01).
  static const int defaultMaxRecords = 500;

  /// Default maximum payload body bytes before truncation (1 MB / 1,048,576 bytes) (D-02).
  static const int defaultMaxBodyBytes = 1048576;

  /// Constant placeholder for redacted sensitive values (D-12).
  static const String redactedPlaceholder = '[REDACTED]';

  /// Internal tracking header used to correlate request/response pairs across interceptors.
  static const String internalTrackingHeader = 'x-fl-net-inspector-tracked-id';

  /// Public synthetic tracking header for cross-interceptor deduplication (D-33).
  static const String headerInspectorId = 'x-network-inspector-id';

  /// Default blacklist of sensitive keys for headers, query params, and JSON bodies (D-09).
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

---

### 4. `lib/src/config/network_inspector_config.dart` (config, request-response)

**Analog:** `lib/src/config/network_inspector_config.dart`

**Imports Pattern** (lines 1-3):
```dart
import 'package:flutter/foundation.dart';

import '../core/constants.dart';
```

**Immutable Model Pattern** (lines 6-56):
```dart
@immutable
class NetworkInspectorConfig {
  final bool? _enabled;
  final int maxRecords;
  final int maxBodyBytes;
  final bool enableAutoCapture;
  final bool enableShakeDetection;
  final bool enableDatabase;
  final bool includeMultipartFilePaths;
  final List<String> customRedactionKeys;
  final List<String> ignoredHosts;
  final List<String> ignoredUrls;

  const NetworkInspectorConfig({
    bool? enabled,
    this.maxRecords = NetworkInspectorConstants.defaultMaxRecords,
    this.maxBodyBytes = NetworkInspectorConstants.defaultMaxBodyBytes,
    this.enableAutoCapture = true,
    this.enableShakeDetection = true,
    this.enableDatabase = true,
    this.includeMultipartFilePaths = false,
    this.customRedactionKeys = const [],
    this.ignoredHosts = const [],
    this.ignoredUrls = const [],
  }) : _enabled = enabled;

  bool get enabled => _enabled ?? !kReleaseMode;
  bool get hasExplicitEnabled => _enabled != null;
```

**copyWith, Equality, and HashCode Pattern** (lines 58-106):
```dart
  NetworkInspectorConfig copyWith({
    bool? enabled,
    int? maxRecords,
    int? maxBodyBytes,
    bool? enableAutoCapture,
    bool? enableShakeDetection,
    bool? enableDatabase,
    bool? includeMultipartFilePaths,
    List<String>? customRedactionKeys,
    List<String>? ignoredHosts,
    List<String>? ignoredUrls,
  }) {
    return NetworkInspectorConfig(
      enabled: enabled ?? _enabled,
      maxRecords: maxRecords ?? this.maxRecords,
      maxBodyBytes: maxBodyBytes ?? this.maxBodyBytes,
      enableAutoCapture: enableAutoCapture ?? this.enableAutoCapture,
      enableShakeDetection: enableShakeDetection ?? this.enableShakeDetection,
      enableDatabase: enableDatabase ?? this.enableDatabase,
      includeMultipartFilePaths:
          includeMultipartFilePaths ?? this.includeMultipartFilePaths,
      customRedactionKeys: customRedactionKeys ?? this.customRedactionKeys,
      ignoredHosts: ignoredHosts ?? this.ignoredHosts,
      ignoredUrls: ignoredUrls ?? this.ignoredUrls,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NetworkInspectorConfig &&
        other._enabled == _enabled &&
        other.maxRecords == maxRecords &&
        other.maxBodyBytes == maxBodyBytes &&
        other.enableAutoCapture == enableAutoCapture &&
        other.enableShakeDetection == enableShakeDetection &&
        other.enableDatabase == enableDatabase &&
        other.includeMultipartFilePaths == includeMultipartFilePaths &&
        listEquals(other.customRedactionKeys, customRedactionKeys) &&
        listEquals(other.ignoredHosts, ignoredHosts) &&
        listEquals(other.ignoredUrls, ignoredUrls);
  }

  @override
  int get hashCode => Object.hash(
        _enabled,
        maxRecords,
        maxBodyBytes,
        enableAutoCapture,
        enableShakeDetection,
        enableDatabase,
        includeMultipartFilePaths,
        Object.hashAll(customRedactionKeys),
        Object.hashAll(ignoredHosts),
        Object.hashAll(ignoredUrls),
      );
```

---

### 5. `lib/src/core/network_inspector.dart` (controller, request-response)

**Analog:** `lib/src/core/network_inspector.dart`

**Imports Pattern** (lines 1-8):
```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/network_inspector_config.dart';
import '../interceptor/platform/http_capture_platform.dart';
import '../logging/manual_logger.dart';
import '../logging/network_request_tracker.dart';
import '../logging/no_op_network_request_tracker.dart';
import '../models/http_error_details.dart';
import '../repository/in_memory_network_inspector_repository.dart';
import '../repository/network_inspector_repository.dart';
import '../repository/sqlite_network_inspector_repository.dart';
import '../storage/platform/ffi_init.dart';
```

**Lifecycle & Auto-Capture Pattern** (lines 24-49, modified per D-37, D-40):
```dart
  static Future<void> initialize({
    NetworkInspectorConfig config = const NetworkInspectorConfig(),
    NetworkInspectorRepository? repository,
  }) async {
    _currentConfig = config;
    _isInitialized = true;

    if (!config.enabled) {
      _repository = null;
      return;
    }

    if (repository != null) {
      _repository = repository;
    } else if (kIsWeb || !config.enableDatabase) {
      _repository = InMemoryNetworkInspectorRepository(maxRecords: config.maxRecords);
    } else {
      initDesktopFfiIfRequired();
      final sqliteRepo = SqliteNetworkInspectorRepository(maxRecords: config.maxRecords);
      await sqliteRepo.initialize();
      _repository = sqliteRepo;
    }

    if (config.enableAutoCapture && !kIsWeb) {
      startAutoCapture();
    }
  }

  /// Installs global HttpOverrides for transparent dart:io HTTP capture (D-37, D-38).
  static void startAutoCapture() {
    if (!isEnabled || kIsWeb) return;
    installHttpOverrides(_currentConfig);
  }

  /// Restores pre-existing HttpOverrides, cleanly detaching dart:io interception (D-40).
  static void stopAutoCapture() {
    restoreHttpOverrides();
  }

  /// Executes [body] within a Zone configured with InspectorHttpOverrides (D-37).
  static R runZoned<R>(R Function() body) {
    if (!isEnabled || kIsWeb) return body();
    return runWithHttpOverrides(body, _currentConfig);
  }
```

**Manual Logging Facade Pattern** (D-45, D-46, D-47, D-48):
```dart
  /// Public static one-shot manual logging API for completed HTTP calls (LOG-01, LOG-02).
  static Future<void> logApi({
    required String method,
    required String url,
    int? statusCode,
    Map<String, dynamic>? requestHeaders,
    Map<String, dynamic>? responseHeaders,
    Object? requestBody,
    Object? responseBody,
    Duration? duration,
    DateTime? timestamp,
    HttpErrorDetails? error,
  }) async {
    if (!isEnabled || _repository == null) return;
    await ManualLogger.logApi(
      repository: _repository!,
      config: _currentConfig,
      method: method,
      url: url,
      statusCode: statusCode,
      requestHeaders: requestHeaders,
      responseHeaders: responseHeaders,
      requestBody: requestBody,
      responseBody: responseBody,
      duration: duration,
      timestamp: timestamp,
      error: error,
    );
  }

  /// Public two-phase request tracking API returning a [NetworkRequestTracker] (D-45).
  static NetworkRequestTracker startRequest({
    required String method,
    required String url,
    Map<String, dynamic>? headers,
    Object? body,
    DateTime? timestamp,
  }) {
    if (!isEnabled || _repository == null) {
      return const NoOpNetworkRequestTracker();
    }
    return ManualLogger.startRequest(
      repository: _repository!,
      config: _currentConfig,
      method: method,
      url: url,
      headers: headers,
      body: body,
      timestamp: timestamp,
    );
  }

  /// Logs a standalone or linked network failure (D-47).
  static Future<void> logError({
    String? id,
    required String method,
    required String url,
    required Object error,
    StackTrace? stackTrace,
    int? statusCode,
    Map<String, dynamic>? headers,
    Object? body,
  }) async {
    if (!isEnabled || _repository == null) return;
    await ManualLogger.logError(
      repository: _repository!,
      config: _currentConfig,
      id: id,
      method: method,
      url: url,
      error: error,
      stackTrace: stackTrace,
      statusCode: statusCode,
      headers: headers,
      body: body,
    );
  }
```

**Teardown & Testing Reset Pattern** (lines 69-82):
```dart
  static Future<void> dispose() async {
    stopAutoCapture();
    await _repository?.dispose();
    _repository = null;
    _isInitialized = false;
  }

  static void resetForTesting() {
    stopAutoCapture();
    _repository?.dispose();
    _repository = null;
    _currentConfig = const NetworkInspectorConfig();
    _isInitialized = false;
  }
```

---

### 6. Platform Export & Stubs (`http_capture_platform.dart`, `http_capture_stub.dart`, `http_capture_io.dart`)

**Analogs:** `lib/src/storage/platform/ffi_init.dart`, `ffi_init_stub.dart`, `ffi_init_io.dart`

**Platform Conditional Export (`lib/src/interceptor/platform/http_capture_platform.dart`):**
```dart
export 'http_capture_stub.dart' if (dart.library.io) 'http_capture_io.dart';
```

**Platform Web Stub (`lib/src/interceptor/platform/http_capture_stub.dart`):**
```dart
import '../../config/network_inspector_config.dart';

/// Web no-op stubs for HttpOverrides management.
void installHttpOverrides(NetworkInspectorConfig config) {}
void restoreHttpOverrides() {}
R runWithHttpOverrides<R>(R Function() body, NetworkInspectorConfig config) => body();
```

**Platform IO Implementation (`lib/src/interceptor/platform/http_capture_io.dart`):**
```dart
import 'dart:io';
import '../../config/network_inspector_config.dart';
import '../io/http_overrides_manager.dart';

HttpOverrides? _previousOverrides;
bool _isInstalled = false;

void installHttpOverrides(NetworkInspectorConfig config) {
  if (_isInstalled) return;
  _previousOverrides = HttpOverrides.current;
  HttpOverrides.global = InspectorHttpOverrides(
    previousOverrides: _previousOverrides,
    config: config,
  );
  _isInstalled = true;
}

void restoreHttpOverrides() {
  if (!_isInstalled) return;
  HttpOverrides.global = _previousOverrides;
  _previousOverrides = null;
  _isInstalled = false;
}

R runWithHttpOverrides<R>(R Function() body, NetworkInspectorConfig config) {
  final overrides = InspectorHttpOverrides(
    previousOverrides: HttpOverrides.current,
    config: config,
  );
  return HttpOverrides.runWithHttpOverrides(body, overrides);
}
```

---

### 7. `lib/src/interceptor/stream/stream_tap_transformer.dart` (utility, streaming)

**Analog:** `lib/src/repository/write_buffer_queue.dart` (lines 88-106: error isolation) & `lib/src/utils/payload_truncator.dart` (lines 80-116: byte slicing)

**Imports Pattern:**
```dart
import 'dart:async';
import 'dart:typed_data';
```

**Core Stream Transformer Pattern (INTC-03, D-41, D-43):**
```dart
/// Creates a non-destructive [StreamTransformer] that forwards incoming byte chunks
/// synchronously to consumer sinks while accumulating an internal copy up to [maxBodyBytes].
StreamTransformer<List<int>, List<int>> createStreamTapTransformer({
  required int maxBodyBytes,
  required bool isBinary,
  required void Function(List<int> bufferedBytes, bool isTruncated) onComplete,
  required void Function(Object error, StackTrace stackTrace, List<int> partialBytes) onError,
}) {
  final buffer = BytesBuilder(copy: false);
  int accumulatedBytes = 0;
  bool isTruncated = false;

  return StreamTransformer<List<int>, List<int>>.fromHandlers(
    handleData: (List<int> chunk, EventSink<List<int>> sink) {
      // 1. Synchronously forward chunk downstream to host application listener
      sink.add(chunk);

      // 2. Accumulate copy for network inspection buffer (skip raw bytes if binary per D-43)
      if (!isBinary) {
        if (accumulatedBytes + chunk.length <= maxBodyBytes) {
          buffer.add(chunk);
          accumulatedBytes += chunk.length;
        } else if (!isTruncated) {
          final remaining = maxBodyBytes - accumulatedBytes;
          if (remaining > 0) {
            buffer.add(chunk.sublist(0, remaining));
            accumulatedBytes += remaining;
          }
          isTruncated = true;
        }
      } else {
        accumulatedBytes += chunk.length;
      }
    },
    handleError: (Object error, StackTrace stackTrace, EventSink<List<int>> sink) {
      sink.addError(error, stackTrace);
      try {
        onError(error, stackTrace, buffer.takeBytes());
      } catch (_) {
        // Defensive error isolation
      }
    },
    handleDone: (EventSink<List<int>> sink) {
      sink.close();
      try {
        onComplete(buffer.takeBytes(), isTruncated);
      } catch (_) {
        // Defensive error isolation
      }
    },
  );
}
```

---

### 8. `lib/src/interceptor/io/http_overrides_manager.dart` (middleware, request-response)

**Analog:** `lib/src/core/network_inspector.dart` (lines 10-49: configuration injection and delegation)

**Imports Pattern:**
```dart
import 'dart:io';

import '../../config/network_inspector_config.dart';
import 'inspector_http_client.dart';
```

**Core Chaining Pattern (INTC-01, INTC-02, D-38):**
```dart
/// Custom [HttpOverrides] that safely delegates unmatched calls to [_previousOverrides]
/// while wrapping created clients in [InspectorHttpClient].
class InspectorHttpOverrides extends HttpOverrides {
  final HttpOverrides? _previousOverrides;
  final NetworkInspectorConfig _config;

  InspectorHttpOverrides({
    HttpOverrides? previousOverrides,
    required NetworkInspectorConfig config,
  })  : _previousOverrides = previousOverrides,
        _config = config;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final HttpClient client = _previousOverrides != null
        ? _previousOverrides!.createHttpClient(context)
        : super.createHttpClient(context);
    return InspectorHttpClient(client, _config);
  }

  @override
  String findProxyFromEnvironment(Uri url, Map<String, String>? environment) {
    if (_previousOverrides != null) {
      return _previousOverrides!.findProxyFromEnvironment(url, environment);
    }
    return super.findProxyFromEnvironment(url, environment);
  }
}
```

---

### 9. `lib/src/interceptor/io/inspector_http_client.dart` (middleware, request-response)

**Analog:** `lib/src/repository/in_memory_network_inspector_repository.dart` (lines 13-36: interface delegation)

**Core Proxy Pattern (INTC-01, D-39):**
```dart
import 'dart:io';

import '../../config/network_inspector_config.dart';
import 'inspector_http_client_request.dart';

class InspectorHttpClient implements HttpClient {
  final HttpClient _inner;
  final NetworkInspectorConfig _config;

  InspectorHttpClient(this._inner, this._config);

  // Forwarding two-way configuration properties per D-39
  @override
  Duration? get idleTimeout => _inner.idleTimeout;
  @override
  set idleTimeout(Duration? value) => _inner.idleTimeout = value;

  @override
  Duration? get connectionTimeout => _inner.connectionTimeout;
  @override
  set connectionTimeout(Duration? value) => _inner.connectionTimeout = value;

  @override
  String? get userAgent => _inner.userAgent;
  @override
  set userAgent(String? value) => _inner.userAgent = value;

  @override
  bool get autoUncompress => _inner.autoUncompress;
  @override
  set autoUncompress(bool value) => _inner.autoUncompress = value;

  @override
  set badCertificateCallback(bool Function(X509Certificate cert, String host, int port)? callback) =>
      _inner.badCertificateCallback = callback;

  // Intercepting request creation methods
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final request = await _inner.openUrl(method, url);
    return InspectorHttpClientRequest(request, method, url, _config);
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);

  @override
  Future<HttpClientRequest> headUrl(Uri url) => openUrl('HEAD', url);

  @override
  void close({bool force = false}) => _inner.close(force: force);
  ...
}
```

---

### 10. `lib/src/interceptor/io/inspector_http_client_request.dart` (middleware, streaming)

**Analog:** `lib/src/utils/redaction_engine.dart` (lines 36-63: header redaction) & `lib/src/repository/write_buffer_queue.dart` (lines 57-72: enqueuing state)

**Core Interception & Header Stripping Pattern (INTC-06, D-33, D-36):**
```dart
import 'dart:convert';
import 'dart:io';

import '../../config/network_inspector_config.dart';
import '../../core/constants.dart';
import '../../core/network_inspector.dart';
import '../../models/network_record.dart';
import '../../models/network_status.dart';
import '../../utils/uuid_generator.dart';
import 'inspector_http_client_response.dart';

class InspectorHttpClientRequest implements HttpClientRequest {
  final HttpClientRequest _inner;
  final String _method;
  final Uri _url;
  final NetworkInspectorConfig _config;

  final BytesBuilder _bodyBytes = BytesBuilder(copy: false);
  bool _isSuppressed = false;
  String? _transactionId;
  DateTime? _startTimestamp;

  InspectorHttpClientRequest(this._inner, this._method, this._url, this._config);

  @override
  void write(Object? obj) {
    if (!_isSuppressed && obj != null) {
      _bodyBytes.add(utf8.encode(obj.toString()));
    }
    _inner.write(obj);
  }

  @override
  void add(List<int> data) {
    if (!_isSuppressed) {
      _bodyBytes.add(data);
    }
    _inner.add(data);
  }

  @override
  Future<HttpClientResponse> close() async {
    // 1. Check for synthetic deduplication header (D-33, INTC-06)
    final trackingHeader = NetworkInspectorConstants.internalTrackingHeader;
    final publicHeader = NetworkInspectorConstants.headerInspectorId;
    final hasTrackingId = _inner.headers[trackingHeader] != null ||
        _inner.headers[publicHeader] != null;

    if (hasTrackingId) {
      // Strip synthetic header before wire transmission!
      _inner.headers.removeAll(trackingHeader);
      _inner.headers.removeAll(publicHeader);
      _isSuppressed = true;
    }

    // 2. Check blacklist (D-36)
    if (_isIgnored(_url)) {
      _isSuppressed = true;
    }

    if (!_isSuppressed && NetworkInspector.isEnabled) {
      _transactionId = UuidGenerator.v4();
      _startTimestamp = DateTime.now();

      // Persist pending record to repository
      final pendingRecord = NetworkRecord(
        id: _transactionId!,
        url: _url.toString(),
        baseUrl: '${_url.scheme}://${_url.authority}',
        path: _url.path,
        method: _method.toUpperCase(),
        requestHeaders: _extractHeaders(_inner.headers),
        requestQueryParams: _url.queryParameters,
        requestTimestamp: _startTimestamp!,
        status: NetworkStatus.pending,
      );
      unawaited(NetworkInspector.repository?.save(pendingRecord));
    }

    HttpClientResponse response;
    try {
      response = await _inner.close();
    } catch (e, st) {
      // Record socket or connection failure (INTC-07, D-44)
      if (!_isSuppressed && _transactionId != null) {
        _handleFailure(e, st);
      }
      rethrow;
    }

    if (_isSuppressed) {
      return response;
    }

    return InspectorHttpClientResponse(
      response,
      transactionId: _transactionId!,
      startTimestamp: _startTimestamp!,
      config: _config,
    );
  }

  bool _isIgnored(Uri uri) {
    final host = uri.host.toLowerCase();
    if (_config.ignoredHosts.any((h) => h.toLowerCase() == host)) return true;
    final fullUrl = uri.toString().toLowerCase();
    if (_config.ignoredUrls.any((u) => fullUrl.contains(u.toLowerCase()))) return true;
    return false;
  }
}
```

---

### 11. `lib/src/interceptor/io/inspector_http_client_response.dart` (middleware, streaming)

**Analog:** `lib/src/utils/payload_truncator.dart` (lines 80-116: truncateBytes) & `lib/src/models/network_record.dart` (lines 16-60)

**Core Stream Proxy Pattern (INTC-01, INTC-03, D-41, D-42, D-43):**
```dart
import 'dart:async';
import 'dart:io';

import '../../config/network_inspector_config.dart';
import '../../core/network_inspector.dart';
import '../../models/network_status.dart';
import '../../utils/payload_truncator.dart';
import '../../utils/redaction_engine.dart';
import '../stream/stream_tap_transformer.dart';

class InspectorHttpClientResponse extends StreamView<List<int>> implements HttpClientResponse {
  final HttpClientResponse _inner;
  final String transactionId;
  final DateTime startTimestamp;
  final NetworkInspectorConfig config;

  InspectorHttpClientResponse(
    this._inner, {
    required this.transactionId,
    required this.startTimestamp,
    required this.config,
  }) : super(
          _inner.transform(
            createStreamTapTransformer(
              maxBodyBytes: config.maxBodyBytes,
              isBinary: _isBinaryMime(_inner.headers.contentType?.mimeType),
              onComplete: (bytes, isTruncated) {
                _onResponseComplete(
                  inner: _inner,
                  transactionId: transactionId,
                  startTimestamp: startTimestamp,
                  config: config,
                  bytes: bytes,
                  isTruncated: isTruncated,
                );
              },
              onError: (error, stackTrace, partialBytes) {
                _onResponseError(
                  inner: _inner,
                  transactionId: transactionId,
                  startTimestamp: startTimestamp,
                  config: config,
                  error: error,
                  stackTrace: stackTrace,
                  partialBytes: partialBytes,
                );
              },
            ),
          ),
        );

  @override
  int get statusCode => _inner.statusCode;
  @override
  HttpHeaders get headers => _inner.headers;
  @override
  int get contentLength => _inner.contentLength;
  @override
  bool get isRedirect => _inner.isRedirect;
  @override
  String get reasonPhrase => _inner.reasonPhrase;
  ...
}
```

---

### 12. `lib/src/interceptor/dio/network_inspector_dio_interceptor.dart` (middleware, request-response)

**Analog:** `lib/src/utils/redaction_engine.dart` (lines 7-48: sanitization) & `lib/src/utils/payload_truncator.dart` (lines 25-77: truncation)

**Imports Pattern:**
```dart
import 'dart:async';
import 'package:dio/dio.dart';

import '../../config/network_inspector_config.dart';
import '../../core/constants.dart';
import '../../core/network_inspector.dart';
import '../../models/http_error_details.dart';
import '../../models/multipart_entry.dart';
import '../../models/network_record.dart';
import '../../models/network_status.dart';
import '../../utils/payload_truncator.dart';
import '../../utils/redaction_engine.dart';
import '../../utils/uuid_generator.dart';
```

**Core Dio Interceptor Pattern (INTC-04, D-33, D-34, D-36):**
```dart
class NetworkInspectorDioInterceptor extends Interceptor {
  static const _capturedKey = '__fl_net_inspector_captured';
  static const _recordIdKey = '__fl_net_inspector_id';
  static const _startTimeKey = '__fl_net_inspector_start';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!NetworkInspector.isEnabled) {
      return handler.next(options);
    }

    // D-34: Prevent duplicate capture from nested / repeated registrations
    if (options.extra[_capturedKey] == true) {
      return handler.next(options);
    }
    options.extra[_capturedKey] = true;

    // D-36: Host and URL blacklist check
    final uri = options.uri;
    if (_isIgnored(uri)) {
      return handler.next(options);
    }

    final id = UuidGenerator.v4();
    final startTimestamp = DateTime.now();
    options.extra[_recordIdKey] = id;
    options.extra[_startTimeKey] = startTimestamp;

    // D-33: Inject synthetic tracking header for low-level HttpOverrides deduplication
    options.headers[NetworkInspectorConstants.internalTrackingHeader] = id;
    options.headers[NetworkInspectorConstants.headerInspectorId] = id;

    // Extract multipart metadata if FormData (DATA-04)
    List<MultipartEntry>? multipartEntries;
    if (options.data is FormData) {
      final formData = options.data as FormData;
      multipartEntries = [
        for (final field in formData.fields)
          MultipartEntry(
            fieldName: field.key,
            isText: true,
            textValue: field.value,
          ),
        for (final file in formData.files)
          MultipartEntry(
            fieldName: file.key,
            fileName: file.value.filename,
            contentType: file.value.contentType?.mimeType,
            length: file.value.length,
            filePath: NetworkInspector.currentConfig.includeMultipartFilePaths ? null : null,
            isText: false,
          ),
      ];
    }

    // Save pending record
    final record = NetworkRecord(
      id: id,
      url: uri.toString(),
      baseUrl: '${uri.scheme}://${uri.authority}',
      path: uri.path,
      method: options.method.toUpperCase(),
      requestHeaders: Map<String, dynamic>.from(options.headers),
      requestQueryParams: uri.queryParameters,
      requestTimestamp: startTimestamp,
      multipartEntries: multipartEntries,
      status: NetworkStatus.pending,
    );

    unawaited(NetworkInspector.repository?.save(record));
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!NetworkInspector.isEnabled) {
      return handler.next(response);
    }

    final id = response.requestOptions.extra[_recordIdKey] as String?;
    final startTimestamp = response.requestOptions.extra[_startTimeKey] as DateTime?;

    if (id != null && startTimestamp != null) {
      final endTimestamp = DateTime.now();
      final durationMs = endTimestamp.difference(startTimestamp).inMilliseconds;
      _updateRecordSuccess(id, response, durationMs, endTimestamp);
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!NetworkInspector.isEnabled) {
      return handler.next(err);
    }

    final id = err.requestOptions.extra[_recordIdKey] as String?;
    final startTimestamp = err.requestOptions.extra[_startTimeKey] as DateTime?;

    if (id != null && startTimestamp != null) {
      final endTimestamp = DateTime.now();
      final durationMs = endTimestamp.difference(startTimestamp).inMilliseconds;
      _updateRecordFailed(id, err, durationMs, endTimestamp);
    }

    handler.next(err);
  }
}
```

---

### 13. `lib/src/interceptor/http/network_inspector_http_client.dart` (middleware, streaming / request-response)

**Analog:** `lib/src/repository/in_memory_network_inspector_repository.dart` & `lib/src/repository/network_inspector_repository.dart`

**Imports Pattern:**
```dart
import 'dart:async';
import 'package:http/http.dart' as http;

import '../../core/constants.dart';
import '../../core/network_inspector.dart';
import '../../models/http_error_details.dart';
import '../../models/network_record.dart';
import '../../models/network_status.dart';
import '../../utils/uuid_generator.dart';
import '../stream/stream_tap_transformer.dart';
```

**Core `http.BaseClient` Pattern (INTC-05, D-33, D-41):**
```dart
class NetworkInspectorHttpClient extends http.BaseClient {
  final http.Client _inner;

  NetworkInspectorHttpClient([http.Client? inner]) : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!NetworkInspector.isEnabled) {
      return _inner.send(request);
    }

    final id = UuidGenerator.v4();
    final startTimestamp = DateTime.now();

    // D-33: Inject synthetic header for deduplication
    request.headers[NetworkInspectorConstants.internalTrackingHeader] = id;
    request.headers[NetworkInspectorConstants.headerInspectorId] = id;

    // Save pending record
    final record = NetworkRecord(
      id: id,
      url: request.url.toString(),
      baseUrl: '${request.url.scheme}://${request.url.authority}',
      path: request.url.path,
      method: request.method.toUpperCase(),
      requestHeaders: Map<String, dynamic>.from(request.headers),
      requestQueryParams: request.url.queryParameters,
      requestTimestamp: startTimestamp,
      status: NetworkStatus.pending,
    );
    unawaited(NetworkInspector.repository?.save(record));

    http.StreamedResponse response;
    try {
      response = await _inner.send(request);
    } catch (e, st) {
      // INTC-07: Error handling
      final durationMs = DateTime.now().difference(startTimestamp).inMilliseconds;
      final errorRecord = record.copyWith(
        durationMs: durationMs,
        status: NetworkStatus.failed,
        errorDetails: HttpErrorDetails(
          message: e.toString(),
          errorType: e.runtimeType.toString(),
          stackTrace: st.toString(),
        ),
      );
      unawaited(NetworkInspector.repository?.save(errorRecord));
      rethrow;
    }

    // Tap response stream non-destructively
    final tappedStream = response.stream.transform(
      createStreamTapTransformer(
        maxBodyBytes: NetworkInspector.currentConfig.maxBodyBytes,
        isBinary: _isBinary(response.headers['content-type']),
        onComplete: (bytes, isTruncated) {
          final durationMs = DateTime.now().difference(startTimestamp).inMilliseconds;
          // Build completed record and update repository
        },
        onError: (err, st, partialBytes) {
          final durationMs = DateTime.now().difference(startTimestamp).inMilliseconds;
          // Build failed record and update repository
        },
      ),
    );

    return http.StreamedResponse(
      http.ByteStream(tappedStream),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() {
    _inner.close();
  }
}
```

---

### 14. `lib/src/logging/network_request_tracker.dart` (interface, request-response)

**Analog:** `lib/src/repository/network_inspector_repository.dart` (lines 7-36: abstract interface class contract)

**Interface Contract (LOG-01, D-45):**
```dart
/// Two-phase request tracker contract for recording asynchronous HTTP operations
/// like GraphQL, gRPC, WebSockets, or custom SDKs with exact timing.
abstract interface class NetworkRequestTracker {
  /// The unique RFC 4122 v4 transaction identifier for this request.
  String get id;

  /// Completes the tracked request with a server response.
  Future<void> onResponse({
    required int statusCode,
    Map<String, dynamic>? headers,
    Object? body,
    DateTime? timestamp,
  });

  /// Completes the tracked request as failed with error details.
  Future<void> onError({
    required Object error,
    StackTrace? stackTrace,
    int? statusCode,
    Map<String, dynamic>? headers,
    Object? body,
  });
}
```

---

### 15. `lib/src/logging/no_op_network_request_tracker.dart` (utility, request-response)

**Analog:** `lib/src/storage/platform/ffi_init_stub.dart` (lines 1-3) & `lib/src/core/constants.dart` (lines 2-4)

**Zero-Allocation Implementation (D-48):**
```dart
import 'network_request_tracker.dart';

/// Zero-allocation no-op implementation of [NetworkRequestTracker] returned
/// when network inspection is disabled or running in release mode without explicit override.
final class NoOpNetworkRequestTracker implements NetworkRequestTracker {
  const NoOpNetworkRequestTracker();

  @override
  String get id => '';

  @override
  Future<void> onResponse({
    required int statusCode,
    Map<String, dynamic>? headers,
    Object? body,
    DateTime? timestamp,
  }) async {}

  @override
  Future<void> onError({
    required Object error,
    StackTrace? stackTrace,
    int? statusCode,
    Map<String, dynamic>? headers,
    Object? body,
  }) async {}
}
```

---

### 16. `lib/src/logging/manual_logger.dart` & `network_request_tracker_impl.dart` (service, request-response)

**Analog:** `lib/src/utils/payload_truncator.dart` (lines 25-77) & `lib/src/utils/redaction_engine.dart` (lines 36-94)

**Core Object Preprocessing Pattern (D-46, LOG-02):**
```dart
import 'dart:convert';
import '../config/network_inspector_config.dart';
import '../models/payload_data.dart';
import '../utils/body_type_detector.dart';
import '../utils/payload_truncator.dart';
import '../utils/redaction_engine.dart';

abstract final class ManualLogger {
  const ManualLogger._();

  /// Converts an arbitrary `Object?` (Map, List, String, Uint8List) into sanitized [PayloadData].
  static PayloadData processPayload({
    required Object? rawBody,
    required String? contentType,
    required NetworkInspectorConfig config,
  }) {
    if (rawBody == null) return const PayloadData();

    final redactionEngine = RedactionEngine(customKeys: config.customRedactionKeys);

    if (rawBody is List<int>) {
      return PayloadTruncator.truncateBytes(
        bytes: rawBody,
        contentType: contentType,
        maxBytes: config.maxBodyBytes,
      );
    }

    String stringBody;
    if (rawBody is String) {
      stringBody = rawBody;
    } else if (rawBody is Map || rawBody is List) {
      try {
        stringBody = jsonEncode(rawBody);
      } catch (_) {
        stringBody = rawBody.toString();
      }
    } else {
      stringBody = rawBody.toString();
    }

    final redactedBody = redactionEngine.redactBody(stringBody, contentType);
    return PayloadTruncator.truncate(
      body: redactedBody,
      contentType: contentType,
      maxBytes: config.maxBodyBytes,
    );
  }
}
```

---

### 17. Test Files

**Analog:** `test/repository/write_buffer_queue_test.dart` (lines 1-203) & `test/config/network_inspector_config_test.dart` (lines 1-140)

**Test File Skeleton:**
```dart
import 'package:flutter_network_inspector/flutter_network_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GroupName', () {
    late InMemoryNetworkInspectorRepository testRepo;

    setUp(() async {
      testRepo = InMemoryNetworkInspectorRepository();
      await NetworkInspector.initialize(
        config: const NetworkInspectorConfig(enabled: true, enableDatabase: false),
        repository: testRepo,
      );
    });

    tearDown(() {
      NetworkInspector.resetForTesting();
    });

    test('verifies behavior matching decision requirements', () async {
      // Setup, execute, expect
    });
  });
}
```

---

## Shared Patterns

### 1. Defensive Error Isolation
**Source:** `lib/src/repository/write_buffer_queue.dart` (lines 96-98) & `lib/src/utils/redaction_engine.dart` (lines 90-93)  
**Apply to:** All interceptor handlers (`onRequest`, `onResponse`, `onError`, `close()`, stream transformer callbacks)  
**Description:** Network inspection is diagnostic instrumentation; under no circumstances may an inspector bug, parsing failure, or database disk error disrupt or abort the host application's network traffic. Every internal logging operation must be protected by a try/catch boundary that silently swallows internal inspection faults while re-throwing user application errors.
```dart
try {
  // Capture, deserialize, redact, or persist inspection record
} catch (_) {
  // Defensive error isolation prevents inspector errors from crashing user networking
}
```

---

### 2. Release-Mode Zero-Overhead Guard
**Source:** `lib/src/core/network_inspector.dart` (lines 31-34) & `lib/src/config/network_inspector_config.dart` (lines 52-53)  
**Apply to:** `NetworkInspectorDioInterceptor.onRequest`, `NetworkInspectorHttpClient.send`, `InspectorHttpClientRequest.close`, and all manual logging methods  
**Description:** Inspecting `NetworkInspector.isEnabled` before performing any memory allocation, UUID generation, string formatting, or stream wrapping ensures true zero production overhead in release builds per D-03 and D-48.
```dart
if (!NetworkInspector.isEnabled) {
  return handler.next(options); // Dio
  // or return _inner.send(request); // http
  // or return const NoOpNetworkRequestTracker(); // startRequest
}
```

---

### 3. Redaction & Truncation Pipeline
**Source:** `lib/src/utils/payload_truncator.dart` (lines 25-77) & `lib/src/utils/redaction_engine.dart` (lines 36-127)  
**Apply to:** `InspectorHttpClientResponse`, `NetworkInspectorDioInterceptor`, `NetworkInspectorHttpClient`, and `ManualLogger`  
**Description:** When capturing payloads, apply operations in a strict invariant sequence:
1. Detect declared content type and binary formats via `BodyTypeDetector`.
2. Sanitize sensitive headers, query parameters, and JSON/Form keys via `RedactionEngine`.
3. Truncate body strings or byte arrays exceeding `config.maxBodyBytes` via `PayloadTruncator`, appending standardized truncation banners or binary summaries.
4. Construct immutable `PayloadData` and assign to `NetworkRecord`.

---

### 4. Two-Phase In-Memory Coalescing Update
**Source:** `lib/src/repository/write_buffer_queue.dart` (lines 57-72) & `lib/src/repository/in_memory_network_inspector_repository.dart` (lines 25-36)  
**Apply to:** All interceptors and request trackers (`dart:io`, `Dio`, `http`, manual tracker)  
**Description:** When a request begins, persist a `NetworkRecord` with `status: NetworkStatus.pending`. When the response arrives or network fails, update the existing record with response/error details, duration, and terminal status (`success` or `failed`), calling `repository.save(record)`. The repository automatically coalesces the record by `id`.

---

### 5. Web-Safe Conditional Platform Imports
**Source:** `lib/src/storage/platform/ffi_init.dart` (lines 1-2)  
**Apply to:** `lib/src/interceptor/platform/http_capture_platform.dart`  
**Description:** `dart:io` cannot be statically imported on Flutter Web (`kIsWeb`). Encapsulate all `dart:io` `HttpOverrides` logic in `http_capture_io.dart` and export via conditional import with a pure Dart no-op stub `http_capture_stub.dart`.

---

## No Analog Found

Every file to be created or modified in Phase 3 maps to an existing codebase analog or standard pattern within the established architecture.

---

## Metadata

**Analog search scope:** `lib/`, `test/`, `pubspec.yaml`  
**Files scanned:** 44 Dart files across models, config, core, repository, storage, and utils  
**Pattern extraction date:** 2026-11-01  
