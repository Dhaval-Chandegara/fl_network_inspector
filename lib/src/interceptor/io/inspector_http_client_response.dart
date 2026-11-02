import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../config/network_inspector_config.dart';
import '../../core/network_inspector.dart';
import '../../models/body_type.dart';
import '../../models/http_error_details.dart';
import '../../models/network_record.dart';
import '../../models/network_status.dart';
import '../../models/payload_data.dart';
import '../../utils/body_type_detector.dart';
import '../../utils/payload_truncator.dart';
import '../../utils/redaction_engine.dart';
import '../stream/stream_tap_transformer.dart';

/// Wraps an underlying [HttpClientResponse] to transparently tap response stream bytes
/// without consuming or altering the single-subscription stream for host applications (INTC-01, D-39, D-41).
class InspectorHttpClientResponse extends StreamView<List<int>> implements HttpClientResponse {
  final HttpClientResponse _inner;
  final String transactionId;
  final DateTime startTimestamp;
  final NetworkInspectorConfig config;
  final Uri url;
  final String method;
  final Map<String, String> requestHeaders;
  final Map<String, dynamic> requestQueryParams;
  final PayloadData? requestPayload;
  final String? requestContentType;
  final int requestSize;

  InspectorHttpClientResponse(
    this._inner, {
    required this.transactionId,
    required this.startTimestamp,
    required this.config,
    required this.url,
    required this.method,
    required this.requestHeaders,
    required this.requestQueryParams,
    this.requestPayload,
    this.requestContentType,
    this.requestSize = 0,
  }) : super(
          _inner.transform(
            createStreamTapTransformer(
              maxBodyBytes: config.maxBodyBytes,
              isBinary: _isBinaryMime(_inner.headers.contentType?.mimeType),
              onComplete: (bufferedBytes, isTruncated, totalBytes) {
                _onResponseComplete(
                  inner: _inner,
                  transactionId: transactionId,
                  startTimestamp: startTimestamp,
                  config: config,
                  url: url,
                  method: method,
                  requestHeaders: requestHeaders,
                  requestQueryParams: requestQueryParams,
                  requestPayload: requestPayload,
                  requestContentType: requestContentType,
                  requestSize: requestSize,
                  bufferedBytes: bufferedBytes,
                  isTruncated: isTruncated,
                  totalBytes: totalBytes,
                );
              },
              onError: (error, stackTrace, partialBytes, totalBytes) {
                _onResponseError(
                  inner: _inner,
                  transactionId: transactionId,
                  startTimestamp: startTimestamp,
                  config: config,
                  url: url,
                  method: method,
                  requestHeaders: requestHeaders,
                  requestQueryParams: requestQueryParams,
                  requestPayload: requestPayload,
                  requestContentType: requestContentType,
                  requestSize: requestSize,
                  error: error,
                  stackTrace: stackTrace,
                  partialBytes: partialBytes,
                  totalBytes: totalBytes,
                );
              },
            ),
          ),
        ) {
    // Progressive status updates for SSE / live streams (D-42)
    if (_isProgressiveStream(_inner.headers.contentType?.mimeType)) {
      _saveProgressiveInitialRecord();
    }
  }

  static bool _isBinaryMime(String? mime) {
    if (mime == null) return false;
    final lower = mime.toLowerCase();
    return lower.startsWith('image/') ||
        lower.startsWith('video/') ||
        lower.startsWith('audio/') ||
        lower.contains('application/octet-stream') ||
        lower.contains('application/pdf') ||
        lower.contains('application/zip') ||
        lower.contains('application/gzip');
  }

  static bool _isProgressiveStream(String? mime) {
    if (mime == null) return false;
    final lower = mime.toLowerCase();
    return lower.contains('text/event-stream') || lower.contains('multipart/x-mixed-replace');
  }

