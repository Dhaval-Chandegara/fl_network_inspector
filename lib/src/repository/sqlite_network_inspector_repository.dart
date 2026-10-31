import 'package:sqflite/sqflite.dart';

import '../core/constants.dart';
import '../models/network_record.dart';
import '../models/record_filter.dart';
import '../models/record_sort.dart';
import '../storage/database_constants.dart';
import '../storage/database_manager.dart';
import '../storage/database_pruner.dart';
import '../storage/database_query_builder.dart';
import 'network_inspector_repository.dart';
import 'write_buffer_queue.dart';

/// Embedded SQLite implementation of [NetworkInspectorRepository].
///
/// Features:
/// - Write-Ahead Logging (WAL) concurrency via [DatabaseManager] (D-19).
/// - Asynchronous 200ms debounced micro-batch writes via [WriteBufferQueue] (D-21).
/// - In-memory request/response pair coalescing (D-22).
/// - High-water mark burst protection (D-23).
/// - Automated threshold hysteresis FIFO pruning (D-25, D-26).
/// - Dependency injection of [DatabaseFactory] and path for headless testing (D-30).
class SqliteNetworkInspectorRepository implements NetworkInspectorRepository {
  /// Maximum number of records retained in the database before pruning.
  final int maxRecords;

  final DatabaseManager _dbManager;
  WriteBufferQueue _writeQueue;

  /// Creates a [SqliteNetworkInspectorRepository].
  ///
  /// Injects [databaseFactory] and [databasePath] when provided (e.g. for testing);
  /// otherwise defaults to standard platform storage.
  SqliteNetworkInspectorRepository({
    DatabaseFactory? databaseFactory,
    String? databasePath,
    this.maxRecords = NetworkInspectorConstants.defaultMaxRecords,
  })  : _dbManager = DatabaseManager(
          factory: databaseFactory,
          customPath: databasePath,
        ),
        _writeQueue = WriteBufferQueue(onFlush: (batch) async {}) {
    _writeQueue = WriteBufferQueue(onFlush: _persistBatch);
  }

  /// Explicitly opens and initializes the database connection.
  Future<void> initialize() async {
    await _dbManager.database;
  }

  @override
  Future<void> save(NetworkRecord record) async {
    _writeQueue.enqueue(record);
  }

  @override
  Future<void> saveBatch(List<NetworkRecord> records) async {
    for (final record in records) {
      _writeQueue.enqueue(record);
    }
  }

  Future<void> _persistBatch(List<NetworkRecord> records) async {
    if (records.isEmpty) return;

    final db = await _dbManager.database;
    final batch = db.batch();

    for (final record in records) {
      batch.insert(
        DatabaseConstants.tableName,
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    await DatabasePruner.pruneIfNecessary(db, maxRecords);
  }

  @override
  Future<NetworkRecord?> getById(String id) async {
    await _writeQueue.flush();
    final db = await _dbManager.database;

    final rows = await db.query(
      DatabaseConstants.tableName,
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return NetworkRecord.fromMap(rows.first);
  }

  @override
  Future<List<NetworkRecord>> getRecords({
    RecordFilter? filter,
    RecordSort? sort,
    int limit = 50,
    int offset = 0,
  }) async {
    await _writeQueue.flush();
    final db = await _dbManager.database;

    final (sql, args) = DatabaseQueryBuilder.buildRecordsQuery(
      filter: filter,
      sort: sort,
      limit: limit,
      offset: offset,
    );

    final rows = await db.rawQuery(sql, args);
    return rows.map((r) => NetworkRecord.fromMap(r)).toList();
  }

  @override
  Future<int> getRecordCount({RecordFilter? filter}) async {
    await _writeQueue.flush();
    final db = await _dbManager.database;

    final (sql, args) = DatabaseQueryBuilder.buildCountQuery(filter: filter);
    final countResult = await db.rawQuery(sql, args);

    return Sqflite.firstIntValue(countResult) ?? 0;
  }

  @override
  Future<void> clearAll() async {
    _writeQueue.dispose();
    final db = await _dbManager.database;
    await DatabasePruner.clearAll(db);
    // Recreate fresh write queue for subsequent operations
    _writeQueue = WriteBufferQueue(onFlush: _persistBatch);
  }

  @override
  Future<void> flush() async {
    await _writeQueue.flush();
  }

  @override
  Future<void> dispose() async {
    await _writeQueue.flush();
    _writeQueue.dispose();
    await _dbManager.close();
  }
}
