import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';

import '../../config/network_inspector_config.dart';
import '../../core/constants.dart';
import '../../core/network_inspector.dart';
import '../../models/body_type.dart';
import '../../models/http_error_details.dart';
import '../../models/multipart_entry.dart';
import '../../models/network_record.dart';
import '../../models/network_status.dart';
import '../../models/payload_data.dart';
import '../../utils/payload_truncator.dart';
import '../../utils/redaction_engine.dart';
import '../../utils/uuid_generator.dart';

/// Dedicated client adapter interceptor for [Dio] 5.x (INTC-04).
///
/// Captures complete request, response, and error lifecycles, injects synthetic
/// deduplication headers (D-33), guards against repeated registrations (D-34),
/// supports retries with fresh IDs (D-35), and extracts FormData multipart
/// metadata without storing raw file bytes (DATA-04).
class NetworkInspectorDioInterceptor extends Interceptor {
  static const String _capturedKey = '__fl_net_inspector_captured';
  static const String _recordIdKey = '__fl_net_inspector_id';
  static const String _startTimeKey = '__fl_net_inspector_start';
  static const String _pendingRecordKey = '__fl_net_inspector_pending_record';
  static const String _completedKey = '__fl_net_inspector_completed';

  const NetworkInspectorDioInterceptor();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!NetworkInspector.isEnabled) {
      return handler.next(options);
    }

    // D-34: Guard against repeat or nested interceptor registrations
    if (options.extra[_capturedKey] == true) {
      return handler.next(options);
    }
    options.extra[_capturedKey] = true;

    // D-36: Host and URL blacklist check
    final uri = options.uri;
    if (_isIgnored(uri)) {
      return handler.next(options);
    }

    final id = UuidGenerator.v4();
    final startTimestamp = DateTime.now();
    options.extra[_recordIdKey] = id;
    options.extra[_startTimeKey] = startTimestamp;

    // D-33: Inject synthetic tracking headers for low-level HttpOverrides deduplication
    options.headers[NetworkInspectorConstants.internalTrackingHeader] = id;
    options.headers[NetworkInspectorConstants.headerInspectorId] = id;

    final config = NetworkInspector.currentConfig;
    final engine = RedactionEngine(customKeys: config.customRedactionKeys);

    // Sanitize headers and query parameters
    final rawHeaders = <String, dynamic>{};
    options.headers.forEach((name, value) {
      rawHeaders[name] = value;
    });
    final sanitizedHeaders = engine.redactHeaders(rawHeaders);
    final sanitizedQueryParams = engine.redactQueryParams(uri.queryParameters);

    // Process request payload and multipart metadata (DATA-04)
    PayloadData? requestPayload;
    List<MultipartEntry>? multipartEntries;
    int requestSize = 0;
    final contentType = options.contentType ?? options.headers['content-type']?.toString();

    if (options.data != null) {
      if (options.data is FormData) {
        final formData = options.data as FormData;
        final entries = <MultipartEntry>[];
        int totalBytes = 0;

        for (final field in formData.fields) {
          final fieldBytes = utf8.encode(field.value).length;
          totalBytes += fieldBytes;
          entries.add(
            MultipartEntry(
              fieldName: field.key,
              contentType: 'text/plain',
              byteSize: fieldBytes,
            ),
          );
        }

        for (final file in formData.files) {
          final f = file.value;
          totalBytes += f.length;
          entries.add(
            MultipartEntry(
              fieldName: file.key,
              fileName: f.filename,
              contentType: f.contentType?.mimeType,
              byteSize: f.length,
              filePath: config.includeMultipartFilePaths ? null : null,
            ),
          );
        }

        multipartEntries = entries;
        requestSize = totalBytes;
        requestPayload = PayloadData(
          body:
              '[MultipartFormData: ${formData.fields.length} fields, ${formData.files.length} files]',
          byteSize: totalBytes,
          bodyType: BodyType.formData,
          isTruncated: false,
        );
      } else if (options.data is Map || options.data is List) {
        String jsonStr;
        try {
          jsonStr = jsonEncode(options.data);
        } catch (_) {
          jsonStr = options.data.toString();
        }
        final redacted = engine.redactBody(jsonStr, 'application/json');
        requestPayload = PayloadTruncator.truncate(
          body: redacted,
          contentType: 'application/json',
          maxBytes: config.maxBodyBytes,
        );
        requestSize = requestPayload.byteSize;
      } else if (options.data is String) {
        final str = options.data as String;
        final redacted = engine.redactBody(str, contentType);
        requestPayload = PayloadTruncator.truncate(
          body: redacted,
          contentType: contentType,
          maxBytes: config.maxBodyBytes,
        );
        requestSize = requestPayload.byteSize;
      } else if (options.data is List<int>) {
        final bytes = options.data as List<int>;
        final truncated = PayloadTruncator.truncateBytes(
          bytes: bytes,
          contentType: contentType,
          maxBytes: config.maxBodyBytes,
        );
        final redacted = engine.redactBody(truncated.body, contentType);
        requestPayload = truncated.copyWith(body: redacted);
        requestSize = requestPayload.byteSize;
      } else {
        final str = options.data.toString();
        final redacted = engine.redactBody(str, contentType);
        requestPayload = PayloadTruncator.truncate(
          body: redacted,
          contentType: contentType,
          maxBytes: config.maxBodyBytes,
        );
        requestSize = requestPayload.byteSize;
      }
    }

    final pendingRecord = NetworkRecord(
      id: id,
      url: engine.redactUrl(uri.toString()),
      baseUrl: '${uri.scheme}://${uri.authority}',
      path: uri.path,
      method: options.method.toUpperCase(),
      requestHeaders: sanitizedHeaders,
      requestQueryParams: sanitizedQueryParams,
      requestBody: requestPayload,
      requestContentType: contentType,
      requestSize: requestSize,
      requestTimestamp: startTimestamp,
      multipartEntries: multipartEntries,
      status: NetworkStatus.pending,
    );

    options.extra[_pendingRecordKey] = pendingRecord;
    unawaited(NetworkInspector.repository?.save(pendingRecord));
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!NetworkInspector.isEnabled) {
      return handler.next(response);
    }

    if (response.requestOptions.extra[_completedKey] == true) {
      return handler.next(response);
    }
    response.requestOptions.extra[_completedKey] = true;

    final id = response.requestOptions.extra[_recordIdKey] as String?;
    final startTimestamp = response.requestOptions.extra[_startTimeKey] as DateTime?;
    final pendingRecord = response.requestOptions.extra[_pendingRecordKey] as NetworkRecord?;

    if (id != null && startTimestamp != null) {
      final endTimestamp = DateTime.now();
      final durationMs = endTimestamp.difference(startTimestamp).inMilliseconds;
      final config = NetworkInspector.currentConfig;
      final engine = RedactionEngine(customKeys: config.customRedactionKeys);

      final rawHeaders = <String, dynamic>{};
      response.headers.forEach((name, values) {
        rawHeaders[name] = values.join(', ');
      });
      final sanitizedResponseHeaders = engine.redactHeaders(rawHeaders);

      final contentType = response.headers.value('content-type');
      PayloadData? responsePayload;

      if (response.data != null) {
        if (response.data is Map || response.data is List) {
          String jsonStr;
          try {
            jsonStr = jsonEncode(response.data);
          } catch (_) {
            jsonStr = response.data.toString();
          }
          final redacted = engine.redactBody(jsonStr, 'application/json');
          responsePayload = PayloadTruncator.truncate(
            body: redacted,
            contentType: 'application/json',
            maxBytes: config.maxBodyBytes,
          );
        } else if (response.data is String) {
          final str = response.data as String;
          final redacted = engine.redactBody(str, contentType);
          responsePayload = PayloadTruncator.truncate(
            body: redacted,
            contentType: contentType,
            maxBytes: config.maxBodyBytes,
          );
        } else if (response.data is List<int>) {
          final bytes = response.data as List<int>;
          final truncated = PayloadTruncator.truncateBytes(
            bytes: bytes,
            contentType: contentType,
            maxBytes: config.maxBodyBytes,
          );
          final redacted = engine.redactBody(truncated.body, contentType);
          responsePayload = truncated.copyWith(body: redacted);
        } else {
          final str = response.data.toString();
          final redacted = engine.redactBody(str, contentType);
          responsePayload = PayloadTruncator.truncate(
            body: redacted,
            contentType: contentType,
            maxBytes: config.maxBodyBytes,
          );
        }
      }

      final uri = response.requestOptions.uri;
      final completedRecord = (pendingRecord != null)
          ? pendingRecord.copyWith(
              responseStatusCode: response.statusCode,
              responseHeaders: sanitizedResponseHeaders,
              responseBody: responsePayload,
              responseContentType: contentType,
              responseSize: responsePayload?.byteSize ?? 0,
              responseTimestamp: endTimestamp,
              durationMs: durationMs,
              status: NetworkStatus.success,
            )
          : NetworkRecord(
              id: id,
              url: engine.redactUrl(uri.toString()),
              baseUrl: '${uri.scheme}://${uri.authority}',
              path: uri.path,
              method: response.requestOptions.method.toUpperCase(),
              requestTimestamp: startTimestamp,
              responseStatusCode: response.statusCode,
              responseHeaders: sanitizedResponseHeaders,
              responseBody: responsePayload,
              responseContentType: contentType,
              responseSize: responsePayload?.byteSize ?? 0,
              responseTimestamp: endTimestamp,
              durationMs: durationMs,
              status: NetworkStatus.success,
            );

      unawaited(NetworkInspector.repository?.save(completedRecord));
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!NetworkInspector.isEnabled) {
      return handler.next(err);
    }

    if (err.requestOptions.extra[_completedKey] == true) {
      return handler.next(err);
    }
    err.requestOptions.extra[_completedKey] = true;
    // D-35: Reset captured flag on options so retrying the request generates a fresh record
    err.requestOptions.extra[_capturedKey] = false;

    final id = err.requestOptions.extra[_recordIdKey] as String?;
    final startTimestamp = err.requestOptions.extra[_startTimeKey] as DateTime?;
    final pendingRecord = err.requestOptions.extra[_pendingRecordKey] as NetworkRecord?;

    if (id != null && startTimestamp != null) {
      final endTimestamp = DateTime.now();
      final durationMs = endTimestamp.difference(startTimestamp).inMilliseconds;
      final config = NetworkInspector.currentConfig;
      final engine = RedactionEngine(customKeys: config.customRedactionKeys);

      final errorDetails = HttpErrorDetails(
        message: err.message ?? err.error?.toString() ?? err.type.name,
        errorType: err.type.name,
        stackTrace: err.stackTrace.toString(),
        statusCode: err.response?.statusCode,
      );

      Map<String, dynamic>? sanitizedResponseHeaders;
      PayloadData? responsePayload;
      String? contentType;

      if (err.response != null) {
        final rawHeaders = <String, dynamic>{};
        err.response!.headers.forEach((name, values) {
          rawHeaders[name] = values.join(', ');
        });
        sanitizedResponseHeaders = engine.redactHeaders(rawHeaders);
        contentType = err.response!.headers.value('content-type');

        if (err.response!.data != null) {
          if (err.response!.data is Map || err.response!.data is List) {
            String jsonStr;
            try {
              jsonStr = jsonEncode(err.response!.data);
            } catch (_) {
              jsonStr = err.response!.data.toString();
            }
            final redacted = engine.redactBody(jsonStr, 'application/json');
            responsePayload = PayloadTruncator.truncate(
              body: redacted,
              contentType: 'application/json',
              maxBytes: config.maxBodyBytes,
            );
          } else if (err.response!.data is String) {
            final str = err.response!.data as String;
            final redacted = engine.redactBody(str, contentType);
            responsePayload = PayloadTruncator.truncate(
              body: redacted,
              contentType: contentType,
              maxBytes: config.maxBodyBytes,
            );
          } else if (err.response!.data is List<int>) {
            final bytes = err.response!.data as List<int>;
            final truncated = PayloadTruncator.truncateBytes(
              bytes: bytes,
              contentType: contentType,
              maxBytes: config.maxBodyBytes,
            );
            final redacted = engine.redactBody(truncated.body, contentType);
            responsePayload = truncated.copyWith(body: redacted);
          } else {
            final str = err.response!.data.toString();
            final redacted = engine.redactBody(str, contentType);
            responsePayload = PayloadTruncator.truncate(
              body: redacted,
              contentType: contentType,
              maxBytes: config.maxBodyBytes,
            );
          }
        }
      }

      final uri = err.requestOptions.uri;
      final failedRecord = (pendingRecord != null)
          ? pendingRecord.copyWith(
              responseStatusCode: err.response?.statusCode,
              responseHeaders: sanitizedResponseHeaders,
              responseBody: responsePayload,
              responseContentType: contentType,
              responseSize: responsePayload?.byteSize ?? 0,
              responseTimestamp: endTimestamp,
              durationMs: durationMs,
              status: NetworkStatus.failed,
              error: errorDetails,
            )
          : NetworkRecord(
              id: id,
              url: engine.redactUrl(uri.toString()),
              baseUrl: '${uri.scheme}://${uri.authority}',
              path: uri.path,
              method: err.requestOptions.method.toUpperCase(),
              requestTimestamp: startTimestamp,
              responseStatusCode: err.response?.statusCode,
              responseHeaders: sanitizedResponseHeaders,
              responseBody: responsePayload,
              responseContentType: contentType,
              responseSize: responsePayload?.byteSize ?? 0,
              responseTimestamp: endTimestamp,
              durationMs: durationMs,
              status: NetworkStatus.failed,
              error: errorDetails,
            );

      unawaited(NetworkInspector.repository?.save(failedRecord));
    }

    handler.next(err);
  }

  bool _isIgnored(Uri uri) {
    final host = uri.host.toLowerCase();
    final config = NetworkInspector.currentConfig;
    if (config.ignoredHosts.any((h) => h.toLowerCase() == host)) {
      return true;
    }
    final fullUrl = uri.toString().toLowerCase();
    if (config.ignoredUrls.any((u) => fullUrl.contains(u.toLowerCase()))) {
      return true;
    }
    return false;
  }
}
