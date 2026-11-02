import 'dart:convert';
import 'dart:io';
import 'package:flutter_network_inspector/flutter_network_inspector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('Full Pipeline End-to-End Integration (TEST-01, TEST-02, TEST-03)', () {
    late HttpServer server;
    late SqliteNetworkInspectorRepository sqliteRepo;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      // 1. Start local HTTP test server
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest request) async {
        if (request.uri.path == '/api/users') {
          if (request.method == 'GET') {
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode([
              {'id': 1, 'name': 'Alice'},
              {'id': 2, 'name': 'Bob'},
            ]));
          } else if (request.method == 'POST') {
            final content = await utf8.decodeStream(request);
            final data = jsonDecode(content) as Map<String, dynamic>;
            request.response.statusCode = HttpStatus.created;
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode({
              'id': 3,
              'name': data['name'],
              'created': true,
            }));
          }
          await request.response.close();
        } else if (request.uri.path == '/api/error') {
          request.response.statusCode = HttpStatus.notFound;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'error': 'Resource not found'}));
          await request.response.close();
        }
      });

      // 2. Initialize in-memory SQLite repository via sqflite_common_ffi
      sqliteRepo = SqliteNetworkInspectorRepository(
        databaseFactory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
        maxRecords: 100,
      );
      await sqliteRepo.initialize();

      // 3. Initialize NetworkInspector facade with SQLite repository
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

    test('captures HTTP client traffic and persists into SQLite with query retrieval', () async {
      final client = NetworkInspectorHttpClient();
      final url = Uri.parse('http://${server.address.host}:${server.port}/api/users');

      // 1. Execute GET request
      final getResponse = await client.get(url, headers: {'X-Client-App': 'Tester'});
      expect(getResponse.statusCode, 200);
      expect(getResponse.body, contains('Alice'));

      // 2. Execute POST request with payload
      final postResponse = await client.post(
        url,
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer test-token'},
        body: jsonEncode({'name': 'Charlie', 'password': 'super-secret'}),
      );
      expect(postResponse.statusCode, 201);
      expect(postResponse.body, contains('Charlie'));

      // 3. Execute 404 request
      final errorUrl = Uri.parse('http://${server.address.host}:${server.port}/api/error');
      final errResponse = await client.get(errorUrl);
      expect(errResponse.statusCode, 404);

      client.close();

      // Wait for async queue to persist to SQLite
      await sqliteRepo.flush();

      // 4. Verify all records persisted in SQLite
      final allRecords = await sqliteRepo.getRecords();
      expect(allRecords.length, 3);

      // Verify records ordered newest first by default
      expect(allRecords[0].url, contains('/api/error'));
      expect(allRecords[0].responseStatusCode, 404);

      expect(allRecords[1].url, contains('/api/users'));
      expect(allRecords[1].method, 'POST');
      expect(allRecords[1].responseStatusCode, 201);
      expect(allRecords[1].status, NetworkStatus.success);
      // Redaction engine check: password redacted
      expect(allRecords[1].requestBody?.body, contains(NetworkInspectorConstants.redactedPlaceholder));
      expect(allRecords[1].requestHeaders['Authorization'], '[REDACTED]');

      expect(allRecords[2].url, contains('/api/users'));
      expect(allRecords[2].method, 'GET');
      expect(allRecords[2].responseStatusCode, 200);
      expect(allRecords[2].status, NetworkStatus.success);

      // 5. Verify SQL filtering: search query
      final searchResult = await sqliteRepo.getRecords(
        filter: const RecordFilter(searchQuery: 'Charlie'),
      );
      expect(searchResult.length, 1);
      expect(searchResult.first.method, 'POST');

      // 6. Verify SQL filtering: errors only (status >= 400)
      final errorsOnly = await sqliteRepo.getRecords(
        filter: const RecordFilter(errorOnly: true),
      );
      expect(errorsOnly.length, 1);
      expect(errorsOnly.first.responseStatusCode, 404);

      // 7. Verify clearAll wipes SQLite records
      await sqliteRepo.clearAll();
      final postClear = await sqliteRepo.getRecords();
      expect(postClear, isEmpty);
      expect(await sqliteRepo.getRecordCount(), 0);
    });
  });
}