  void _saveProgressiveInitialRecord() {
    try {
      final engine = RedactionEngine(customKeys: config.customRedactionKeys);
      final rawHeaders = <String, String>{};
      _inner.headers.forEach((name, values) {
        rawHeaders[name] = values.join(', ');
      });
      final sanitizedResponseHeaders = engine
          .redactHeaders(rawHeaders)
          .map((k, v) => MapEntry(k, v.toString()));

      final initialRecord = NetworkRecord(
        id: transactionId,
        url: engine.redactUrl(url.toString()),
        baseUrl: '${url.scheme}://${url.authority}',
        path: url.path,
        method: method.toUpperCase(),
        responseStatusCode: _inner.statusCode,
        status: NetworkStatus.pending,
        requestHeaders: requestHeaders,
        requestQueryParams: requestQueryParams,
        requestBody: requestPayload,
        requestContentType: requestContentType,
        requestSize: requestSize,
        responseHeaders: sanitizedResponseHeaders,
        requestTimestamp: startTimestamp,
      );
      unawaited(NetworkInspector.repository?.save(initialRecord));
    } catch (_) {
      // Defensive isolation
    }
  }

  static void _onResponseComplete({
    required HttpClientResponse inner,
    required String transactionId,
    required DateTime startTimestamp,
    required NetworkInspectorConfig config,
    required Uri url,
    required String method,
    required Map<String, String> requestHeaders,
    required Map<String, dynamic> requestQueryParams,
    required PayloadData? requestPayload,
    required String? requestContentType,
    required int requestSize,
    required List<int> bufferedBytes,
    required bool isTruncated,
    required int totalBytes,
  }) {
    try {
      final duration = DateTime.now().difference(startTimestamp);
      final engine = RedactionEngine(customKeys: config.customRedactionKeys);
      final rawHeaders = <String, String>{};
      inner.headers.forEach((name, values) {
        rawHeaders[name] = values.join(', ');
      });
      final sanitizedResponseHeaders = engine
          .redactHeaders(rawHeaders)
          .map((k, v) => MapEntry(k, v.toString()));

      final contentType = inner.headers.contentType?.mimeType;
      PayloadData responsePayload;

      if (_isBinaryMime(contentType)) {
        // Binary stream bypass (D-43)
        final summary = PayloadTruncator.formatBinarySummary(
          contentType ?? 'application/octet-stream',
          totalBytes,
        );
        responsePayload = PayloadData(
          body: summary,
          byteSize: totalBytes,
          bodyType: BodyType.binary,
          isTruncated: false,
        );
      } else {
        final decodedText = utf8.decode(bufferedBytes, allowMalformed: true);
        final finalBody = isTruncated
            ? '$decodedText${PayloadTruncator.formatTruncationBanner(config.maxBodyBytes)}'
            : decodedText;
        final redactedBody = engine.redactBody(finalBody, contentType);
        responsePayload = PayloadData(
          body: redactedBody,
          byteSize: totalBytes,
          bodyType: BodyTypeDetector.detect(body: finalBody, contentType: contentType),
          isTruncated: isTruncated,
        );
      }

      final record = NetworkRecord(
        id: transactionId,
        url: engine.redactUrl(url.toString()),
        baseUrl: '${url.scheme}://${url.authority}',
        path: url.path,
        method: method.toUpperCase(),
        responseStatusCode: inner.statusCode,
        status: NetworkStatus.success,
        requestHeaders: requestHeaders,
        requestQueryParams: requestQueryParams,
        requestBody: requestPayload,
        requestContentType: requestContentType,
        requestSize: requestSize,
        responseHeaders: sanitizedResponseHeaders,
        responseBody: responsePayload,
        responseContentType: contentType,
        responseSize: totalBytes,
        responseTimestamp: DateTime.now(),
        requestTimestamp: startTimestamp,
        durationMs: duration.inMilliseconds,
      );

      unawaited(NetworkInspector.repository?.save(record));
    } catch (_) {
      // Defensive isolation
    }
  }

