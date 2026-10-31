import 'package:flutter/foundation.dart';

/// Detailed exception, socket error, or HTTP failure diagnostics.
@immutable
class HttpErrorDetails {
  /// The human-readable error description or exception message.
  final String message;

  /// The runtime type or classification of the error (e.g. `SocketException`, `TimeoutException`, `DioException`).
  final String? errorType;

  /// Stringified stack trace captured at the failure site.
  final String? stackTrace;

  /// The associated HTTP response status code, if any.
  final int? statusCode;

  /// Creates an [HttpErrorDetails] instance.
  const HttpErrorDetails({
    required this.message,
    this.errorType,
    this.stackTrace,
    this.statusCode,
  });

  /// Creates a copy of this [HttpErrorDetails] with updated properties.
  HttpErrorDetails copyWith({
    String? message,
    String? errorType,
    String? stackTrace,
    int? statusCode,
  }) {
    return HttpErrorDetails(
      message: message ?? this.message,
      errorType: errorType ?? this.errorType,
      stackTrace: stackTrace ?? this.stackTrace,
      statusCode: statusCode ?? this.statusCode,
    );
  }

  /// Converts this model into a database- and JSON-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'error_type': errorType,
      'stack_trace': stackTrace,
      'status_code': statusCode,
    };
  }

  /// Deserializes an [HttpErrorDetails] from a map.
  factory HttpErrorDetails.fromMap(Map<String, dynamic> map) {
    final rawStatusCode = map['status_code'] ?? map['statusCode'];
    final int? statusCode = (rawStatusCode is num)
        ? rawStatusCode.toInt()
        : (rawStatusCode != null ? int.tryParse(rawStatusCode.toString()) : null);

    return HttpErrorDetails(
      message: (map['message'] ?? '') as String,
      errorType: map['error_type'] as String? ?? map['errorType'] as String?,
      stackTrace: map['stack_trace'] as String? ?? map['stackTrace'] as String?,
      statusCode: statusCode,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HttpErrorDetails &&
        other.message == message &&
        other.errorType == errorType &&
        other.stackTrace == stackTrace &&
        other.statusCode == statusCode;
  }

  @override
  int get hashCode => Object.hash(message, errorType, stackTrace, statusCode);

  @override
  String toString() {
    return 'HttpErrorDetails(message: $message, errorType: $errorType, '
        'statusCode: $statusCode, stackTrace: ${stackTrace != null ? "present" : "null"})';
  }
}
