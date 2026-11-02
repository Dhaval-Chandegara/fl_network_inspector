import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/constants.dart';

/// Immutable configuration for the flutter_network_inspector package.
@immutable
class NetworkInspectorConfig {
  /// Internal storage for explicit enablement.
  final bool? _enabled;

  /// Optional root navigator key for programmatic inspector display (D-52).
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Maximum records persisted in local storage before automatic FIFO pruning (D-01).
  final int maxRecords;

  /// Maximum payload bytes captured per request or response body before truncation (D-02).
  final int maxBodyBytes;

  /// Whether automatic HTTP client interception is enabled (D-04).
  final bool enableAutoCapture;

  /// Whether shake-to-open gesture detection is enabled (D-04).
  final bool enableShakeDetection;

  /// Accelerometer motion vector magnitude threshold in m/s² required to register a shake (SHAKE-01, SHAKE-02).
  final double shakeThreshold;

  /// Cooldown debounce window in milliseconds after a shake event before accepting subsequent shakes (SHAKE-02).
  final int shakeDebounceMs;

  /// Whether SQLite persistence is enabled (D-04).
  final bool enableDatabase;

  /// Whether local file paths are retained in multipart form inspection metadata (D-15).
  final bool includeMultipartFilePaths;

  /// Custom sensitive keys to redact from headers, query params, and JSON bodies.
  final List<String> customRedactionKeys;

  /// Hostnames to bypass capture early without interceptor allocations (D-36).
  final List<String> ignoredHosts;

  /// URL substrings or patterns to bypass capture early (D-36).
  final List<String> ignoredUrls;

  /// Creates a [NetworkInspectorConfig] with configurable parameters.
  ///
  /// When [enabled] is omitted, it evaluates dynamically to `!kReleaseMode` (D-03),
  /// guaranteeing that network inspection is disabled in production builds unless
  /// explicitly forced.
  const NetworkInspectorConfig({
    bool? enabled,
    this.navigatorKey,
    this.maxRecords = NetworkInspectorConstants.defaultMaxRecords,
    this.maxBodyBytes = NetworkInspectorConstants.defaultMaxBodyBytes,
    this.enableAutoCapture = true,
    this.enableShakeDetection = true,
    this.shakeThreshold = NetworkInspectorConstants.defaultShakeThreshold,
    this.shakeDebounceMs = NetworkInspectorConstants.defaultShakeDebounceMs,
    this.enableDatabase = true,
    this.includeMultipartFilePaths = false,
    this.customRedactionKeys = const [],
    this.ignoredHosts = const [],
    this.ignoredUrls = const [],
  }) : _enabled = enabled;

  /// Evaluates whether the inspector is active.
  ///
  /// Defaults to `!kReleaseMode` (disabled in release builds) unless explicitly
  /// overridden during initialization (D-03).
  bool get enabled => _enabled ?? !kReleaseMode;

  /// Returns whether [enabled] was explicitly specified rather than defaulting.
  bool get hasExplicitEnabled => _enabled != null;

  /// Creates a modified copy of this configuration.
  NetworkInspectorConfig copyWith({
    bool? enabled,
    GlobalKey<NavigatorState>? navigatorKey,
    int? maxRecords,
    int? maxBodyBytes,
    bool? enableAutoCapture,
    bool? enableShakeDetection,
    double? shakeThreshold,
    int? shakeDebounceMs,
    bool? enableDatabase,
    bool? includeMultipartFilePaths,
    List<String>? customRedactionKeys,
    List<String>? ignoredHosts,
    List<String>? ignoredUrls,
  }) {
    return NetworkInspectorConfig(
      enabled: enabled ?? _enabled,
      navigatorKey: navigatorKey ?? this.navigatorKey,
      maxRecords: maxRecords ?? this.maxRecords,
      maxBodyBytes: maxBodyBytes ?? this.maxBodyBytes,
      enableAutoCapture: enableAutoCapture ?? this.enableAutoCapture,
      enableShakeDetection: enableShakeDetection ?? this.enableShakeDetection,
      shakeThreshold: shakeThreshold ?? this.shakeThreshold,
      shakeDebounceMs: shakeDebounceMs ?? this.shakeDebounceMs,
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
        other.navigatorKey == navigatorKey &&
        other.maxRecords == maxRecords &&
        other.maxBodyBytes == maxBodyBytes &&
        other.enableAutoCapture == enableAutoCapture &&
        other.enableShakeDetection == enableShakeDetection &&
        other.shakeThreshold == shakeThreshold &&
        other.shakeDebounceMs == shakeDebounceMs &&
        other.enableDatabase == enableDatabase &&
        other.includeMultipartFilePaths == includeMultipartFilePaths &&
        listEquals(other.customRedactionKeys, customRedactionKeys) &&
        listEquals(other.ignoredHosts, ignoredHosts) &&
        listEquals(other.ignoredUrls, ignoredUrls);
  }

  @override
  int get hashCode => Object.hash(
        _enabled,
        navigatorKey,
        maxRecords,
        maxBodyBytes,
        enableAutoCapture,
        enableShakeDetection,
        shakeThreshold,
        shakeDebounceMs,
        enableDatabase,
        includeMultipartFilePaths,
        Object.hashAll(customRedactionKeys),
        Object.hashAll(ignoredHosts),
        Object.hashAll(ignoredUrls),
      );

  @override
  String toString() {
    return 'NetworkInspectorConfig(enabled: $enabled, navigatorKey: $navigatorKey, '
        'maxRecords: $maxRecords, '
        'maxBodyBytes: $maxBodyBytes, enableAutoCapture: $enableAutoCapture, '
        'enableShakeDetection: $enableShakeDetection, '
        'shakeThreshold: $shakeThreshold, shakeDebounceMs: $shakeDebounceMs, '
        'enableDatabase: $enableDatabase, '
        'includeMultipartFilePaths: $includeMultipartFilePaths, '
        'customRedactionKeys: $customRedactionKeys, '
        'ignoredHosts: $ignoredHosts, ignoredUrls: $ignoredUrls)';
  }
}
