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
