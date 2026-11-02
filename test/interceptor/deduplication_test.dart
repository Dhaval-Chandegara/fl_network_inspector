import 'dart:convert';
import 'dart:io';

import 'package:flutter_network_inspector/flutter_network_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cross-Interceptor Deduplication & Header Stripping (INTC-06, D-33)', () {
    late HttpServer server;
    late InMemoryNetworkInspectorRepository repository;
    final receivedHeaders = <String, List<String>>{};

    setUp(() async {
      receivedHeaders.clear();
      repository = InMemoryNetworkInspectorRepository(maxRecords: 100);
      await NetworkInspector.initialize(
        config: const NetworkInspectorConfig(enabled: true),
        repository: repository,
      );

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest request) async {
        request.headers.forEach((name, values) {
          receivedHeaders[name.toLowerCase()] = values;
        });
        request.response.statusCode = HttpStatus.ok;
        request.response.write(jsonEncode({'status': 'ok'}));
        await request.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
      NetworkInspector.resetForTesting();
    });

    test('strips x-network-inspector-id before wire transmission and suppresses duplicate record',
        () async {
      final client = HttpClient();

      final url = Uri.parse('http://${server.address.host}:${server.port}/test');
      final request = await client.getUrl(url);

      const trackingId = 'uuid-dedup-12345';
      request.headers.add(NetworkInspectorConstants.headerInspectorId, trackingId);
      request.headers.add('x-custom-app-header', 'keep-me');

      final response = await request.close();
      expect(response.statusCode, equals(HttpStatus.ok));
      await response.drain<void>();

      // Allow async repository writes to settle
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Assert wire transmission: remote server NEVER received the tracking header
      expect(receivedHeaders.containsKey(NetworkInspectorConstants.headerInspectorId), isFalse);
      expect(
        receivedHeaders.containsKey(NetworkInspectorConstants.internalTrackingHeader),
        isFalse,
      );
      // But normal headers remain intact
      expect(receivedHeaders['x-custom-app-header'], equals(['keep-me']));

      // Assert suppression: InspectorHttpClientRequest created ZERO repository records
      final count = await repository.getRecordCount();
      expect(count, equals(0));
    });

    test('strips x-fl-net-inspector-tracked-id and suppresses record creation', () async {
      final client = HttpClient();

      final url = Uri.parse('http://${server.address.host}:${server.port}/test');
      final request = await client.getUrl(url);

      request.headers.add(
        NetworkInspectorConstants.internalTrackingHeader,
        'uuid-internal-5678',
      );
      request.headers.add('x-client-platform', 'flutter');

      final response = await request.close();
      expect(response.statusCode, equals(HttpStatus.ok));
      await response.drain<void>();

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Assert stripped over wire
      expect(
        receivedHeaders.containsKey(NetworkInspectorConstants.internalTrackingHeader),
        isFalse,
      );
      expect(receivedHeaders['x-client-platform'], equals(['flutter']));

      // Suppressed repository record
      final count = await repository.getRecordCount();
      expect(count, equals(0));
    });

    test('handles case-insensitive tracking header names (e.g. capitalized)', () async {
      final client = HttpClient();

      final url = Uri.parse('http://${server.address.host}:${server.port}/test');
      final request = await client.getUrl(url);

      request.headers.add('X-Network-Inspector-Id', 'uuid-capitalized-999');

      final response = await request.close();
      expect(response.statusCode, equals(HttpStatus.ok));
      await response.drain<void>();

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Assert stripped
      expect(receivedHeaders.containsKey('x-network-inspector-id'), isFalse);

      // Suppressed
      final count = await repository.getRecordCount();
      expect(count, equals(0));
    });

    test('captures normally when no tracking header is present', () async {
      final client = HttpClient();

      final url = Uri.parse('http://${server.address.host}:${server.port}/test');
      final request = await client.getUrl(url);

      request.headers.add('x-normal-header', 'normal-value');

      final response = await request.close();
      expect(response.statusCode, equals(HttpStatus.ok));
      await response.drain<void>();

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(receivedHeaders['x-normal-header'], equals(['normal-value']));

      // Record was captured because no tracking header suppressed it
      final count = await repository.getRecordCount();
      expect(count, equals(1));
    });
  });
}
