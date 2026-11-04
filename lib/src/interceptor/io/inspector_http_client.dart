import 'dart:async';
import 'dart:io';

import '../../config/network_inspector_config.dart';
import '../../core/network_inspector.dart';
import '../../models/http_error_details.dart';
import '../../models/network_record.dart';
import '../../models/network_status.dart';
import '../../utils/redaction_engine.dart';
import '../../utils/uuid_generator.dart';
import 'inspector_http_client_request.dart';

/// Wraps an underlying [HttpClient] to intercept and proxy all outgoing requests (INTC-01, D-39).
class InspectorHttpClient implements HttpClient {
  final HttpClient _inner;
  final NetworkInspectorConfig _config;

  InspectorHttpClient(this._inner, this._config);

  @override
  Duration get idleTimeout => _inner.idleTimeout;

  @override
  set idleTimeout(Duration value) => _inner.idleTimeout = value;

  @override
  Duration? get connectionTimeout => _inner.connectionTimeout;

  @override
  set connectionTimeout(Duration? value) => _inner.connectionTimeout = value;

  @override
  int? get maxConnectionsPerHost => _inner.maxConnectionsPerHost;

  @override
  set maxConnectionsPerHost(int? value) => _inner.maxConnectionsPerHost = value;

  @override
  bool get autoUncompress => _inner.autoUncompress;

  @override
  set autoUncompress(bool value) => _inner.autoUncompress = value;

  @override
  String? get userAgent => _inner.userAgent;

  @override
  set userAgent(String? value) => _inner.userAgent = value;

  @override
  set badCertificateCallback(
          bool Function(X509Certificate cert, String host, int port)?
              callback) =>
      _inner.badCertificateCallback = callback;

  @override
  set authenticate(
          Future<bool> Function(Uri url, String scheme, String? realm)? f) =>
      _inner.authenticate = f;

  @override
  set authenticateProxy(
          Future<bool> Function(
                  String host, int port, String scheme, String? realm)?
              f) =>
      _inner.authenticateProxy = f;

  @override
  set findProxy(String Function(Uri url)? f) => _inner.findProxy = f;

  @override
  set connectionFactory(
          Future<ConnectionTask<Socket>> Function(
                  Uri url, String? proxyHost, int? proxyPort)?
              f) =>
      _inner.connectionFactory = f;

  @override
  set keyLog(void Function(String line)? callback) => _inner.keyLog = callback;

  @override
  void addCredentials(
          Uri url, String realm, HttpClientCredentials credentials) =>
      _inner.addCredentials(url, realm, credentials);

  @override
  void addProxyCredentials(String host, int port, String realm,
          HttpClientCredentials credentials) =>
      _inner.addProxyCredentials(host, port, realm, credentials);

  @override
  void close({bool force = false}) => _inner.close(force: force);

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

  @override
  Future<HttpClientRequest> open(
      String method, String host, int port, String path) async {
    final startTimestamp = DateTime.now();
    try {
      final request = await _inner.open(method, host, port, path);
      return InspectorHttpClientRequest(request, method, request.uri, _config);
    } catch (e, st) {
      if (NetworkInspector.isEnabled) {
        final scheme = port == 443 ? 'https' : 'http';
        final isDefaultPort = (scheme == 'https' && port == 443) ||
            (scheme == 'http' && port == 80);
        final uri = Uri(
          scheme: scheme,
          host: host,
          port: isDefaultPort ? null : port,
          path: path,
        );
        if (!_isIgnored(uri)) {
          final engine =
              RedactionEngine(customKeys: _config.customRedactionKeys);
          final failedRecord = NetworkRecord(
            id: UuidGenerator.v4(),
            url: engine.redactUrl(uri.toString()),
            baseUrl: '${uri.scheme}://${uri.authority}',
            path: uri.path,
            method: method.toUpperCase(),
            requestQueryParams: engine.redactQueryParams(uri.queryParameters),
            requestTimestamp: startTimestamp,
            durationMs:
                DateTime.now().difference(startTimestamp).inMilliseconds,
            status: NetworkStatus.failed,
            error: HttpErrorDetails(
              errorType: e.runtimeType.toString(),
              message: e.toString(),
              stackTrace: st.toString(),
            ),
          );
          unawaited(NetworkInspector.repository?.save(failedRecord));
        }
      }
      rethrow;
    }
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final startTimestamp = DateTime.now();
    try {
      final request = await _inner.openUrl(method, url);
      return InspectorHttpClientRequest(request, method, url, _config);
    } catch (e, st) {
      if (NetworkInspector.isEnabled && !_isIgnored(url)) {
        final engine = RedactionEngine(customKeys: _config.customRedactionKeys);
        final failedRecord = NetworkRecord(
          id: UuidGenerator.v4(),
          url: engine.redactUrl(url.toString()),
          baseUrl: '${url.scheme}://${url.authority}',
          path: url.path,
          method: method.toUpperCase(),
          requestQueryParams: engine.redactQueryParams(url.queryParameters),
          requestTimestamp: startTimestamp,
          durationMs: DateTime.now().difference(startTimestamp).inMilliseconds,
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
  }

  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      open('GET', host, port, path);

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      open('POST', host, port, path);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      open('PUT', host, port, path);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      open('DELETE', host, port, path);

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      open('PATCH', host, port, path);

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);

  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      open('HEAD', host, port, path);

  @override
  Future<HttpClientRequest> headUrl(Uri url) => openUrl('HEAD', url);
}
