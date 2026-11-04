import 'dart:convert';
import 'dart:io';

import 'package:fl_network_inspector/fl_network_inspector.dart';
import 'package:fl_network_inspector/src/interceptor/io/inspector_http_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InspectorHttpClient Interceptor (INTC-01, INTC-03, D-39, D-41)', () {
    late HttpServer server;
    late InMemoryNetworkInspectorRepository repository;

    setUp(() async {
      repository = InMemoryNetworkInspectorRepository(maxRecords: 100);
      await NetworkInspector.initialize(
        config: const NetworkInspectorConfig(enabled: true),
        repository: repository,
      );

      // Spin up local loopback HTTP server
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest request) async {
        if (request.uri.path == '/hello') {
          request.response.headers.contentType = ContentType.json;
          request.response.statusCode = HttpStatus.ok;
          request.response.write(jsonEncode({'message': 'world', 'status': 'success'}));
          await request.response.close();
        } else if (request.uri.path == '/echo') {
          final requestBody = await utf8.decoder.bind(request).join();
          request.response.headers.contentType = ContentType.json;
          request.response.statusCode = HttpStatus.created;
          request.response.write(jsonEncode({'echoed': requestBody}));
          await request.response.close();
        } else if (request.uri.path == '/image.png') {
          request.response.headers.contentType = ContentType('image', 'png');
          request.response.statusCode = HttpStatus.ok;
          request.response.add(List.generate(200, (i) => i % 256));
          await request.response.close();
        } else if (request.uri.path == '/events') {
          request.response.headers.contentType = ContentType('text', 'event-stream');
          request.response.statusCode = HttpStatus.ok;
          request.response.write('event: ping\ndata: 123\n\n');
          await Future<void>.delayed(const Duration(milliseconds: 150));
          await request.response.close();
        } else if (request.uri.path == '/analytics/ping') {
          request.response.statusCode = HttpStatus.ok;
          request.response.write('OK');
          await request.response.close();
        } else if (request.uri.path == '/error') {
          request.response.statusCode = HttpStatus.internalServerError;
          request.response.write('Internal Server Error');
          await request.response.close();
        } else {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        }
      });
    });

    tearDown(() async {
      await server.close(force: true);
      NetworkInspector.resetForTesting();
    });

    test('intercepts GET request and permits single-subscription stream consumption without error',
        () async {
      final nativeClient = HttpClient();
      final client = InspectorHttpClient(nativeClient, NetworkInspector.currentConfig);

      final url = Uri.parse('http://${server.address.host}:${server.port}/hello?query=test');
      final request = await client.getUrl(url);
      request.headers.add('x-custom-test-header', 'test-value');

      final response = await request.close();

      expect(response.statusCode, equals(HttpStatus.ok));

      // Host application consumes single-subscription response stream
      final responseBody = await response.transform(utf8.decoder).join();
      expect(responseBody, contains('"message":"world"'));

      client.close();

      // Wait briefly for unawaited repository write
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final records = await repository.getRecords();
      expect(records, isNotEmpty);

      final record = records.first;
      expect(record.url, contains('/hello'));
      expect(record.method, equals('GET'));
      expect(record.responseStatusCode, equals(200));
      expect(record.status, equals(NetworkStatus.success));
      expect(record.responseBody?.body, contains('"message":"world"'));
      expect(record.requestHeaders['x-custom-test-header'], equals('test-value'));
      expect(record.durationMs, isNotNull);
      expect(record.durationMs! >= 0, isTrue);
    });

    test('intercepts POST request with body and stores request and response payloads', () async {
      final nativeClient = HttpClient();
      final client = InspectorHttpClient(nativeClient, NetworkInspector.currentConfig);

      final url = Uri.parse('http://${server.address.host}:${server.port}/echo');
      final request = await client.postUrl(url);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'input': 'sample payload'}));

      final response = await request.close();
      expect(response.statusCode, equals(HttpStatus.created));

      final responseBody = await response.transform(utf8.decoder).join();
      expect(responseBody, contains('sample payload'));

      client.close();

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final records = await repository.getRecords();
      expect(records, isNotEmpty);

      final record = records.first;
      expect(record.method, equals('POST'));
      expect(record.responseStatusCode, equals(201));
      expect(record.status, equals(NetworkStatus.success));
      expect(record.requestBody?.body, contains('sample payload'));
      expect(record.responseBody?.body, contains('sample payload'));
    });

    test('captures connection/socket failure with NetworkStatus.failed (D-44)', () async {
      final nativeClient = HttpClient();
      final client = InspectorHttpClient(nativeClient, NetworkInspector.currentConfig);

      // Unused port that will fail connection immediately
      final deadUrl = Uri.parse('http://${InternetAddress.loopbackIPv4.address}:1/dead');

      try {
        final request = await client.getUrl(deadUrl);
        await request.close();
        fail('Should have thrown SocketException');
      } catch (e) {
        expect(e, isA<SocketException>());
      } finally {
        client.close();
      }

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final records = await repository.getRecords();
      expect(records, isNotEmpty);

      final record = records.first;
      expect(record.status, equals(NetworkStatus.failed));
      expect(record.error, isNotNull);
      expect(record.error?.errorType, contains('SocketException'));
    });

    test('does not save records when NetworkInspector is disabled (D-03)', () async {
      NetworkInspector.resetForTesting();
      await NetworkInspector.initialize(
        config: const NetworkInspectorConfig(enabled: false),
        repository: repository,
      );

      final nativeClient = HttpClient();
      final client = InspectorHttpClient(nativeClient, NetworkInspector.currentConfig);

      final url = Uri.parse('http://${server.address.host}:${server.port}/hello');
      final request = await client.getUrl(url);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      expect(body, contains('"message":"world"'));

      client.close();

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final records = await repository.getRecords();
      expect(records, isEmpty);
    });

    test('bypasses capture for blacklisted hosts and URLs (D-36)', () async {
      NetworkInspector.resetForTesting();
      await NetworkInspector.initialize(
        config: NetworkInspectorConfig(
          enabled: true,
          ignoredHosts: [server.address.host],
          ignoredUrls: const ['/analytics'],
        ),
        repository: repository,
      );

      final nativeClient = HttpClient();
      final client = InspectorHttpClient(nativeClient, NetworkInspector.currentConfig);

      // 1. Request matching ignoredUrls
      final analyticsUrl = Uri.parse('http://${server.address.host}:${server.port}/analytics/ping');
      final req1 = await client.getUrl(analyticsUrl);
      final res1 = await req1.close();
      final body1 = await res1.transform(utf8.decoder).join();
      expect(body1, equals('OK'));

      client.close();

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Repository must receive ZERO records
      final records = await repository.getRecords();
      expect(records, isEmpty);
    });

    test('binary response streams bypass byte buffer memory and record summary (D-43)', () async {
      final nativeClient = HttpClient();
      final client = InspectorHttpClient(nativeClient, NetworkInspector.currentConfig);

      final imageUrl = Uri.parse('http://${server.address.host}:${server.port}/image.png');
      final request = await client.getUrl(imageUrl);
      final response = await request.close();

      // Host application consumes all binary bytes
      final bytes = await response.fold<List<int>>([], (prev, elem) => prev..addAll(elem));
      expect(bytes.length, equals(200));

      client.close();

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final records = await repository.getRecords();
      expect(records, isNotEmpty);

      final record = records.first;
      expect(record.responseStatusCode, equals(200));
      expect(record.responseSize, equals(200));
      expect(record.responseBody?.bodyType, equals(BodyType.binary));
      expect(record.responseBody?.body, equals('[Binary data: image/png, 200 bytes]'));
    });

    test('Server-Sent Events (SSE) record headers and status immediately upon arrival (D-42)', () async {
      final nativeClient = HttpClient();
      final client = InspectorHttpClient(nativeClient, NetworkInspector.currentConfig);

      final sseUrl = Uri.parse('http://${server.address.host}:${server.port}/events');
      final request = await client.getUrl(sseUrl);
      final response = await request.close();

      // Immediately after close() returns the response stream,
      // before the stream completes, check repository
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final initialRecords = await repository.getRecords();
      expect(initialRecords, isNotEmpty, reason: 'SSE headers and status should be recorded immediately');
      final pendingRecord = initialRecords.first;
      expect(pendingRecord.responseStatusCode, equals(200));
      expect(pendingRecord.responseHeaders?['content-type'], contains('text/event-stream'));

      // Now drain the stream
      final events = await response.transform(utf8.decoder).join();
      expect(events, contains('event: ping'));

      client.close();

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final finalRecords = await repository.getRecords();
      expect(finalRecords.first.status, equals(NetworkStatus.success));
    });
  });
}
