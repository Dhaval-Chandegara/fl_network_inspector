import 'dart:async';

import '../config/network_inspector_config.dart';
import '../models/body_type.dart';
import '../models/http_error_details.dart';
import '../models/network_record.dart';
import '../models/network_status.dart';
import '../repository/network_inspector_repository.dart';
import '../utils/redaction_engine.dart';
import 'manual_logger.dart';
import 'network_request_tracker.dart';

/// Concrete implementation of [NetworkRequestTracker] that records an initial pending record
/// and updates it on completion with exact elapsed duration (D-45, LOG-01).
class NetworkRequestTrackerImpl implements NetworkRequestTracker {
  final NetworkInspectorRepository _repository;
  final NetworkInspectorConfig _config;
  @override
  final String id;
  final String _method;
  final String _url;
  final DateTime _startTimestamp;

  final Completer<void> _initCompleter = Completer<void>();
  NetworkRecord? _pendingRecord;
  final RedactionEngine _engine;

  NetworkRequestTrackerImpl({
    required NetworkInspectorRepository repository,
    required NetworkInspectorConfig config,
    required this.id,
    required String method,
    required String url,
    Map<String, dynamic>? headers,
    Object? body,
    required DateTime startTimestamp,
  })  : _repository = repository,
        _config = config,
        _method = method,
        _url = url,
        _startTimestamp = startTimestamp,
        _engine = RedactionEngine(customKeys: config.customRedactionKeys) {
    unawaited(_initPending(headers, body));
  }

  Future<void> _initPending(Map<String, dynamic>? headers, Object? body) async {
    try {
      final uri = Uri.tryParse(_url);
      final baseUrl = uri != null ? '${uri.scheme}://${uri.authority}' : '';
      final path = uri?.path ?? '';
      final queryParams = uri?.queryParameters ?? const {};

      final sanitizedReqHeaders = headers != null
          ? _engine
              .redactHeaders(headers)
              .map((k, v) => MapEntry(k, v.toString()))
          : null;
      final sanitizedQueryParams = _engine.redactQueryParams(queryParams);
      final reqContentType = ManualLogger.findContentType(headers);

      final reqPayload = ManualLogger.processPayload(
        rawBody: body,
        contentType: reqContentType,
        config: _config,
      );

      final multipartEntries = ManualLogger.extractMultipartEntries(body);

      _pendingRecord = NetworkRecord(
        id: id,
        url: _engine.redactUrl(_url),
        baseUrl: baseUrl,
        path: path,
        method: _method.toUpperCase(),
        status: NetworkStatus.pending,
        requestHeaders: sanitizedReqHeaders ?? const {},
        requestQueryParams: sanitizedQueryParams,
        requestBody: reqPayload.bodyType != BodyType.empty ? reqPayload : null,
        requestContentType: reqContentType ??
            (reqPayload.bodyType == BodyType.json ? 'application/json' : null),
        requestSize: reqPayload.byteSize,
        multipartEntries: multipartEntries,
        requestTimestamp: _startTimestamp,
      );

      await _repository.save(_pendingRecord!);
    } catch (_) {
      // Defensive isolation
    } finally {
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    }
  }

  @override
  Future<void> onResponse({
    required int statusCode,
    Map<String, dynamic>? headers,
    Object? body,
    DateTime? timestamp,
  }) async {
    await _initCompleter.future;

    try {
      final endTimestamp = timestamp ?? DateTime.now();
      final durationMs =
          endTimestamp.difference(_startTimestamp).inMilliseconds;

      final sanitizedRespHeaders = headers != null
          ? _engine
              .redactHeaders(headers)
              .map((k, v) => MapEntry(k, v.toString()))
          : null;
      final respContentType = ManualLogger.findContentType(headers);

      final respPayload = ManualLogger.processPayload(
        rawBody: body,
        contentType: respContentType,
        config: _config,
      );

      final base = _pendingRecord;
      final updated = base != null
          ? base.copyWith(
              responseStatusCode: statusCode,
              status: NetworkStatus.success,
              responseHeaders: sanitizedRespHeaders,
              responseBody:
                  respPayload.bodyType != BodyType.empty ? respPayload : null,
              responseContentType: respContentType ??
                  (respPayload.bodyType == BodyType.json
                      ? 'application/json'
                      : null),
              responseSize: respPayload.byteSize,
              durationMs: durationMs,
              responseTimestamp: endTimestamp,
            )
          : NetworkRecord(
              id: id,
              url: _engine.redactUrl(_url),
              baseUrl: '',
              path: '',
              method: _method.toUpperCase(),
              responseStatusCode: statusCode,
              status: NetworkStatus.success,
              responseHeaders: sanitizedRespHeaders,
              responseBody:
                  respPayload.bodyType != BodyType.empty ? respPayload : null,
              responseContentType: respContentType,
              responseSize: respPayload.byteSize,
              durationMs: durationMs,
              requestTimestamp: _startTimestamp,
              responseTimestamp: endTimestamp,
            );

      await _repository.save(updated);
    } catch (_) {
      // Defensive isolation
    }
  }

  @override
  Future<void> onError({
    required Object error,
    StackTrace? stackTrace,
    int? statusCode,
    Map<String, dynamic>? headers,
    Object? body,
  }) async {
    await _initCompleter.future;

    try {
      final endTimestamp = DateTime.now();
      final durationMs =
          endTimestamp.difference(_startTimestamp).inMilliseconds;

      final sanitizedRespHeaders = headers != null
          ? _engine
              .redactHeaders(headers)
              .map((k, v) => MapEntry(k, v.toString()))
          : null;
      final respContentType = ManualLogger.findContentType(headers);

      final respPayload = ManualLogger.processPayload(
        rawBody: body,
        contentType: respContentType,
        config: _config,
      );

      final errorDetails = HttpErrorDetails(
        message: error.toString(),
        errorType: error.runtimeType.toString(),
        stackTrace: stackTrace?.toString(),
        statusCode: statusCode,
      );

      final base = _pendingRecord;
      final updated = base != null
          ? base.copyWith(
              responseStatusCode: statusCode,
              status: NetworkStatus.failed,
              responseHeaders: sanitizedRespHeaders,
              responseBody:
                  respPayload.bodyType != BodyType.empty ? respPayload : null,
              responseContentType: respContentType,
              responseSize: respPayload.byteSize,
              durationMs: durationMs,
              error: errorDetails,
              responseTimestamp: endTimestamp,
            )
          : NetworkRecord(
              id: id,
              url: _engine.redactUrl(_url),
              baseUrl: '',
              path: '',
              method: _method.toUpperCase(),
              responseStatusCode: statusCode,
              status: NetworkStatus.failed,
              responseHeaders: sanitizedRespHeaders,
              responseBody:
                  respPayload.bodyType != BodyType.empty ? respPayload : null,
              responseContentType: respContentType,
              responseSize: respPayload.byteSize,
              durationMs: durationMs,
              error: errorDetails,
              requestTimestamp: _startTimestamp,
              responseTimestamp: endTimestamp,
            );

      await _repository.save(updated);
    } catch (_) {
      // Defensive isolation
    }
  }
}
