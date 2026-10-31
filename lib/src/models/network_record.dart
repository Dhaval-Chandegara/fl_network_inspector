import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../utils/uuid_generator.dart';
import 'http_error_details.dart';
import 'multipart_entry.dart';
import 'network_status.dart';
import 'payload_data.dart';

/// Unified immutable domain model representing an HTTP transaction across its complete lifecycle.
///
/// Models in-flight requests (status == pending), completed requests (status == success),
/// and failed requests (status == failed).
@immutable
class NetworkRecord {
  /// Unique RFC 4122 v4 transaction identifier.
  final String id;

  /// Full absolute request URL including scheme, host, path, and query string.
  final String url;

  /// Base URL (scheme + authority / host + port).
  final String baseUrl;

  /// URL path without scheme or query parameters.
  final String path;

  /// HTTP verb (e.g. GET, POST, PUT, DELETE, PATCH).
  final String method;

  /// Captured HTTP request headers.
  final Map<String, dynamic> requestHeaders;

  /// Parsed query string parameters.
  final Map<String, dynamic> requestQueryParams;

  /// Captured request body payload data.
  final PayloadData? requestBody;

  /// Request MIME content type (e.g., `application/json`).
  final String? requestContentType;

  /// Total request body size in bytes.
  final int requestSize;

  /// Timestamp when the request was initiated.
  final DateTime requestTimestamp;

  /// HTTP response status code (e.g. 200, 404, 500), null while in-flight.
  final int? responseStatusCode;

  /// Captured HTTP response headers, null while in-flight.
  final Map<String, dynamic>? responseHeaders;

  /// Captured response body payload data, null while in-flight.
  final PayloadData? responseBody;

  /// Response MIME content type.
  final String? responseContentType;

  /// Total response size in bytes.
  final int? responseSize;

  /// Timestamp when the response or error was received.
  final DateTime? responseTimestamp;

  /// Total round-trip duration in milliseconds.
  final int? durationMs;

  /// Lifecycle state of this transaction.
  final NetworkStatus status;

  /// Detailed error or exception information when the transaction fails.
  final HttpErrorDetails? error;

  /// Multipart form upload entries metadata, if applicable.
  final List<MultipartEntry>? multipartEntries;

  /// Creates an immutable [NetworkRecord] instance.
  NetworkRecord({
    String? id,
    required this.url,
    required this.baseUrl,
    required this.path,
    required this.method,
    this.requestHeaders = const {},
    this.requestQueryParams = const {},
    this.requestBody,
    this.requestContentType,
    this.requestSize = 0,
    required this.requestTimestamp,
    this.responseStatusCode,
    this.responseHeaders,
    this.responseBody,
    this.responseContentType,
    this.responseSize,
    this.responseTimestamp,
    this.durationMs,
    this.status = NetworkStatus.pending,
    this.error,
    this.multipartEntries,
  }) : id = id ?? UuidGenerator.v4();

  /// Constant constructor when all fields including [id] are explicitly supplied.
  const NetworkRecord.raw({
    required this.id,
    required this.url,
    required this.baseUrl,
    required this.path,
    required this.method,
    this.requestHeaders = const {},
    this.requestQueryParams = const {},
    this.requestBody,
    this.requestContentType,
    this.requestSize = 0,
    required this.requestTimestamp,
    this.responseStatusCode,
    this.responseHeaders,
    this.responseBody,
    this.responseContentType,
    this.responseSize,
    this.responseTimestamp,
    this.durationMs,
    this.status = NetworkStatus.pending,
    this.error,
    this.multipartEntries,
  });

  /// Whether the request is currently in flight.
  bool get isPending => status == NetworkStatus.pending;

  /// Whether the request completed successfully.
  bool get isSuccess => status == NetworkStatus.success;

  /// Whether the request encountered a network error or failure.
  bool get isFailed => status == NetworkStatus.failed;

  /// Whether this transaction represents an error (exception or HTTP status >= 400).
  bool get hasError =>
      error != null ||
      (responseStatusCode != null && responseStatusCode! >= 400);

