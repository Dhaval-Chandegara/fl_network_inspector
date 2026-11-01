import 'dart:convert';
import 'dart:io';

import 'package:flutter_network_inspector/flutter_network_inspector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

void main() {
  group('NetworkInspectorHttpClient Adapter (INTC-03, INTC-05, D-33, D-34, D-41, DATA-04)', () {
    late HttpServer server;
    late InMemoryNetworkInspectorRepository repository;
    final receivedHeaders = <String, List<String>>{};

    setUp(() async {
      receivedHeaders.clear();
      repository = InMemoryNetworkInspectorRepository(maxRecords: 100);
      await NetworkInspector.initialize(
        config: const NetworkInspectorConfig(
          enabled: true,
          enableAutoCapture: false, // Isolate package:http adapter
          ignoredHosts: ['analytics.http.local'],
        ),
        repository: repository,
      );

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest request) async {
        request.headers.forEach((name, values) {
          receivedHeaders[name.toLowerCase()] = values;
        });

        if (request.uri.path == '/api/items') {
          if (request.method == 'GET') {
            request.response.headers.contentType = ContentType.json;
            request.response.statusCode = HttpStatus.ok;
            request.response.write(jsonEncode([
              {'id': 101, 'name': 'Item 1'},
              {'id': 102, 'name': 'Item 2'},
            ]));
            await request.response.close();
          } else if (request.method == 'POST') {
            final body = await utf8.decoder.bind(request).join();
            request.response.headers.contentType = ContentType.json;
            request.response.statusCode = HttpStatus.created;
            request.response.write(jsonEncode({'created': true, 'body': body}));
            await request.response.close();
          }
        } else if (request.uri.path == '/api/multipart') {
          await request.drain<void>();
          request.response.headers.contentType = ContentType.json;
          request.response.statusCode = HttpStatus.ok;
          request.response.write(jsonEncode({'status': 'multipart_received'}));
          await request.response.close();
        } else if (request.uri.path == '/api/binary') {
          request.response.headers.contentType = ContentType('image', 'jpeg');
          request.response.statusCode = HttpStatus.ok;
          request.response.add(List.generate(512, (i) => i % 256));
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

    test('sends GET request, taps stream non-destructively, and records success', () async {
      final client = NetworkInspectorHttpClient();
      final url = Uri.parse(
        'http://${server.address.host}:${server.port}/api/items?category=books&apiKey=secret123',
      );

      final response = await client.get(url, headers: {'x-app-client': 'flutter-http'});

      expect(response.statusCode, equals(200));
      // Host application consumes single-subscription response body safely
      expect(response.body, contains('Item 1'));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final records = await repository.getRecords();
      expect(records.length, equals(1));

      final record = records.first;
      expect(record.method, equals('GET'));
      expect(record.path, equals('/api/items'));
      expect(record.status, equals(NetworkStatus.success));
      expect(record.responseStatusCode, equals(200));
      expect(record.durationMs, isNotNull);

      // Redaction verification
      expect(record.requestQueryParams['category'], equals('books'));
      expect(
        record.requestQueryParams['apiKey'],
        equals(NetworkInspectorConstants.redactedPlaceholder),
      );

      // Injected tracking header verification
      expect(
        receivedHeaders.containsKey(NetworkInspectorConstants.headerInspectorId),
        isTrue,
      );

      client.close();
    });

    test('sends POST request and captures request and response payloads', () async {
      final client = NetworkInspectorHttpClient();
      final url = Uri.parse('http://${server.address.host}:${server.port}/api/items');

      final payload = jsonEncode({'title': 'New Book', 'password': 'my-secret'});
      final response = await client.post(
        url,
        headers: {'content-type': 'application/json'},
        body: payload,
      );

      expect(response.statusCode, equals(201));
      expect(response.body, contains('"created":true'));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final records = await repository.getRecords();
      expect(records.length, equals(1));

      final record = records.first;
      expect(record.method, equals('POST'));
      expect(record.status, equals(NetworkStatus.success));
      expect(record.responseStatusCode, equals(201));
      expect(record.requestBody, isNotNull);
      expect(
        record.requestBody!.body,
        contains(NetworkInspectorConstants.redactedPlaceholder),
      );
      expect(record.requestBody!.body, contains('New Book'));

      client.close();
    });

    test('extracts MultipartRequest metadata without raw file bytes (DATA-04)', () async {
      final client = NetworkInspectorHttpClient();
      final url = Uri.parse('http://${server.address.host}:${server.port}/api/multipart');

      final request = http.MultipartRequest('POST', url);
      request.fields['description'] = 'Invoice upload';
      request.files.add(
        http.MultipartFile.fromBytes(
          'invoice_file',
          List.generate(1024, (i) => i % 256),
          filename: 'invoice.pdf',
          contentType: MediaType('application', 'pdf'),
        ),
      );

      final streamedResponse = await client.send(request);
      expect(streamedResponse.statusCode, equals(200));

      // Consumer consumes stream with bytesToString without error
      final responseBody = await streamedResponse.stream.bytesToString();
      expect(responseBody, contains('multipart_received'));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final records = await repository.getRecords();
      expect(records.length, equals(1));

      final record = records.first;
      expect(record.method, equals('POST'));
      expect(record.multipartEntries, isNotNull);
      expect(record.multipartEntries!.length, equals(2));

      final textEntry = record.multipartEntries!.firstWhere(
        (e) => e.fieldName == 'description',
      );
      expect(textEntry.fileName, isNull);
      expect(textEntry.byteSize, equals(utf8.encode('Invoice upload').length));

      final fileEntry = record.multipartEntries!.firstWhere(
        (e) => e.fieldName == 'invoice_file',
      );
      expect(fileEntry.fileName, equals('invoice.pdf'));
      expect(fileEntry.contentType, equals('application/pdf'));
      expect(fileEntry.byteSize, equals(1024));

      client.close();
    });

    test('handles binary response stream with format summary (D-43)', () async {
      final client = NetworkInspectorHttpClient();
      final url = Uri.parse('http://${server.address.host}:${server.port}/api/binary');

      final response = await client.get(url);
      expect(response.statusCode, equals(200));
      expect(response.bodyBytes.length, equals(512));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final records = await repository.getRecords();
      expect(records.length, equals(1));

      final record = records.first;
      expect(record.responseBody, isNotNull);
      expect(record.responseBody!.bodyType, equals(BodyType.binary));
      expect(record.responseBody!.body, contains('[Binary data: image/jpeg, 512 bytes]'));

      client.close();
    });

    test('records NetworkStatus.failed on socket/connection failure (INTC-07)', () async {
      final client = NetworkInspectorHttpClient();
      // Target a non-existent port
      final url = Uri.parse('http://127.0.0.1:59999/unreachable');

      try {
        await client.get(url);
        fail('Expected ClientException');
      } on http.ClientException catch (e) {
        expect(e.message, isNotEmpty);
      } catch (_) {
        // Other socket error
      }

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final records = await repository.getRecords();
      expect(records.length, equals(1));

      final record = records.first;
      expect(record.status, equals(NetworkStatus.failed));
      expect(record.error, isNotNull);
      expect(record.durationMs, isNotNull);

      client.close();
    });

    test('guards against repeated/nested wrapper registrations (D-34)', () async {
      final innerClient = NetworkInspectorHttpClient();
      // Nested client wrapping another NetworkInspectorHttpClient
      final outerClient = NetworkInspectorHttpClient(innerClient);

      final url = Uri.parse('http://${server.address.host}:${server.port}/api/items');
      final response = await outerClient.get(url);
      expect(response.statusCode, equals(200));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final records = await repository.getRecords();
      // Only 1 record created
      expect(records.length, equals(1));

      outerClient.close();
    });

    test('bypasses capture for blacklisted hosts (D-36)', () async {
      final client = NetworkInspectorHttpClient();
      final url = Uri.parse('http://analytics.http.local:8080/event');

      try {
        await client.get(url);
      } catch (_) {
        // Failed DNS
      }

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final count = await repository.getRecordCount();
      expect(count, equals(0));

      client.close();
    });

    test('no-ops when NetworkInspector is disabled (D-03)', () async {
      NetworkInspector.resetForTesting();
      await NetworkInspector.initialize(
        config: const NetworkInspectorConfig(enabled: false),
        repository: repository,
      );

      final client = NetworkInspectorHttpClient();
      final url = Uri.parse('http://${server.address.host}:${server.port}/api/items');
      final response = await client.get(url);
      expect(response.statusCode, equals(200));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final count = await repository.getRecordCount();
      expect(count, equals(0));

      client.close();
    });
  });
}
