/// Two-phase request tracker contract for recording asynchronous HTTP operations
/// like GraphQL, gRPC, WebSockets, or custom SDKs with exact timing (D-45, LOG-01).
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
