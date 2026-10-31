import 'package:flutter_network_inspector/src/storage/database_constants.dart';
import 'package:flutter_network_inspector/src/storage/database_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('DatabaseSchemaTest', () {
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

    test('verifies PRAGMA journal_mode and synchronous execute without errors (D-19)', () async {
      final db = await dbManager.database;
      expect(db.isOpen, isTrue);

      // Verify pragmas execute cleanly
      final journalModeResult = await db.rawQuery('PRAGMA journal_mode;');
      expect(journalModeResult, isNotEmpty);

      final syncResult = await db.rawQuery('PRAGMA synchronous;');
      expect(syncResult, isNotEmpty);
    });

    test('verifies all 21 table columns, data types, and primary key via PRAGMA table_info (D-17)', () async {
      final db = await dbManager.database;
      final columnsInfo = await db.rawQuery('PRAGMA table_info(${DatabaseConstants.tableName});');

      expect(columnsInfo, hasLength(21));

      final columnMap = {
        for (final row in columnsInfo) row['name'] as String: row,
      };

      // Verify all 21 columns exist
      for (final expectedCol in DatabaseConstants.allColumns) {
        expect(
          columnMap.containsKey(expectedCol),
          isTrue,
          reason: 'Expected column $expectedCol was not found in table_info',
        );
      }

      // Check primary key on id
      final idCol = columnMap[DatabaseConstants.columnId]!;
      expect(idCol['pk'], equals(1));
      expect((idCol['type'] as String).toUpperCase(), equals('TEXT'));

      // Check types of key columns
      expect((columnMap[DatabaseConstants.columnUrl]!['type'] as String).toUpperCase(), equals('TEXT'));
      expect((columnMap[DatabaseConstants.columnBaseUrl]!['type'] as String).toUpperCase(), equals('TEXT'));
      expect((columnMap[DatabaseConstants.columnPath]!['type'] as String).toUpperCase(), equals('TEXT'));
      expect((columnMap[DatabaseConstants.columnMethod]!['type'] as String).toUpperCase(), equals('TEXT'));
      expect((columnMap[DatabaseConstants.columnRequestHeaders]!['type'] as String).toUpperCase(), equals('TEXT'));
      expect((columnMap[DatabaseConstants.columnRequestQueryParams]!['type'] as String).toUpperCase(), equals('TEXT'));
      expect((columnMap[DatabaseConstants.columnRequestBody]!['type'] as String).toUpperCase(), equals('TEXT'));
      expect((columnMap[DatabaseConstants.columnRequestSize]!['type'] as String).toUpperCase(), equals('INTEGER'));
      expect((columnMap[DatabaseConstants.columnResponseStatusCode]!['type'] as String).toUpperCase(), equals('INTEGER'));
      expect((columnMap[DatabaseConstants.columnResponseHeaders]!['type'] as String).toUpperCase(), equals('TEXT'));
      expect((columnMap[DatabaseConstants.columnResponseBody]!['type'] as String).toUpperCase(), equals('TEXT'));
      expect((columnMap[DatabaseConstants.columnResponseSize]!['type'] as String).toUpperCase(), equals('INTEGER'));
      expect((columnMap[DatabaseConstants.columnDurationMs]!['type'] as String).toUpperCase(), equals('INTEGER'));
      expect((columnMap[DatabaseConstants.columnStatus]!['type'] as String).toUpperCase(), equals('TEXT'));
      expect((columnMap[DatabaseConstants.columnError]!['type'] as String).toUpperCase(), equals('TEXT'));
      expect((columnMap[DatabaseConstants.columnMultipartEntries]!['type'] as String).toUpperCase(), equals('TEXT'));
    });

    test('verifies presence of all 5 dedicated B-tree indexes in sqlite_master (D-18)', () async {
      final db = await dbManager.database;
      final indexes = await db.rawQuery(
        "SELECT name, sql FROM sqlite_master WHERE type = 'index' AND tbl_name = ?;",
        [DatabaseConstants.tableName],
      );

      final indexNames = indexes.map((row) => row['name'] as String).toSet();

      expect(indexNames, contains('idx_records_timestamp'));
      expect(indexNames, contains('idx_records_status_code'));
      expect(indexNames, contains('idx_records_method'));
      expect(indexNames, contains('idx_records_duration'));
      expect(indexNames, contains('idx_records_status'));

      // Verify timestamp index includes DESC
      final timestampIndex = indexes.firstWhere((row) => row['name'] == 'idx_records_timestamp');
      final sql = (timestampIndex['sql'] as String).toUpperCase();
      expect(sql, contains('DESC'));
    });

    test('verifies default values and non-null constraints', () async {
      final db = await dbManager.database;
      final columnsInfo = await db.rawQuery('PRAGMA table_info(${DatabaseConstants.tableName});');

      final columnMap = {
        for (final row in columnsInfo) row['name'] as String: row,
      };

      // Default value for request_size
      final requestSizeCol = columnMap[DatabaseConstants.columnRequestSize]!;
      expect(requestSizeCol['dflt_value'], equals('0'));
      expect(requestSizeCol['notnull'], equals(1));

      // Non-null constraints
      final notNullColumns = [
        DatabaseConstants.columnUrl,
        DatabaseConstants.columnBaseUrl,
        DatabaseConstants.columnPath,
        DatabaseConstants.columnMethod,
        DatabaseConstants.columnRequestTimestamp,
        DatabaseConstants.columnStatus,
      ];

      for (final colName in notNullColumns) {
        expect(
          columnMap[colName]!['notnull'],
          equals(1),
          reason: 'Column $colName should have NOT NULL constraint',
        );
      }

      // Nullable columns
      final nullableColumns = [
        DatabaseConstants.columnRequestBody,
        DatabaseConstants.columnRequestContentType,
        DatabaseConstants.columnResponseStatusCode,
        DatabaseConstants.columnResponseHeaders,
        DatabaseConstants.columnResponseBody,
        DatabaseConstants.columnResponseContentType,
        DatabaseConstants.columnResponseSize,
        DatabaseConstants.columnResponseTimestamp,
        DatabaseConstants.columnDurationMs,
        DatabaseConstants.columnError,
        DatabaseConstants.columnMultipartEntries,
      ];

      for (final colName in nullableColumns) {
        expect(
          columnMap[colName]!['notnull'],
          equals(0),
          reason: 'Column $colName should be nullable',
        );
      }
    });
  });
}
