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

/// Public singleton facade for initializing and accessing the Flutter Network Inspector.
final class NetworkInspector {
  NetworkInspector._();

  static NetworkInspectorConfig _currentConfig = const NetworkInspectorConfig();
  static bool _isInitialized = false;
  static NetworkInspectorRepository? _repository;

  /// Initializes the Network Inspector with the specified [config] and optional [repository].
  ///
  /// If [config.enabled] is false (e.g. in release mode by default per D-03), storage
  /// and interceptor pipelines remain disabled.
  /// If [repository] is provided, it is used directly (useful for tests or custom backends).
  /// Otherwise, routes to [InMemoryNetworkInspectorRepository] on Web or when [config.enableDatabase]
  /// is false, or to [SqliteNetworkInspectorRepository] with desktop FFI initialization.
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

  /// Installs global [HttpOverrides] for transparent dart:io HTTP capture (D-37, D-38).
  static void startAutoCapture() {
    if (!isEnabled || kIsWeb) return;
    installHttpOverrides(_currentConfig);
  }

  /// Restores pre-existing [HttpOverrides], cleanly detaching dart:io interception (D-40).
  static void stopAutoCapture() {
    restoreHttpOverrides();
  }

  /// Executes [body] within a Zone configured with [InspectorHttpOverrides] (D-37).
  static R runZoned<R>(R Function() body) {
    if (!isEnabled || kIsWeb) return body();
    return runWithHttpOverrides(body, _currentConfig);
  }

  /// Public static one-shot manual logging API for completed HTTP calls (LOG-01, LOG-02, D-45).
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

  /// Public two-phase request tracking API returning a [NetworkRequestTracker] (D-45, LOG-01).
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

  /// Returns the active data access repository, or `null` if disabled.
  static NetworkInspectorRepository? get repository => _repository;

  /// Returns the current active configuration.
  static NetworkInspectorConfig get currentConfig => _currentConfig;

  /// Returns whether the inspector is enabled and active in this runtime environment.
  static bool get isEnabled => _currentConfig.enabled;

  /// Returns whether [initialize] has been explicitly called.
  static bool get isInitialized => _isInitialized;

  /// Flushes any pending in-memory write buffer queue entries to durable storage (D-24).
  static Future<void> flush() async {
    await _repository?.flush();
  }

  /// Disposes the active repository and resets inspector state (D-24, D-40).
  static Future<void> dispose() async {
    stopAutoCapture();
    await _repository?.dispose();
    _repository = null;
    _isInitialized = false;
  }

  /// Resets configuration, repository, and state to uninitialized defaults (for testing purposes).
  static void resetForTesting() {
    stopAutoCapture();
    _repository?.dispose();
    _repository = null;
    _currentConfig = const NetworkInspectorConfig();
    _isInitialized = false;
  }
}
