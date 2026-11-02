import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../config/network_inspector_config.dart';
import '../../core/constants.dart';
import '../../core/network_inspector.dart';
import '../../models/http_error_details.dart';
import '../../models/network_record.dart';
import '../../models/network_status.dart';
import '../../models/payload_data.dart';
import '../../utils/body_type_detector.dart';
import '../../utils/payload_truncator.dart';
import '../../utils/redaction_engine.dart';
import '../../utils/uuid_generator.dart';
import 'inspector_http_client_response.dart';

/// Wraps an underlying [HttpClientRequest] to capture outgoing request headers,
/// query parameters, and buffered request payload (INTC-01, D-39).
class InspectorHttpClientRequest implements HttpClientRequest {
  final HttpClientRequest _inner;
  final String _method;
  final Uri _url;
  final NetworkInspectorConfig _config;

  final BytesBuilder _bodyBytes = BytesBuilder(copy: false);
  int _accumulatedBodyBytes = 0;
  int _totalBodyBytes = 0;
  bool _isBodyTruncated = false;
  bool _isSuppressed = false;
  bool _suppressionEvaluated = false;
  String? _transactionId;
  DateTime? _startTimestamp;

  InspectorHttpClientRequest(this._inner, this._method, this._url, this._config);

  bool _isIgnored(Uri uri) {
    final host = uri.host.toLowerCase();
    if (_config.ignoredHosts.any((h) => h.toLowerCase() == host)) {
      return true;
    }
    final fullUrl = uri.toString().toLowerCase();
    if (_config.ignoredUrls.any((u) => fullUrl.contains(u.toLowerCase()))) {
      return true;
    }
    return false;
  }

  void _evaluateSuppression() {
    if (_suppressionEvaluated) return;
    _suppressionEvaluated = true;

    // 1. Blacklist check (INTC-01, D-36)
    if (_isIgnored(_url)) {
      _isSuppressed = true;
    }

    // 2. Deduplication check: look for synthetic tracking headers (INTC-06, D-33)
    const trackingHeader = NetworkInspectorConstants.internalTrackingHeader;
    const publicHeader = NetworkInspectorConstants.headerInspectorId;
    bool hasTrackingId = false;
    final headersToRemove = <String>[];
    try {
      _inner.headers.forEach((name, values) {
        final lower = name.toLowerCase();
        if (lower == trackingHeader.toLowerCase() || lower == publicHeader.toLowerCase()) {
          hasTrackingId = true;
          headersToRemove.add(name);
        }
      });
      if (!hasTrackingId) {
        hasTrackingId = _inner.headers[trackingHeader] != null ||
            _inner.headers[publicHeader] != null;
      }

      if (hasTrackingId) {
        _isSuppressed = true;
        // Strip synthetic headers before wire transmission so server never sees them
        _inner.headers.removeAll(trackingHeader);
        _inner.headers.removeAll(publicHeader);
        for (final h in headersToRemove) {
          _inner.headers.removeAll(h);
        }
      }
    } catch (_) {
      // Defensive in case headers cannot be mutated
    }
  }

  void _bufferChunk(List<int> chunk) {
    if (_isSuppressed) return;
    _totalBodyBytes += chunk.length;
    if (_accumulatedBodyBytes < _config.maxBodyBytes) {
      final remaining = _config.maxBodyBytes - _accumulatedBodyBytes;
      if (chunk.length <= remaining) {
        _bodyBytes.add(chunk);
        _accumulatedBodyBytes += chunk.length;
      } else {
        _bodyBytes.add(chunk.sublist(0, remaining));
        _accumulatedBodyBytes += remaining;
        _isBodyTruncated = true;
      }
    } else {
      _isBodyTruncated = true;
    }
  }

  @override
  void add(List<int> data) {
    _evaluateSuppression();
    _bufferChunk(data);
    _inner.add(data);
  }