  static void _onResponseError({
    required HttpClientResponse inner,
    required String transactionId,
    required DateTime startTimestamp,
    required NetworkInspectorConfig config,
    required Uri url,
    required String method,
    required Map<String, String> requestHeaders,
    required Map<String, dynamic> requestQueryParams,
    required PayloadData? requestPayload,
    required String? requestContentType,
    required int requestSize,
    required Object error,
    required StackTrace stackTrace,
    required List<int> partialBytes,
    required int totalBytes,
  }) {
    try {
      final duration = DateTime.now().difference(startTimestamp);
      final engine = RedactionEngine(customKeys: config.customRedactionKeys);
      final rawHeaders = <String, String>{};
      try {
        inner.headers.forEach((name, values) {
          rawHeaders[name] = values.join(', ');
        });
      } catch (_) {}
      final sanitizedResponseHeaders = engine
          .redactHeaders(rawHeaders)
          .map((k, v) => MapEntry(k, v.toString()));

      int? statusCode;
      try {
        statusCode = inner.statusCode;
      } catch (_) {}

      String? contentType;
      try {
        contentType = inner.headers.contentType?.mimeType;
      } catch (_) {}

      PayloadData? responsePayload;
      if (_isBinaryMime(contentType)) {
        if (totalBytes > 0) {
          final summary = PayloadTruncator.formatBinarySummary(
            contentType ?? 'application/octet-stream',
            totalBytes,
          );
          responsePayload = PayloadData(
            body: summary,
            byteSize: totalBytes,
            bodyType: BodyType.binary,
            isTruncated: false,
          );
        }
      } else if (partialBytes.isNotEmpty) {
        final isPartialTruncated = partialBytes.length < totalBytes;
        final decodedText = utf8.decode(partialBytes, allowMalformed: true);
        final finalBody = isPartialTruncated
            ? '$decodedText${PayloadTruncator.formatTruncationBanner(config.maxBodyBytes)}'
            : decodedText;
        final redactedBody = engine.redactBody(finalBody, contentType);
        responsePayload = PayloadData(
          body: redactedBody,
          byteSize: totalBytes,
          bodyType: BodyTypeDetector.detect(body: finalBody, contentType: contentType),
          isTruncated: isPartialTruncated,
        );
      }

      final record = NetworkRecord(
        id: transactionId,
        url: engine.redactUrl(url.toString()),
        baseUrl: '${url.scheme}://${url.authority}',
        path: url.path,
        method: method.toUpperCase(),
        responseStatusCode: statusCode,
        status: NetworkStatus.failed,
        requestHeaders: requestHeaders,
        requestQueryParams: requestQueryParams,
        requestBody: requestPayload,
        requestContentType: requestContentType,
        requestSize: requestSize,
        responseHeaders: sanitizedResponseHeaders,
        responseBody: responsePayload,
        responseContentType: responsePayload != null ? contentType : null,
        responseSize: totalBytes,
        responseTimestamp: DateTime.now(),
        requestTimestamp: startTimestamp,
        durationMs: duration.inMilliseconds,
        error: HttpErrorDetails(
          errorType: error.runtimeType.toString(),
          message: error.toString(),
          stackTrace: stackTrace.toString(),
          statusCode: statusCode,
        ),
      );

      unawaited(NetworkInspector.repository?.save(record));
    } catch (_) {
      // Defensive isolation
    }
  }

  // --- HttpClientResponse Forwarding Getters and Methods (D-39) ---

  @override
  int get statusCode => _inner.statusCode;

  @override
  String get reasonPhrase => _inner.reasonPhrase;

  @override
  int get contentLength => _inner.contentLength;

  @override
  HttpClientResponseCompressionState get compressionState => _inner.compressionState;

  @override
  HttpHeaders get headers => _inner.headers;

  @override
  List<Cookie> get cookies => _inner.cookies;

  @override
  bool get isRedirect => _inner.isRedirect;

  @override
  List<RedirectInfo> get redirects => _inner.redirects;

  @override
  bool get persistentConnection => _inner.persistentConnection;

  @override
  Future<HttpClientResponse> redirect([String? method, Uri? url, bool? followLoops]) =>
      _inner.redirect(method, url, followLoops);

  @override
  Future<Socket> detachSocket() => _inner.detachSocket();

  @override
  X509Certificate? get certificate => _inner.certificate;

  @override
  HttpConnectionInfo? get connectionInfo => _inner.connectionInfo;
}
