import 'network_request_tracker.dart';

/// Zero-allocation, production-safe no-op implementation of [NetworkRequestTracker]
/// returned when network inspection is disabled or running in release mode without explicit override (D-48).
final class NoOpNetworkRequestTracker implements NetworkRequestTracker {
  /// Const constructor ensuring zero memory allocation overhead in production.
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
