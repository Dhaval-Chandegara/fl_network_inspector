import '../config/network_inspector_config.dart';

/// Public singleton facade for initializing and accessing the Flutter Network Inspector.
final class NetworkInspector {
  NetworkInspector._();

  static NetworkInspectorConfig _currentConfig = const NetworkInspectorConfig();
  static bool _isInitialized = false;

  /// Initializes the Network Inspector with the specified [config].
  ///
  /// If not invoked prior to app execution, defaults to standard debug-safe configuration.
  static void initialize({
    NetworkInspectorConfig config = const NetworkInspectorConfig(),
  }) {
    _currentConfig = config;
    _isInitialized = true;
  }

  /// Returns the current active configuration.
  static NetworkInspectorConfig get currentConfig => _currentConfig;

  /// Returns whether the inspector is enabled and active in this runtime environment.
  static bool get isEnabled => _currentConfig.enabled;

  /// Returns whether [initialize] has been explicitly called.
  static bool get isInitialized => _isInitialized;

  /// Resets configuration and state to uninitialized defaults (for testing purposes).
  static void resetForTesting() {
    _currentConfig = const NetworkInspectorConfig();
    _isInitialized = false;
  }
}
