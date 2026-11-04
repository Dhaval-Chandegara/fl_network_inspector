import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../config/network_inspector_config.dart';
import '../models/body_type.dart';
import '../models/http_error_details.dart';
import '../models/multipart_entry.dart';
import '../models/network_record.dart';
import '../models/network_status.dart';
import '../models/payload_data.dart';
import '../repository/network_inspector_repository.dart';
import '../utils/payload_truncator.dart';
import '../utils/redaction_engine.dart';
import '../utils/uuid_generator.dart';
import 'network_request_tracker.dart';
import 'network_request_tracker_impl.dart';

/// Service coordinating manual network logging, two-phase request tracking,
/// and error recording (LOG-01, LOG-02, D-45, D-46, D-47).
abstract final class ManualLogger {
  const ManualLogger._();

  /// Extracts the content-type value from a header map regardless of casing.
  static String? findContentType(Map<String, dynamic>? headers) {
    if (headers == null) return null;
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == 'content-type') {
        return entry.value?.toString();
      }
    }
    return null;
  }

  /// Extracts any [MultipartEntry] items if [rawBody] contains them.
  static List<MultipartEntry>? extractMultipartEntries(Object? rawBody) {
    if (rawBody == null) return null;
    if (rawBody is MultipartEntry) {
      return [rawBody];
    }
    if (rawBody is Iterable<MultipartEntry>) {
      return rawBody.toList();
    }
    if (rawBody is Iterable) {
      final entries = rawBody.whereType<MultipartEntry>().toList();
      if (entries.isNotEmpty) return entries;
    }
    return null;
  }

  /// Preprocesses an arbitrary [rawBody] (Map, List, String, Uint8List, MultipartEntry)
  /// through [RedactionEngine] and [PayloadTruncator] into a bounded, sanitized [PayloadData].
  static PayloadData processPayload({
    required Object? rawBody,
    String? contentType,
    required NetworkInspectorConfig config,
  }) {
    if (rawBody == null) return const PayloadData();

    if (rawBody is PayloadData) {
      return rawBody;
    }

    final engine = RedactionEngine(customKeys: config.customRedactionKeys);

    // 1. Raw byte buffer (Uint8List or List<int>)
    if (rawBody is Uint8List || rawBody is List<int>) {
      final bytes = rawBody is Uint8List
          ? rawBody
          : Uint8List.fromList(rawBody as List<int>);
      final effectiveMime = contentType ?? 'application/octet-stream';
      final truncated = PayloadTruncator.truncateBytes(
        bytes: bytes,
        contentType: effectiveMime,
        maxBytes: config.maxBodyBytes,
      );
      final redacted = engine.redactBody(truncated.body, effectiveMime);
      return truncated.copyWith(body: redacted);
    }

    // 2. Multipart entries collection
    final multipartList = extractMultipartEntries(rawBody);
    if (multipartList != null && multipartList.isNotEmpty) {
      final summary = '[Multipart: ${multipartList.length} entries]';
      return PayloadData(
        body: summary,
        byteSize: utf8.encode(summary).length,
        bodyType: BodyType.multipart,
        isTruncated: false,
      );
    }

    // 3. Map or List (JSON structures)
    if (rawBody is Map || rawBody is List) {
      String jsonStr;
      try {
        jsonStr = jsonEncode(rawBody);
      } catch (_) {
        jsonStr = rawBody.toString();
      }
      final effectiveMime = contentType ?? 'application/json';
      final redacted = engine.redactBody(jsonStr, effectiveMime);
      return PayloadTruncator.truncate(
        body: redacted,
        contentType: effectiveMime,
        maxBytes: config.maxBodyBytes,
      );
    }

    // 4. String or other Object primitives
    final strBody = rawBody is String ? rawBody : rawBody.toString();
    final redacted = engine.redactBody(strBody, contentType);
    return PayloadTruncator.truncate(
      body: redacted,
      contentType: contentType,
      maxBytes: config.maxBodyBytes,
    );
  }

  /// Initiates two-phase request tracking returning a [NetworkRequestTracker] (D-45).
  static NetworkRequestTracker startRequest({
    required NetworkInspectorRepository repository,
    required NetworkInspectorConfig config,
    required String method,
    required String url,
    Map<String, dynamic>? headers,
    Object? body,
    DateTime? timestamp,
  }) {
    final id = UuidGenerator.v4();
    final start = timestamp ?? DateTime.now();

    return NetworkRequestTrackerImpl(
      repository: repository,
      config: config,
      id: id,
      method: method,
      url: url,
      headers: headers,
      body: body,
      startTimestamp: start,
    );
  }

  /// Records a completed network event directly into the repository (LOG-01, LOG-02, D-45).
  static Future<void> logApi({
    required NetworkInspectorRepository repository,
    required NetworkInspectorConfig config,
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
    try {
      final engine = RedactionEngine(customKeys: config.customRedactionKeys);
      final id = UuidGenerator.v4();
      final reqTimestamp = timestamp ?? DateTime.now();
      final durationMs = duration?.inMilliseconds ?? 0;
      final respTimestamp =
          reqTimestamp.add(Duration(milliseconds: durationMs));

      final uri = Uri.tryParse(url);
      final baseUrl = uri != null ? '${uri.scheme}://${uri.authority}' : '';
      final path = uri?.path ?? '';
      final queryParams = uri?.queryParameters ?? const {};

      final sanitizedReqHeaders = requestHeaders != null
          ? engine
              .redactHeaders(requestHeaders)
              .map((k, v) => MapEntry(k, v.toString()))
          : null;
      final sanitizedRespHeaders = responseHeaders != null
          ? engine
              .redactHeaders(responseHeaders)
              .map((k, v) => MapEntry(k, v.toString()))
          : null;
      final sanitizedQueryParams = engine.redactQueryParams(queryParams);

      final reqContentType = findContentType(requestHeaders);
      final respContentType = findContentType(responseHeaders);

      final reqPayload = processPayload(
        rawBody: requestBody,
        contentType: reqContentType,
        config: config,
      );
      final respPayload = processPayload(
        rawBody: responseBody,
        contentType: respContentType,
        config: config,
      );

      final multipartEntries = extractMultipartEntries(requestBody);

      final status =
          error != null ? NetworkStatus.failed : NetworkStatus.success;

      final record = NetworkRecord(
        id: id,
        url: engine.redactUrl(url),
        baseUrl: baseUrl,
        path: path,
        method: method.toUpperCase(),
        responseStatusCode: statusCode,
        status: status,
        requestHeaders: sanitizedReqHeaders ?? const {},
        responseHeaders: sanitizedRespHeaders,
        requestQueryParams: sanitizedQueryParams,
        requestBody: reqPayload.bodyType != BodyType.empty ? reqPayload : null,
        responseBody:
            respPayload.bodyType != BodyType.empty ? respPayload : null,
        requestContentType: reqContentType ??
            (reqPayload.bodyType == BodyType.json ? 'application/json' : null),
        responseContentType: respContentType ??
            (respPayload.bodyType == BodyType.json ? 'application/json' : null),
        requestSize: reqPayload.byteSize,
        responseSize: respPayload.byteSize,
        error: error,
        multipartEntries: multipartEntries,
        durationMs: durationMs,
        requestTimestamp: reqTimestamp,
        responseTimestamp: respTimestamp,
      );

      await repository.save(record);
    } catch (_) {
      // Defensive isolation
    }
  }

  /// Logs a standalone or linked network failure (D-47).
  static Future<void> logError({
    required NetworkInspectorRepository repository,
    required NetworkInspectorConfig config,
    String? id,
    required String method,
    required String url,
    required Object error,
    StackTrace? stackTrace,
    int? statusCode,
    Map<String, dynamic>? headers,
    Object? body,
  }) async {
    try {
      final engine = RedactionEngine(customKeys: config.customRedactionKeys);

      final errorDetails = HttpErrorDetails(
        message: error.toString(),
        errorType: error.runtimeType.toString(),
        stackTrace: stackTrace?.toString(),
        statusCode: statusCode,
      );

      // Linked error logging: update existing transaction if id is present (D-47)
      if (id != null && id.isNotEmpty) {
        final existing = await repository.getById(id);
        if (existing != null) {
          PayloadData? responsePayload;
          if (body != null) {
            responsePayload = processPayload(
              rawBody: body,
              contentType: findContentType(headers),
              config: config,
            );
          }
          final sanitizedRespHeaders = headers != null
              ? engine
                  .redactHeaders(headers)
                  .map((k, v) => MapEntry(k, v.toString()))
              : null;

          final now = DateTime.now();
          final updated = existing.copyWith(
            status: NetworkStatus.failed,
            error: errorDetails,
            responseStatusCode: statusCode ?? existing.responseStatusCode,
            responseHeaders: sanitizedRespHeaders ?? existing.responseHeaders,
            responseBody: responsePayload ?? existing.responseBody,
            responseContentType:
                findContentType(headers) ?? existing.responseContentType,
            responseSize: responsePayload?.byteSize ?? existing.responseSize,
            responseTimestamp: now,
            durationMs:
                now.difference(existing.requestTimestamp).inMilliseconds,
          );
          await repository.save(updated);
          return;
        }
      }

      // Standalone error logging: create a fresh failed record (D-47)
      final generatedId = id != null && id.isNotEmpty ? id : UuidGenerator.v4();
      final now = DateTime.now();
      final uri = Uri.tryParse(url);
      final baseUrl = uri != null ? '${uri.scheme}://${uri.authority}' : '';
      final path = uri?.path ?? '';
      final queryParams = uri?.queryParameters ?? const {};

      final sanitizedHeaders = headers != null
          ? engine
              .redactHeaders(headers)
              .map((k, v) => MapEntry(k, v.toString()))
          : null;
      final sanitizedQueryParams = engine.redactQueryParams(queryParams);

      final contentType = findContentType(headers);
      final payload = processPayload(
        rawBody: body,
        contentType: contentType,
        config: config,
      );

      final record = NetworkRecord(
        id: generatedId,
        url: engine.redactUrl(url),
        baseUrl: baseUrl,
        path: path,
        method: method.toUpperCase(),
        responseStatusCode: statusCode,
        status: NetworkStatus.failed,
        requestHeaders: sanitizedHeaders ?? const {},
        requestQueryParams: sanitizedQueryParams,
        requestBody: payload.bodyType != BodyType.empty ? payload : null,
        requestContentType: contentType,
        requestSize: payload.byteSize,
        error: errorDetails,
        requestTimestamp: now,
        responseTimestamp: now,
        durationMs: 0,
      );

      await repository.save(record);
    } catch (_) {
      // Defensive isolation
    }
  }
}
