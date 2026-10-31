import 'package:flutter/foundation.dart';

import '../config/network_inspector_config.dart';
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
      return;
    }

    if (kIsWeb || !config.enableDatabase) {
      _repository = InMemoryNetworkInspectorRepository(maxRecords: config.maxRecords);
    } else {
      initDesktopFfiIfRequired();
      final sqliteRepo = SqliteNetworkInspectorRepository(maxRecords: config.maxRecords);
      await sqliteRepo.initialize();
      _repository = sqliteRepo;
    }
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

  /// Disposes the active repository and resets inspector state (D-24).
  static Future<void> dispose() async {
    await _repository?.dispose();
    _repository = null;
    _isInitialized = false;
  }

  /// Resets configuration, repository, and state to uninitialized defaults (for testing purposes).
  static void resetForTesting() {
    _repository?.dispose();
    _repository = null;
    _currentConfig = const NetworkInspectorConfig();
    _isInitialized = false;
  }
}
