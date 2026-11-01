import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

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
import '../stream/stream_tap_transformer.dart';

/// Dedicated client adapter subclassing [http.BaseClient] from `package:http` (INTC-05).
///
/// Transparently intercepts HTTP calls, injects synthetic deduplication headers (D-33),
/// guards against repeat registrations (D-34), extracts multipart metadata (DATA-04),
/// and taps single-subscription response streams non-destructively (INTC-03, D-41).
class NetworkInspectorHttpClient extends http.BaseClient {
  final http.Client _inner;

  NetworkInspectorHttpClient([http.Client? inner]) : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!NetworkInspector.isEnabled) {
      return _inner.send(request);
    }

    // D-34: Guard against repeat capture from nested or repeated wrappers
    if (request.headers.containsKey(NetworkInspectorConstants.headerInspectorId) ||
        request.headers.containsKey(NetworkInspectorConstants.internalTrackingHeader)) {
      return _inner.send(request);
    }

    // D-36: Host and URL blacklist check
    if (_isIgnored(request.url)) {
      return _inner.send(request);
    }

    final id = UuidGenerator.v4();
    final startTimestamp = DateTime.now();

    // D-33: Inject synthetic tracking headers for low-level HttpOverrides deduplication
    request.headers[NetworkInspectorConstants.headerInspectorId] = id;
    request.headers[NetworkInspectorConstants.internalTrackingHeader] = id;

    final config = NetworkInspector.currentConfig;
    final engine = RedactionEngine(customKeys: config.customRedactionKeys);

    final sanitizedHeaders = engine.redactHeaders(Map<String, dynamic>.from(request.headers));
    final sanitizedQueryParams = engine.redactQueryParams(request.url.queryParameters);
    final sanitizedUrl = engine.redactUrl(request.url.toString());

    PayloadData? requestPayload;
    List<MultipartEntry>? multipartEntries;
    int requestSize = 0;
    final requestContentType = request.headers['content-type'];

    if (request is http.MultipartRequest) {
      final entries = <MultipartEntry>[];
      int totalBytes = 0;

      for (final entry in request.fields.entries) {
        final fieldBytes = utf8.encode(entry.value).length;
        totalBytes += fieldBytes;
        entries.add(
          MultipartEntry(
            fieldName: entry.key,
            contentType: 'text/plain',
            byteSize: fieldBytes,
          ),
        );
      }

      for (final file in request.files) {
        totalBytes += file.length;
        entries.add(
          MultipartEntry(
            fieldName: file.field,
            fileName: file.filename,
            contentType: file.contentType.mimeType,
            byteSize: file.length,
            filePath: config.includeMultipartFilePaths ? null : null,
          ),
        );
      }

      multipartEntries = entries;
      requestSize = totalBytes;
      requestPayload = PayloadData(
        body:
            '[MultipartFormData: ${request.fields.length} fields, ${request.files.length} files]',
        byteSize: totalBytes,
        bodyType: BodyType.formData,
        isTruncated: false,
      );
    } else if (request is http.Request) {
      if (request.bodyBytes.isNotEmpty) {
        final truncated = PayloadTruncator.truncateBytes(
          bytes: request.bodyBytes,
          contentType: requestContentType,
          maxBytes: config.maxBodyBytes,
        );
        final redacted = engine.redactBody(truncated.body, requestContentType);
        requestPayload = truncated.copyWith(body: redacted);
        requestSize = requestPayload.byteSize;
      }
    } else if (request is http.StreamedRequest) {
      final length = request.contentLength ?? 0;
      requestPayload = PayloadData(
        body: '[StreamedRequest: $length bytes]',
        byteSize: length,
        bodyType: BodyType.binary,
        isTruncated: false,
      );
      requestSize = length;
    }

    final pendingRecord = NetworkRecord(
      id: id,
      url: sanitizedUrl,
      baseUrl: '${request.url.scheme}://${request.url.authority}',
      path: request.url.path,
      method: request.method.toUpperCase(),
      requestHeaders: sanitizedHeaders,
      requestQueryParams: sanitizedQueryParams,
      requestBody: requestPayload,
      requestContentType: requestContentType,
      requestSize: requestSize,
      requestTimestamp: startTimestamp,
      multipartEntries: multipartEntries,
      status: NetworkStatus.pending,
    );
    unawaited(NetworkInspector.repository?.save(pendingRecord));

    http.StreamedResponse response;
    try {
      response = await _inner.send(request);
    } catch (e, st) {
      final errorTimestamp = DateTime.now();
      final durationMs = errorTimestamp.difference(startTimestamp).inMilliseconds;
      final errorDetails = HttpErrorDetails(
        message: e.toString(),
        errorType: e.runtimeType.toString(),
        stackTrace: st.toString(),
      );
      final failedRecord = pendingRecord.copyWith(
        responseTimestamp: errorTimestamp,
        durationMs: durationMs,
        status: NetworkStatus.failed,
        error: errorDetails,
      );
      unawaited(NetworkInspector.repository?.save(failedRecord));
      rethrow;
    }

    // Non-destructive stream tapping (INTC-03, D-41, D-43)
    final responseContentType = response.headers['content-type'];
    final isBinary = _isBinary(responseContentType);

    final tappedStream = response.stream.transform(
      createStreamTapTransformer(
        maxBodyBytes: config.maxBodyBytes,
        isBinary: isBinary,
        onComplete: (bufferedBytes, isTruncated, totalBytes) {
          final endTimestamp = DateTime.now();
          final durationMs = endTimestamp.difference(startTimestamp).inMilliseconds;
          final rawHeaders = <String, dynamic>{};
          response.headers.forEach((k, v) => rawHeaders[k] = v);
          final sanitizedResponseHeaders = engine.redactHeaders(rawHeaders);

          PayloadData? responsePayload;
          if (isBinary) {
            responsePayload = PayloadData(
              body: PayloadTruncator.formatBinarySummary(
                responseContentType ?? 'application/octet-stream',
                totalBytes,
              ),
              byteSize: totalBytes,
              bodyType: BodyType.binary,
              isTruncated: false,
            );
          } else if (bufferedBytes.isNotEmpty) {
            final truncated = PayloadTruncator.truncateBytes(
              bytes: bufferedBytes,
              contentType: responseContentType,
              maxBytes: config.maxBodyBytes,
            );
            final redacted = engine.redactBody(truncated.body, responseContentType);
            responsePayload = truncated.copyWith(
              body: redacted,
              isTruncated: isTruncated || truncated.isTruncated,
            );
          }

          final completedRecord = pendingRecord.copyWith(
            responseStatusCode: response.statusCode,
            responseHeaders: sanitizedResponseHeaders,
            responseBody: responsePayload,
            responseContentType: responseContentType,
            responseSize: responsePayload?.byteSize ?? totalBytes,
            responseTimestamp: endTimestamp,
            durationMs: durationMs,
            status: NetworkStatus.success,
          );
          unawaited(NetworkInspector.repository?.save(completedRecord));
        },
        onError: (error, stackTrace, partialBytes, totalBytes) {
          final endTimestamp = DateTime.now();
          final durationMs = endTimestamp.difference(startTimestamp).inMilliseconds;
          final rawHeaders = <String, dynamic>{};
          response.headers.forEach((k, v) => rawHeaders[k] = v);
          final sanitizedResponseHeaders = engine.redactHeaders(rawHeaders);

          final errorDetails = HttpErrorDetails(
            message: error.toString(),
            errorType: error.runtimeType.toString(),
            stackTrace: stackTrace.toString(),
            statusCode: response.statusCode,
          );

          final failedRecord = pendingRecord.copyWith(
            responseStatusCode: response.statusCode,
            responseHeaders: sanitizedResponseHeaders,
            responseContentType: responseContentType,
            responseSize: totalBytes,
            responseTimestamp: endTimestamp,
            durationMs: durationMs,
            status: NetworkStatus.failed,
            error: errorDetails,
          );
          unawaited(NetworkInspector.repository?.save(failedRecord));
        },
      ),
    );

    return http.StreamedResponse(
      http.ByteStream(tappedStream),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() {
    _inner.close();
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

  bool _isBinary(String? contentType) {
    if (contentType == null) return false;
    final lower = contentType.toLowerCase();
    return lower.startsWith('image/') ||
        lower.startsWith('video/') ||
        lower.startsWith('audio/') ||
        lower.contains('application/octet-stream') ||
        lower.contains('application/pdf') ||
        lower.contains('application/zip') ||
        lower.contains('application/gzip');
  }
}
