import 'dart:io';

import 'package:flutter_network_inspector/src/models/network_record.dart';
import 'package:flutter_network_inspector/src/storage/database_constants.dart';
import 'package:flutter_network_inspector/src/storage/database_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('DatabaseMigrationTest', () {
    late Directory tempDir;
    late String tempDbPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fl_net_insp_migration_test_');
      tempDbPath = p.join(tempDir.path, 'migration_test.db');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    });

    test('Test 1: Fresh database open runs onCreate at version 1, creating table and indexes', () async {
      final manager = DatabaseManager(
        factory: databaseFactoryFfi,
        customPath: tempDbPath,
      );

      final db = await manager.database;
      expect(db.isOpen, isTrue);

      final version = await db.getVersion();
      expect(version, equals(DatabaseConstants.schemaVersion));

      // Verify table exists
      final tableCheck = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?;",
        [DatabaseConstants.tableName],
      );
      expect(tableCheck, hasLength(1));

      // Verify user-defined indexes exist
      final indexCheck = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = ? AND name NOT LIKE 'sqlite_autoindex%';",
        [DatabaseConstants.tableName],
      );
      expect(indexCheck, hasLength(5));

      await manager.close();
    });

    test('Test 2: Database opened with matching version does not invoke onUpgrade', () async {
      bool onUpgradeRan = false;

      // First open at v1
      final manager1 = DatabaseManager(
        factory: databaseFactoryFfi,
        customPath: tempDbPath,
      );
      final db1 = await manager1.database;
      expect(db1.isOpen, isTrue);
      await manager1.close();

      // Second open at v1 with upgrade listener
      final manager2 = DatabaseManager(
        factory: databaseFactoryFfi,
        customPath: tempDbPath,
        migrations: {
          1: (db) async {
            onUpgradeRan = true;
          },
        },
      );

      final db2 = await manager2.database;
      final version = await db2.getVersion();
      expect(version, equals(1));
      expect(onUpgradeRan, isFalse);

      await manager2.close();
    });

    test(
        'Test 3: Version upgrade simulation from v1 to v2 adds column and preserves records (DB-05, D-20)',
        () async {
      // Step 1: Initialize v1 database and insert pre-existing records
      final managerV1 = DatabaseManager(
        factory: databaseFactoryFfi,
        customPath: tempDbPath,
      );
      final dbV1 = await managerV1.open(version: 1);
      expect(await dbV1.getVersion(), equals(1));

      final testRecord = NetworkRecord(
        url: 'https://api.example.com/items',
        baseUrl: 'https://api.example.com',
        path: '/items',
        method: 'GET',
        requestTimestamp: DateTime.parse('2026-10-31T21:00:00.000Z'),
        responseStatusCode: 200,
        durationMs: 120,
      );

      await dbV1.insert(DatabaseConstants.tableName, testRecord.toMap());
      final v1Count = Sqflite.firstIntValue(
        await dbV1.rawQuery('SELECT COUNT(*) FROM ${DatabaseConstants.tableName};'),
      );
      expect(v1Count, equals(1));

      await managerV1.close();

      // Step 2: Open with version 2 and registered migration (ALTER TABLE ADD COLUMN)
      bool migrationV2Ran = false;
      final managerV2 = DatabaseManager(
        factory: databaseFactoryFfi,
        customPath: tempDbPath,
        migrations: {
          2: (Database db) async {
            migrationV2Ran = true;
            await db.execute(
              'ALTER TABLE ${DatabaseConstants.tableName} ADD COLUMN extra_test TEXT;',
            );
          },
        },
      );

      final dbV2 = await managerV2.open(version: 2);
      expect(migrationV2Ran, isTrue);
      expect(await dbV2.getVersion(), equals(2));

      // Verify the new column exists in the upgraded schema
      final columnsInfo = await dbV2.rawQuery(
        'PRAGMA table_info(${DatabaseConstants.tableName});',
      );
      final columnNames = columnsInfo.map((row) => row['name'] as String).toList();
      expect(columnNames, contains('extra_test'));
      expect(columnNames, hasLength(22)); // 21 original + 1 added

      // Verify pre-existing v1 record remains intact without data loss
      final rows = await dbV2.query(
        DatabaseConstants.tableName,
        where: '${DatabaseConstants.columnId} = ?',
        whereArgs: [testRecord.id],
      );
      expect(rows, hasLength(1));
      final upgradedRecord = NetworkRecord.fromMap(rows.first);
      expect(upgradedRecord.id, equals(testRecord.id));
      expect(upgradedRecord.url, equals('https://api.example.com/items'));
      expect(upgradedRecord.responseStatusCode, equals(200));
      expect(upgradedRecord.durationMs, equals(120));

      await managerV2.close();
    });
  });
}
