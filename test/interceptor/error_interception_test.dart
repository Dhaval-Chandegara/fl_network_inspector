import 'dart:convert';
import 'dart:io';

import 'package:fl_network_inspector/fl_network_inspector.dart';
import 'package:fl_network_inspector/src/interceptor/io/inspector_http_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Error & Abort Interception (INTC-07, D-44)', () {
    late HttpServer server;
    late ServerSocket rawCrashServer;
    late InMemoryNetworkInspectorRepository repository;

    setUp(() async {
      repository = InMemoryNetworkInspectorRepository(maxRecords: 100);
      await NetworkInspector.initialize(
        config: const NetworkInspectorConfig(enabled: true),
        repository: repository,
      );

      // Standard HTTP server for standard routes
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest request) async {
        if (request.uri.path == '/slow') {
          await Future<void>.delayed(const Duration(seconds: 10));
          request.response.statusCode = HttpStatus.ok;
          await request.response.close();
        } else {
          request.response.statusCode = HttpStatus.ok;
          request.response.write('OK');
          await request.response.close();
        }
      });

      // Raw TCP server that simulates abrupt mid-stream disconnects
      rawCrashServer = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      rawCrashServer.listen((Socket socket) {
        socket.listen((data) async {
          final text = utf8.decode(data, allowMalformed: true);
          if (text.contains('/partial-crash')) {
            socket.write('HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nTransfer-Encoding: chunked\r\n\r\n');
            socket.write('2c\r\n{"status": "in_progress", "partial_data": [1, 2, 3]}\r\n');
            await socket.flush();
            await Future<void>.delayed(const Duration(milliseconds: 30));
            socket.destroy();
          } else if (text.contains('/partial-binary')) {
            socket.write('HTTP/1.1 200 OK\r\nContent-Type: image/png\r\nContent-Length: 1000\r\n\r\n');
            socket.add(List.generate(100, (i) => i % 256));
            await socket.flush();
            await Future<void>.delayed(const Duration(milliseconds: 30));
            socket.destroy();
          }
        });
      });
    });

    tearDown(() async {
      await server.close(force: true);
      await rawCrashServer.close();
      NetworkInspector.resetForTesting();
    });

    test('captures connection/socket failures to unrouted ports and rethrows', () async {
      final nativeClient = HttpClient();
      final client = InspectorHttpClient(nativeClient, NetworkInspector.currentConfig);

      // Unused port that will fail connection immediately
      final deadUrl = Uri.parse('http://${InternetAddress.loopbackIPv4.address}:1/dead');

      Object? thrownError;
      try {
        final request = await client.getUrl(deadUrl);
        await request.close();
      } catch (e) {
        thrownError = e;
      } finally {
        client.close();
      }

      expect(thrownError, isNotNull);
      expect(thrownError, isA<SocketException>());

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final records = await repository.getRecords();
      expect(records, isNotEmpty);

      final record = records.first;
      expect(record.status, equals(NetworkStatus.failed));
      expect(record.error, isNotNull);
      expect(record.error!.errorType, contains('SocketException'));
      expect(record.error!.message, isNotEmpty);
      expect(record.durationMs, isNotNull);
      expect(record.durationMs, greaterThanOrEqualTo(0));
    });

    test('captures request.abort() with NetworkStatus.failed and HttpErrorDetails', () async {
      final nativeClient = HttpClient();
      final client = InspectorHttpClient(nativeClient, NetworkInspector.currentConfig);
      final url = Uri.parse('http://${server.address.address}:${server.port}/slow');

      try {
        final request = await client.postUrl(url);
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode({'payload': 'will_abort'}));

        // Abort the request explicitly
        request.abort(const SocketException('Client aborted connection'));
      } finally {
        client.close(force: true);
      }

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final records = await repository.getRecords();
      expect(records, isNotEmpty);

      final record = records.first;
      expect(record.status, equals(NetworkStatus.failed));
      expect(record.error, isNotNull);
      expect(record.error!.message, contains('Client aborted connection'));
      expect(record.error!.errorType, contains('SocketException'));
      expect(record.requestBody?.body, contains('will_abort'));
    });

    test('retains partial response body when mid-stream error occurs (D-44)', () async {
      final nativeClient = HttpClient();
      final client = InspectorHttpClient(nativeClient, NetworkInspector.currentConfig);
      final url = Uri.parse('http://${rawCrashServer.address.address}:${rawCrashServer.port}/partial-crash');

      Object? streamError;
      try {
        final request = await client.getUrl(url);
        final response = await request.close();

        expect(response.statusCode, equals(HttpStatus.ok));

        // Consume response stream which will fail mid-stream due to socket.destroy()
        await response.toList();
      } catch (e) {
        streamError = e;
      } finally {
        client.close(force: true);
      }

      // Ensure error was not swallowed and forwarded downstream to caller
      expect(streamError, isNotNull);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final records = await repository.getRecords();
      expect(records, isNotEmpty);

      final record = records.first;
      expect(record.status, equals(NetworkStatus.failed));
      expect(record.responseStatusCode, equals(200));
      expect(record.error, isNotNull);
      expect(record.error!.message, isNotEmpty);
      expect(record.error!.statusCode, equals(200));

      // Partial body must be retained!
      expect(record.responseBody, isNotNull);
      expect(record.responseBody!.body, contains('partial_data'));
      expect(record.responseBody!.byteSize, greaterThan(0));
    });

    test('retains binary response summary when mid-stream error occurs on binary stream (D-43, D-44)', () async {
      final nativeClient = HttpClient();
      final client = InspectorHttpClient(nativeClient, NetworkInspector.currentConfig);
      final url = Uri.parse('http://${rawCrashServer.address.address}:${rawCrashServer.port}/partial-binary');

      Object? streamError;
      try {
        final request = await client.getUrl(url);
        final response = await request.close();

        expect(response.statusCode, equals(HttpStatus.ok));

        // Consume binary response stream which will fail mid-stream
        await response.toList();
      } catch (e) {
        streamError = e;
      } finally {
        client.close(force: true);
      }

      expect(streamError, isNotNull);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final records = await repository.getRecords();
      expect(records, isNotEmpty);

      final record = records.first;
      expect(record.status, equals(NetworkStatus.failed));
      expect(record.responseStatusCode, equals(200));
      expect(record.error, isNotNull);
      expect(record.responseBody, isNotNull);
      expect(record.responseBody!.bodyType, equals(BodyType.binary));
      expect(record.responseBody!.body, contains('Binary data'));
      expect(record.responseBody!.body, contains('image/png'));
    });

    test('suppresses error logging when synthetic tracking header is present (INTC-06)', () async {
      final client = HttpClient();
      final url = Uri.parse('http://${rawCrashServer.address.address}:${rawCrashServer.port}/partial-crash');

      try {
        final request = await client.getUrl(url);
        request.headers.add(NetworkInspectorConstants.headerInspectorId, 'existing-uuid-1234');
        final response = await request.close();
        await response.toList();
      } catch (_) {
        // Expected mid-stream failure
      } finally {
        client.close(force: true);
      }

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final records = await repository.getRecords();
      // Suppressed request should not create a record in low-level HttpClient
      expect(records, isEmpty);
    });
  });
}