  /// Creates a copy of this record with updated fields.
  NetworkRecord copyWith({
    String? id,
    String? url,
    String? baseUrl,
    String? path,
    String? method,
    Map<String, dynamic>? requestHeaders,
    Map<String, dynamic>? requestQueryParams,
    PayloadData? requestBody,
    String? requestContentType,
    int? requestSize,
    DateTime? requestTimestamp,
    int? responseStatusCode,
    Map<String, dynamic>? responseHeaders,
    PayloadData? responseBody,
    String? responseContentType,
    int? responseSize,
    DateTime? responseTimestamp,
    int? durationMs,
    NetworkStatus? status,
    HttpErrorDetails? error,
    List<MultipartEntry>? multipartEntries,
  }) {
    return NetworkRecord.raw(
      id: id ?? this.id,
      url: url ?? this.url,
      baseUrl: baseUrl ?? this.baseUrl,
      path: path ?? this.path,
      method: method ?? this.method,
      requestHeaders: requestHeaders ?? this.requestHeaders,
      requestQueryParams: requestQueryParams ?? this.requestQueryParams,
      requestBody: requestBody ?? this.requestBody,
      requestContentType: requestContentType ?? this.requestContentType,
      requestSize: requestSize ?? this.requestSize,
      requestTimestamp: requestTimestamp ?? this.requestTimestamp,
      responseStatusCode: responseStatusCode ?? this.responseStatusCode,
      responseHeaders: responseHeaders ?? this.responseHeaders,
      responseBody: responseBody ?? this.responseBody,
      responseContentType: responseContentType ?? this.responseContentType,
      responseSize: responseSize ?? this.responseSize,
      responseTimestamp: responseTimestamp ?? this.responseTimestamp,
      durationMs: durationMs ?? this.durationMs,
      status: status ?? this.status,
      error: error ?? this.error,
      multipartEntries: multipartEntries ?? this.multipartEntries,
    );
  }

