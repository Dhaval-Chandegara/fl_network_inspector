import 'package:fl_network_inspector/src/models/body_type.dart';
import 'package:fl_network_inspector/src/models/http_error_details.dart';
import 'package:fl_network_inspector/src/models/multipart_entry.dart';
import 'package:fl_network_inspector/src/models/network_record.dart';
import 'package:fl_network_inspector/src/models/network_status.dart';
import 'package:fl_network_inspector/src/models/payload_data.dart';
import 'package:fl_network_inspector/src/storage/database_constants.dart';
import 'package:fl_network_inspector/src/storage/database_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('DatabaseHarnessTest (Tracer)', () {
    late DatabaseManager dbManager;

    setUp(() {
      dbManager = DatabaseManager(
        factory: databaseFactoryFfi,
        customPath: inMemoryDatabasePath,
      );
    });

    tearDown(() async {
      await dbManager.close();
    });

    test('opens in-memory SQLite and round-trips all 21 NetworkRecord columns', () async {
      final db = await dbManager.database;
      expect(db.isOpen, isTrue);

      final record = NetworkRecord(
        url: 'https://api.example.com/v1/users?page=1',
        baseUrl: 'https://api.example.com',
        path: '/v1/users',
        method: 'POST',
        requestHeaders: const {'Authorization': 'Bearer test-token', 'Accept': 'application/json'},
        requestQueryParams: const {'page': '1'},
        requestBody: const PayloadData(
          body: '{"username":"dev"}',
          byteSize: 19,
          bodyType: BodyType.json,
        ),
        requestContentType: 'application/json',
        requestSize: 19,
        requestTimestamp: DateTime.parse('2026-10-31T20:00:00.000Z'),
        responseStatusCode: 201,
        responseHeaders: const {'Content-Type': 'application/json', 'x-request-id': 'req-123'},
        responseBody: const PayloadData(
          body: '{"id":"usr-99","status":"created"}',
          byteSize: 33,
          bodyType: BodyType.json,
        ),
        responseContentType: 'application/json',
        responseSize: 33,
        responseTimestamp: DateTime.parse('2026-10-31T20:00:00.250Z'),
        durationMs: 250,
        status: NetworkStatus.success,
        error: const HttpErrorDetails(
          message: 'None',
          errorType: 'NoError',
        ),
        multipartEntries: const [
          MultipartEntry(
            fieldName: 'avatar',
            fileName: 'profile.jpg',
            contentType: 'image/jpeg',
            byteSize: 1024,
          ),
        ],
      );

      final recordMap = record.toMap();
      expect(recordMap.length, equals(21));

      // Insert row into SQLite table
      final insertResult = await db.insert(
        DatabaseConstants.tableName,
        recordMap,
      );
      expect(insertResult, greaterThan(0));

      // Query inserted row by ID
      final rows = await db.query(
        DatabaseConstants.tableName,
        where: '${DatabaseConstants.columnId} = ?',
        whereArgs: [record.id],
      );

      expect(rows, hasLength(1));
      final queriedRow = rows.first;

      // Verify all 21 column keys exist in queried row
      for (final column in DatabaseConstants.allColumns) {
        expect(
          queriedRow.containsKey(column),
          isTrue,
          reason: 'Missing column $column in queried SQLite row',
        );
      }

      // Reconstruct NetworkRecord via fromMap and verify fidelity
      final reconstructed = NetworkRecord.fromMap(queriedRow);
      expect(reconstructed.id, equals(record.id));
      expect(reconstructed.url, equals(record.url));
      expect(reconstructed.baseUrl, equals(record.baseUrl));
      expect(reconstructed.path, equals(record.path));
      expect(reconstructed.method, equals(record.method));
      expect(reconstructed.requestHeaders['Authorization'], equals('Bearer test-token'));
      expect(reconstructed.requestQueryParams['page'], equals('1'));
      expect(reconstructed.requestBody?.body, equals('{"username":"dev"}'));
      expect(reconstructed.requestSize, equals(19));
      expect(reconstructed.responseStatusCode, equals(201));
      expect(reconstructed.responseHeaders?['x-request-id'], equals('req-123'));
      expect(reconstructed.responseBody?.body, equals('{"id":"usr-99","status":"created"}'));
      expect(reconstructed.durationMs, equals(250));
      expect(reconstructed.status, equals(NetworkStatus.success));
      expect(reconstructed.error?.errorType, equals('NoError'));
      expect(reconstructed.multipartEntries, hasLength(1));
      expect(reconstructed.multipartEntries!.first.fileName, equals('profile.jpg'));
    });
  });
}