  @override
  void write(Object? object) {
    _evaluateSuppression();
    if (object != null && !_isSuppressed) {
      final str = object.toString();
      _bufferChunk(encoding.encode(str));
    }
    _inner.write(object);
  }

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) {
    _evaluateSuppression();
    if (!_isSuppressed) {
      final str = objects.join(separator);
      _bufferChunk(encoding.encode(str));
    }
    _inner.writeAll(objects, separator);
  }

  @override
  void writeln([Object? object = '']) {
    _evaluateSuppression();
    if (!_isSuppressed) {
      final str = '${object ?? ""}\n';
      _bufferChunk(encoding.encode(str));
    }
    _inner.writeln(object);
  }

  @override
  void writeCharCode(int charCode) {
    _evaluateSuppression();
    if (!_isSuppressed) {
      _bufferChunk(encoding.encode(String.fromCharCode(charCode)));
    }
    _inner.writeCharCode(charCode);
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    _evaluateSuppression();
    if (_isSuppressed) {
      return _inner.addStream(stream);
    }
    await for (final chunk in stream) {
      add(chunk);
    }
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _inner.addError(error, stackTrace);
  }

  @override
  Future<void> flush() => _inner.flush();

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {
    _evaluateSuppression();
    if (!_isSuppressed && NetworkInspector.isEnabled) {
      final engine = RedactionEngine(customKeys: _config.customRedactionKeys);
      final rawHeaders = <String, String>{};
      try {
        _inner.headers.forEach((name, values) {
          rawHeaders[name] = values.join(', ');
        });
      } catch (_) {}
      final sanitizedHeaders =
          engine.redactHeaders(rawHeaders).map((k, v) => MapEntry(k, v.toString()));
      final sanitizedQueryParams = engine.redactQueryParams(_url.queryParameters);

      PayloadData? requestPayload;
      String? contentType;
      try {
        contentType = _inner.headers.contentType?.mimeType;
      } catch (_) {}

      if (_bodyBytes.isNotEmpty) {
        final decodedText = utf8.decode(_bodyBytes.toBytes(), allowMalformed: true);
        final finalBody = _isBodyTruncated
            ? '$decodedText${PayloadTruncator.formatTruncationBanner(_config.maxBodyBytes)}'
            : decodedText;
        final redactedBody = engine.redactBody(finalBody, contentType);
        requestPayload = PayloadData(
          body: redactedBody,
          byteSize: _totalBodyBytes,
          bodyType: BodyTypeDetector.detect(body: finalBody, contentType: contentType),
          isTruncated: _isBodyTruncated,
        );
      }

      _transactionId ??= UuidGenerator.v4();
      _startTimestamp ??= DateTime.now();
      final duration = DateTime.now().difference(_startTimestamp!);
      final ex = exception ?? const HttpException('Request aborted');

      final failedRecord = NetworkRecord(
        id: _transactionId!,
        url: engine.redactUrl(_url.toString()),
        baseUrl: '${_url.scheme}://${_url.authority}',
        path: _url.path,
        method: _method.toUpperCase(),
        requestHeaders: sanitizedHeaders,
        requestQueryParams: sanitizedQueryParams,
        requestBody: requestPayload,
        requestContentType: contentType,
        requestSize: _totalBodyBytes,
        requestTimestamp: _startTimestamp!,
        durationMs: duration.inMilliseconds,
        status: NetworkStatus.failed,
        error: HttpErrorDetails(
          errorType: ex.runtimeType.toString(),
          message: ex.toString(),
          stackTrace: (stackTrace ?? StackTrace.current).toString(),
        ),
      );
      unawaited(NetworkInspector.repository?.save(failedRecord));
    }
    _inner.abort(exception, stackTrace);
  }

  @override
  Future<HttpClientResponse> close() async {
    _evaluateSuppression();

    PayloadData? requestPayload;
    Map<String, String> sanitizedHeaders = const {};
    Map<String, dynamic> sanitizedQueryParams = const {};
    final engine = RedactionEngine(customKeys: _config.customRedactionKeys);
    String? requestContentType;
    try {
      requestContentType = _inner.headers.contentType?.mimeType;
    } catch (_) {}

    if (!_isSuppressed && NetworkInspector.isEnabled) {
      _transactionId = UuidGenerator.v4();
      _startTimestamp = DateTime.now();

      final rawHeaders = <String, String>{};
      _inner.headers.forEach((name, values) {
        rawHeaders[name] = values.join(', ');
      });
      sanitizedHeaders =
          engine.redactHeaders(rawHeaders).map((k, v) => MapEntry(k, v.toString()));
      sanitizedQueryParams = engine.redactQueryParams(_url.queryParameters);

      if (_bodyBytes.isNotEmpty) {
        final decodedText = utf8.decode(_bodyBytes.toBytes(), allowMalformed: true);
        final finalBody = _isBodyTruncated
            ? '$decodedText${PayloadTruncator.formatTruncationBanner(_config.maxBodyBytes)}'
            : decodedText;
        final redactedBody = engine.redactBody(finalBody, requestContentType);
        requestPayload = PayloadData(
          body: redactedBody,
          byteSize: _totalBodyBytes,
          bodyType: BodyTypeDetector.detect(body: finalBody, contentType: requestContentType),
          isTruncated: _isBodyTruncated,
        );
      }

      final pendingRecord = NetworkRecord(
        id: _transactionId!,
        url: engine.redactUrl(_url.toString()),
        baseUrl: '${_url.scheme}://${_url.authority}',
        path: _url.path,
        method: _method.toUpperCase(),
        requestHeaders: sanitizedHeaders,
        requestQueryParams: sanitizedQueryParams,
        requestBody: requestPayload,
        requestContentType: requestContentType,
        requestSize: _totalBodyBytes,
        requestTimestamp: _startTimestamp!,
        status: NetworkStatus.pending,
      );
      unawaited(NetworkInspector.repository?.save(pendingRecord));
    }

    HttpClientResponse response;
    try {
      response = await _inner.close();
    } catch (e, st) {
      if (!_isSuppressed && _transactionId != null && _startTimestamp != null) {
        final duration = DateTime.now().difference(_startTimestamp!);
        final failedRecord = NetworkRecord(
          id: _transactionId!,
          url: engine.redactUrl(_url.toString()),
          baseUrl: '${_url.scheme}://${_url.authority}',
          path: _url.path,
          method: _method.toUpperCase(),
          requestHeaders: sanitizedHeaders,
          requestQueryParams: sanitizedQueryParams,
          requestBody: requestPayload,
          requestContentType: requestContentType,
          requestSize: _totalBodyBytes,
          requestTimestamp: _startTimestamp!,
          durationMs: duration.inMilliseconds,
          status: NetworkStatus.failed,
          error: HttpErrorDetails(
            errorType: e.runtimeType.toString(),
            message: e.toString(),
            stackTrace: st.toString(),
          ),
        );
        unawaited(NetworkInspector.repository?.save(failedRecord));
      }
      rethrow;
    }

    if (_isSuppressed || !NetworkInspector.isEnabled) {
      return response;
    }

    return InspectorHttpClientResponse(
      response,
      transactionId: _transactionId!,
      startTimestamp: _startTimestamp!,
      config: _config,
      url: _url,
      method: _method,
      requestHeaders: sanitizedHeaders,
      requestQueryParams: sanitizedQueryParams,
      requestPayload: requestPayload,
      requestContentType: requestContentType,
      requestSize: _totalBodyBytes,
    );
  }

  // --- HttpClientRequest Forwarding Getters and Setters (D-39) ---

  @override
  Encoding get encoding => _inner.encoding;

  @override
  set encoding(Encoding value) => _inner.encoding = value;

  @override
  int get contentLength => _inner.contentLength;

  @override
  set contentLength(int value) => _inner.contentLength = value;

  @override
  bool get bufferOutput => _inner.bufferOutput;

  @override
  set bufferOutput(bool value) => _inner.bufferOutput = value;

  @override
  bool get followRedirects => _inner.followRedirects;

  @override
  set followRedirects(bool value) => _inner.followRedirects = value;

  @override
  int get maxRedirects => _inner.maxRedirects;

  @override
  set maxRedirects(int value) => _inner.maxRedirects = value;

  @override
  bool get persistentConnection => _inner.persistentConnection;

  @override
  set persistentConnection(bool value) => _inner.persistentConnection = value;

  @override
  HttpHeaders get headers => _inner.headers;

  @override
  List<Cookie> get cookies => _inner.cookies;

  @override
  Uri get uri => _inner.uri;

  @override
  String get method => _inner.method;

  @override
  HttpConnectionInfo? get connectionInfo => _inner.connectionInfo;

  @override
  Future<HttpClientResponse> get done => _inner.done;
}
