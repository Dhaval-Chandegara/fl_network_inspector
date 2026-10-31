import 'package:sqflite/sqflite.dart';

import 'database_constants.dart';

/// Database maintenance utility handling hysteresis FIFO pruning and developer clear-all operations.
abstract final class DatabasePruner {
  DatabasePruner._();

  /// Hysteresis margin added to maxRecords before FIFO pruning triggers (D-25).
  static const int hysteresisMargin = 50;

  /// Evaluates table row count and executes indexed subquery pruning if
  /// the count exceeds [maxRecords] + [margin] (default 50).
  ///
  /// Pruning retains the newest [maxRecords] rows sorted by [columnRequestTimestamp] DESC
  /// and removes older rows in a single query (D-26).
  /// Wrapped in defensive try-catch to isolate maintenance errors (D-27).
  static Future<void> pruneIfNecessary(
    Database db,
    int maxRecords, {
    int margin = hysteresisMargin,
  }) async {
    try {
      if (!db.isOpen) return;

      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseConstants.tableName};',
      );
      final currentCount = Sqflite.firstIntValue(countResult) ?? 0;

      if (currentCount > (maxRecords + margin)) {
        await db.rawDelete('''
DELETE FROM ${DatabaseConstants.tableName}
WHERE ${DatabaseConstants.columnId} NOT IN (
  SELECT ${DatabaseConstants.columnId} FROM ${DatabaseConstants.tableName}
  ORDER BY ${DatabaseConstants.columnRequestTimestamp} DESC
  LIMIT ?
);
''', [maxRecords]);
      }
    } catch (_) {
      // Defensive error isolation prevents background maintenance errors from propagating
    }
  }

  /// Deletes all rows in the network records table, preserving table schema,
  /// active database connection, and B-tree indexes (D-28).
  static Future<void> clearAll(Database db) async {
    try {
      if (!db.isOpen) return;
      await db.delete(DatabaseConstants.tableName);
    } catch (_) {
      // Defensive error isolation
    }
  }
}
