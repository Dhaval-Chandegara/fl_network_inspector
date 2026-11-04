import 'dart:convert';
import 'dart:io';
import 'package:fl_network_inspector/fl_network_inspector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('Duplicate API Calls Tracing & Optimization (Item 8)', () {
    late HttpServer server;
    late SqliteNetworkInspectorRepository sqliteRepo;
    int requestCounter = 0;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      requestCounter = 0;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest request) async {
        requestCounter++;
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'callCount': requestCounter,
          'message': 'Duplicate request response',
        }));
        await request.response.close();
      });

      sqliteRepo = SqliteNetworkInspectorRepository(
        databaseFactory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
        maxRecords: 100,
      );
      await sqliteRepo.initialize();

      await NetworkInspector.initialize(
        config: const NetworkInspectorConfig(
          enabled: true,
          enableDatabase: true,
          enableAutoCapture: false,
          enableShakeDetection: false,
        ),
        repository: sqliteRepo,
      );
    });

    tearDown(() async {
      await NetworkInspector.dispose();
      await server.close(force: true);
    });

    test('records every duplicate API call with distinct UUIDs and timestamps for tracing', () async {
      final client = NetworkInspectorHttpClient();
      final url = Uri.parse('http://${server.address.host}:${server.port}/api/redundant-data');

      // Execute 5 identical GET calls in rapid succession
      for (int i = 0; i < 5; i++) {
        final response = await client.get(url, headers: {'X-Custom-Header': 'same-value'});
        expect(response.statusCode, 200);
      }

      // Execute 3 identical POST calls with the exact same payload
      for (int i = 0; i < 3; i++) {
        final response = await client.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'action': 'refresh', 'token': 'abc'}),
        );
        expect(response.statusCode, 200);
      }

      client.close();

      // Flush in-memory queue to SQLite
      await sqliteRepo.flush();

      // Verify all 8 calls were captured individually
      final records = await sqliteRepo.getRecords();
      expect(records.length, equals(8));

      // Verify every record has a unique UUID
      final recordIds = records.map((r) => r.id).toSet();
      expect(recordIds.length, equals(8), reason: 'Each duplicate call must have a unique transaction ID');

      // Verify all 5 GET calls are recorded
      final getRecords = records.where((r) => r.method == 'GET').toList();
      expect(getRecords.length, equals(5));

      // Verify all 3 POST calls are recorded
      final postRecords = records.where((r) => r.method == 'POST').toList();
      expect(postRecords.length, equals(3));
    });
  });
}
