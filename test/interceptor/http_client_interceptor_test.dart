import 'dart:convert';
import 'dart:io';

import 'package:flutter_network_inspector/flutter_network_inspector.dart';
import 'package:flutter_network_inspector/src/interceptor/io/inspector_http_client.dart';
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
  });
}