  /// Converts this record to a database row and JSON-compatible Map with snake_case keys.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'base_url': baseUrl,
      'path': path,
      'method': method,
      'request_headers': jsonEncode(requestHeaders),
      'request_query_params': jsonEncode(requestQueryParams),
      'request_body': requestBody != null ? jsonEncode(requestBody!.toMap()) : null,
      'request_content_type': requestContentType,
      'request_size': requestSize,
      'request_timestamp': requestTimestamp.toIso8601String(),
      'response_status_code': responseStatusCode,
      'response_headers': responseHeaders != null ? jsonEncode(responseHeaders) : null,
      'response_body': responseBody != null ? jsonEncode(responseBody!.toMap()) : null,
      'response_content_type': responseContentType,
      'response_size': responseSize,
      'response_timestamp': responseTimestamp?.toIso8601String(),
      'duration_ms': durationMs,
      'status': status.toJson(),
      'error': error != null ? jsonEncode(error!.toMap()) : null,
      'multipart_entries': multipartEntries != null
          ? jsonEncode(multipartEntries!.map((e) => e.toMap()).toList())
          : null,
    };
  }

  /// Deserializes a [NetworkRecord] from a database row or JSON Map.
  ///
  /// Seamlessly parses both pre-encoded JSON strings (from SQLite) and
  /// native Dart Map / List structures.
  factory NetworkRecord.fromMap(Map<String, dynamic> map) {
    dynamic decodeIfString(dynamic val) {
      if (val is String && val.trim().isNotEmpty) {
        try {
          return jsonDecode(val);
        } catch (_) {
          return val;
        }
      }
      return val;
    }

    Map<String, dynamic> parseMap(dynamic val) {
      final decoded = decodeIfString(val);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return const {};
    }

    Map<String, dynamic>? parseNullableMap(dynamic val) {
      if (val == null) return null;
      final decoded = decodeIfString(val);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    }

    PayloadData? parsePayload(dynamic val) {
      if (val == null) return null;
      final decoded = decodeIfString(val);
      if (decoded is Map<String, dynamic>) {
        return PayloadData.fromMap(decoded);
      } else if (decoded is Map) {
        return PayloadData.fromMap(Map<String, dynamic>.from(decoded));
      }
      return null;
    }

    HttpErrorDetails? parseError(dynamic val) {
      if (val == null) return null;
      final decoded = decodeIfString(val);
      if (decoded is Map<String, dynamic>) {
        return HttpErrorDetails.fromMap(decoded);
      } else if (decoded is Map) {
        return HttpErrorDetails.fromMap(Map<String, dynamic>.from(decoded));
      }
      return null;
    }

    List<MultipartEntry>? parseMultipart(dynamic val) {
      if (val == null) return null;
      final decoded = decodeIfString(val);
      if (decoded is List) {
        return decoded
            .whereType<Map<dynamic, dynamic>>()
            .map((e) => MultipartEntry.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
      return null;
    }

    DateTime parseDateTime(dynamic val) {
      if (val is DateTime) return val;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    DateTime? parseNullableDateTime(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final rawStatusCode = map['response_status_code'] ?? map['responseStatusCode'];
    final int? responseStatusCode = (rawStatusCode is num)
        ? rawStatusCode.toInt()
        : (rawStatusCode != null ? int.tryParse(rawStatusCode.toString()) : null);

    final rawRequestSize = map['request_size'] ?? map['requestSize'] ?? 0;
    final int requestSize = (rawRequestSize is num)
        ? rawRequestSize.toInt()
        : int.tryParse(rawRequestSize.toString()) ?? 0;

    final rawResponseSize = map['response_size'] ?? map['responseSize'];
    final int? responseSize = (rawResponseSize is num)
        ? rawResponseSize.toInt()
        : (rawResponseSize != null ? int.tryParse(rawResponseSize.toString()) : null);

    final rawDuration = map['duration_ms'] ?? map['durationMs'];
    final int? durationMs = (rawDuration is num)
        ? rawDuration.toInt()
        : (rawDuration != null ? int.tryParse(rawDuration.toString()) : null);

    return NetworkRecord.raw(
      id: (map['id'] as String?)?.isNotEmpty == true ? map['id'] as String : UuidGenerator.v4(),
      url: (map['url'] ?? '') as String,
      baseUrl: (map['base_url'] ?? map['baseUrl'] ?? '') as String,
      path: (map['path'] ?? '') as String,
      method: ((map['method'] ?? 'GET') as String).toUpperCase(),
      requestHeaders: parseMap(map['request_headers'] ?? map['requestHeaders']),
      requestQueryParams: parseMap(map['request_query_params'] ?? map['requestQueryParams']),
      requestBody: parsePayload(map['request_body'] ?? map['requestBody']),
      requestContentType: map['request_content_type'] as String? ?? map['requestContentType'] as String?,
      requestSize: requestSize,
      requestTimestamp: parseDateTime(map['request_timestamp'] ?? map['requestTimestamp']),
      responseStatusCode: responseStatusCode,
      responseHeaders: parseNullableMap(map['response_headers'] ?? map['responseHeaders']),
      responseBody: parsePayload(map['response_body'] ?? map['responseBody']),
      responseContentType: map['response_content_type'] as String? ?? map['responseContentType'] as String?,
      responseSize: responseSize,
      responseTimestamp: parseNullableDateTime(map['response_timestamp'] ?? map['responseTimestamp']),
      durationMs: durationMs,
      status: NetworkStatus.fromString(map['status'] as String?),
      error: parseError(map['error']),
      multipartEntries: parseMultipart(map['multipart_entries'] ?? map['multipartEntries']),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NetworkRecord &&
        other.id == id &&
        other.url == url &&
        other.method == method &&
        other.requestTimestamp == requestTimestamp &&
        other.responseStatusCode == responseStatusCode &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(
        id,
        url,
        method,
        requestTimestamp,
        responseStatusCode,
        status,
      );

  @override
  String toString() {
    return 'NetworkRecord(id: $id, method: $method, url: $url, '
        'status: $status, statusCode: $responseStatusCode, duration: ${durationMs}ms)';
  }
}
