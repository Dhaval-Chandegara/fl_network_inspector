import 'package:fl_network_inspector/src/models/network_record.dart';
import 'package:fl_network_inspector/src/storage/database_constants.dart';
import 'package:fl_network_inspector/src/storage/database_manager.dart';
import 'package:fl_network_inspector/src/storage/database_pruner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('DatabasePrunerTest', () {
    late DatabaseManager dbManager;
    late Database db;

    setUp(() async {
      dbManager = DatabaseManager(
        factory: databaseFactoryFfi,
        customPath: inMemoryDatabasePath,
      );
      db = await dbManager.database;
    });

    tearDown(() async {
      await dbManager.close();
    });

    Future<void> insertTestRecords(int count, {DateTime? startTimestamp}) async {
      final base = startTimestamp ?? DateTime.parse('2026-10-31T12:00:00.000Z');
      final batch = db.batch();
      for (var i = 0; i < count; i++) {
        final record = NetworkRecord(
          url: 'https://api.example.com/item/$i',
          baseUrl: 'https://api.example.com',
          path: '/item/$i',
          method: 'GET',
          requestTimestamp: base.add(Duration(seconds: i)),
        );
        batch.insert(DatabaseConstants.tableName, record.toMap());
      }
      await batch.commit(noResult: true);
    }

    test('Test 1: Does NOT prune when count is within hysteresis margin (D-25)', () async {
      const maxRecords = 10;
      const margin = 5;

      // Insert exactly 15 records (maxRecords + margin)
      await insertTestRecords(15);

      final countBefore = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseConstants.tableName};'),
      );
      expect(countBefore, equals(15));

      await DatabasePruner.pruneIfNecessary(db, maxRecords, margin: margin);

      final countAfter = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseConstants.tableName};'),
      );
      expect(countAfter, equals(15)); // Not pruned
    });

    test(
        'Test 2: Pruning triggers when count exceeds maxRecords + margin, keeping newest maxRecords in FIFO order (D-25, D-26)',
        () async {
      const maxRecords = 10;
      const margin = 5;
      final startTime = DateTime.parse('2026-10-31T00:00:00.000Z');

      // Insert 20 records (exceeds 10 + 5)
      await insertTestRecords(20, startTimestamp: startTime);

      final countBefore = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseConstants.tableName};'),
      );
      expect(countBefore, equals(20));

      await DatabasePruner.pruneIfNecessary(db, maxRecords, margin: margin);

      final countAfter = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseConstants.tableName};'),
      );
      expect(countAfter, equals(maxRecords)); // Pruned down to exactly 10

      // Verify the remaining 10 records are the newest (items 10 to 19)
      final remainingRows = await db.query(
        DatabaseConstants.tableName,
        orderBy: '${DatabaseConstants.columnRequestTimestamp} ASC',
      );
      expect(remainingRows, hasLength(10));

      // The earliest remaining item should be item/10
      expect(remainingRows.first['url'], equals('https://api.example.com/item/10'));
      expect(remainingRows.last['url'], equals('https://api.example.com/item/19'));
    });

    test('Test 3: Default hysteresis margin of 50 triggers at maxRecords + 50', () async {
      const maxRecords = 100;
      expect(DatabasePruner.hysteresisMargin, equals(50));

      // Insert 150 records (100 + 50) -> should not prune
      await insertTestRecords(150);
      await DatabasePruner.pruneIfNecessary(db, maxRecords);
      var count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseConstants.tableName};'),
      );
      expect(count, equals(150));

      // Insert 1 more record -> 151 exceeds 150 -> should prune to 100
      await insertTestRecords(1);
      await DatabasePruner.pruneIfNecessary(db, maxRecords);
      count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseConstants.tableName};'),
      );
      expect(count, equals(100));
    });

    test('Test 4: Clear all action removes all records and permits new inserts (D-28)', () async {
      await insertTestRecords(15);
      var count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseConstants.tableName};'),
      );
      expect(count, equals(15));

      await DatabasePruner.clearAll(db);

      count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseConstants.tableName};'),
      );
      expect(count, equals(0));

      // Subsequent insert works without errors
      await insertTestRecords(1);
      count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseConstants.tableName};'),
      );
      expect(count, equals(1));
    });

    test('Test 5: Error resilience: pruneIfNecessary handles closed database without throwing (D-27)', () async {
      await dbManager.close();

      // Should complete without uncaught exceptions
      await expectLater(
        DatabasePruner.pruneIfNecessary(db, 10),
        completes,
      );
      await expectLater(
        DatabasePruner.clearAll(db),
        completes,
      );
    });
  });
}
