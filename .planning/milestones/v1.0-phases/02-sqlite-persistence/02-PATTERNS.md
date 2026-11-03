# Phase 02: SQLite Persistence - Pattern Map

**Mapped:** 2026-10-31  
**Files analyzed:** 22  
**Analogs found:** 22 / 22  

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `pubspec.yaml` | config | static | `pubspec.yaml` | exact |
| `lib/flutter_network_inspector.dart` | entry / barrel | static | `lib/flutter_network_inspector.dart` | exact |
| `lib/src/core/network_inspector.dart` | controller / facade | request-response | `lib/src/core/network_inspector.dart` | exact |
| `lib/src/storage/database_constants.dart` | config / constants | static | `lib/src/core/constants.dart` | exact |
| `lib/src/storage/database_manager.dart` | service / storage driver | file-I/O | `lib/src/core/network_inspector.dart` | role-match |
| `lib/src/storage/database_query_builder.dart` | utility / query builder | transform | `lib/src/utils/payload_truncator.dart` | exact |
| `lib/src/storage/database_pruner.dart` | utility / maintenance | batch / file-I/O | `lib/src/utils/payload_truncator.dart` | role-match |
| `lib/src/storage/platform/ffi_init.dart` | utility / platform bridge | static | `lib/flutter_network_inspector.dart` | exact |
| `lib/src/storage/platform/ffi_init_stub.dart` | utility / platform bridge | static | `lib/src/utils/uuid_generator.dart` | role-match |
| `lib/src/storage/platform/ffi_init_io.dart` | utility / platform bridge | static / init | `lib/src/core/network_inspector.dart` | role-match |
| `lib/src/repository/network_inspector_repository.dart` | service / interface | CRUD | `lib/src/models/network_record.dart` | role-match |
| `lib/src/repository/write_buffer_queue.dart` | utility / buffer queue | batch / event-driven | `lib/src/utils/payload_truncator.dart` | role-match |
| `lib/src/repository/sqlite_network_inspector_repository.dart` | service / repository | CRUD / batch | `lib/src/core/network_inspector.dart` | role-match |
| `lib/src/repository/in_memory_network_inspector_repository.dart` | service / repository | CRUD / ring-buffer | `lib/src/utils/redaction_engine.dart` | role-match |
| `test/storage/database_schema_test.dart` | test | verification | `test/core/platform_safety_test.dart` | role-match |
| `test/storage/database_query_builder_test.dart` | test | verification | `test/models/network_record_test.dart` | role-match |
| `test/storage/database_pruner_test.dart` | test | verification | `test/utils/payload_truncator_test.dart` | role-match |
| `test/storage/database_migration_test.dart` | test | verification | `test/config/network_inspector_config_test.dart` | role-match |
| `test/repository/write_buffer_queue_test.dart` | test | verification | `test/utils/payload_truncator_test.dart` | role-match |
| `test/repository/sqlite_repository_test.dart` | test | verification | `test/models/network_record_test.dart` | role-match |
| `test/repository/in_memory_repository_test.dart` | test | verification | `test/models/network_record_test.dart` | role-match |
| `test/core/barrel_export_test.dart` | test | verification | `test/core/barrel_export_test.dart` | exact |

---

## Pattern Assignments

### `pubspec.yaml` (config, static)

**Analog:** `pubspec.yaml`

**Dependencies block pattern** (lines 10-14):
```yaml
dependencies:
  flutter:
    sdk: flutter
  uuid: ^4.6.0
  path: ^1.9.1
  sqflite: ^2.4.5
  sqflite_common_ffi: ^2.4.5
```

**Dev-dependencies block pattern** (lines 15-20):
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  test: ^1.25.0
```

---

### `lib/flutter_network_inspector.dart` (entry / barrel, static)

**Analog:** `lib/flutter_network_inspector.dart`

**Imports and export block pattern** (lines 1-30):
```dart
/// Flutter Network Inspector
///
/// A reusable, modular, lightweight, and production-safe Flutter package
/// that captures, stores, manages, and displays HTTP network requests and
/// responses made by a Flutter application.
library flutter_network_inspector;

// Configuration
export 'src/config/network_inspector_config.dart';

// Core Facade & Constants
export 'src/core/constants.dart';
export 'src/core/network_inspector.dart';

// Domain Models
export 'src/models/body_type.dart';
export 'src/models/http_error_details.dart';
export 'src/models/multipart_entry.dart';
export 'src/models/network_record.dart';
export 'src/models/network_status.dart';
export 'src/models/payload_data.dart';
export 'src/models/record_filter.dart';
export 'src/models/record_sort.dart';

// Repository & Storage (Phase 2 additions)
export 'src/repository/in_memory_network_inspector_repository.dart';
export 'src/repository/network_inspector_repository.dart';
export 'src/repository/sqlite_network_inspector_repository.dart';

// Utilities
export 'src/utils/body_type_detector.dart';
export 'src/utils/payload_truncator.dart';
export 'src/utils/redaction_engine.dart';
export 'src/utils/uuid_generator.dart';
```

---

### `lib/src/core/network_inspector.dart` (controller / facade, request-response)

**Analog:** `lib/src/core/network_inspector.dart`

**Imports pattern** (lines 1-2):
```dart
import 'package:flutter/foundation.dart';

import '../config/network_inspector_config.dart';
import '../repository/in_memory_network_inspector_repository.dart';
import '../repository/network_inspector_repository.dart';
import '../repository/sqlite_network_inspector_repository.dart';
import '../storage/platform/ffi_init.dart';
```

**Core facade pattern** (lines 4-34):
```dart
/// Public singleton facade for initializing and accessing the Flutter Network Inspector.
final class NetworkInspector {
  NetworkInspector._();

  static NetworkInspectorConfig _currentConfig = const NetworkInspectorConfig();
  static bool _isInitialized = false;
  static NetworkInspectorRepository? _repository;

  /// Initializes the Network Inspector with the specified [config] and optional [repository].
  static Future<void> initialize({
    NetworkInspectorConfig config = const NetworkInspectorConfig(),
    NetworkInspectorRepository? repository,
  }) async {
    _currentConfig = config;
    _isInitialized = true;

    if (!config.enabled) {
      _repository = null;
      return;
    }

    if (repository != null) {
      _repository = repository;
      return;
    }

    // Platform & feature-flag routing (D-31, D-32)
    if (kIsWeb || !config.enableDatabase) {
      _repository = InMemoryNetworkInspectorRepository(
        maxRecords: config.maxRecords,
      );
    } else {
      initDesktopFfiIfRequired();
      final sqliteRepo = SqliteNetworkInspectorRepository(
        maxRecords: config.maxRecords,
      );
      await sqliteRepo.initialize();
      _repository = sqliteRepo;
    }
  }

  /// Returns the active repository instance.
  static NetworkInspectorRepository? get repository => _repository;

  /// Flushes any pending buffered writes to disk (D-24).
  static Future<void> flush() async {
    await _repository?.flush();
  }

  /// Disposes repository resources and cleans up background timers (D-24).
  static Future<void> dispose() async {
    await _repository?.dispose();
    _repository = null;
    _isInitialized = false;
  }

  /// Resets configuration and state to uninitialized defaults (for testing purposes).
  static void resetForTesting() {
    _currentConfig = const NetworkInspectorConfig();
    _isInitialized = false;
    _repository = null;
  }
}
```

---

### `lib/src/storage/database_constants.dart` (config / constants, static)

**Analog:** `lib/src/core/constants.dart`

**Imports & class definition pattern** (lines 1-32):
```dart
/// Database table names, column keys, and DDL SQL definitions for SQLite persistence (D-17, D-18).
abstract final class DatabaseConstants {
  const DatabaseConstants._();

  /// SQLite database file name.
  static const String databaseFileName = 'fl_network_inspector.db';

  /// Primary table name for storing network records.
  static const String tableName = 'network_records';

  /// Current database schema version.
  static const int schemaVersion = 1;

  // Dedicated column names matching NetworkRecord.toMap() keys directly
  static const String columnId = 'id';
  static const String columnUrl = 'url';
  static const String columnBaseUrl = 'base_url';
  static const String columnPath = 'path';
  static const String columnMethod = 'method';
  static const String columnRequestHeaders = 'request_headers';
  static const String columnRequestQueryParams = 'request_query_params';
  static const String columnRequestBody = 'request_body';
  static const String columnRequestContentType = 'request_content_type';
  static const String columnRequestSize = 'request_size';
  static const String columnRequestTimestamp = 'request_timestamp';
  static const String columnResponseStatusCode = 'response_status_code';
  static const String columnResponseHeaders = 'response_headers';
  static const String columnResponseBody = 'response_body';
  static const String columnResponseContentType = 'response_content_type';
  static const String columnResponseSize = 'response_size';
  static const String columnResponseTimestamp = 'response_timestamp';
  static const String columnDurationMs = 'duration_ms';
  static const String columnStatus = 'status';
  static const String columnError = 'error';
  static const String columnMultipartEntries = 'multipart_entries';

  // Table creation DDL statement (D-17)
  static const String createTableSql = '''
    CREATE TABLE $tableName (
      $columnId TEXT PRIMARY KEY,
      $columnUrl TEXT NOT NULL,
      $columnBaseUrl TEXT NOT NULL,
      $columnPath TEXT NOT NULL,
      $columnMethod TEXT NOT NULL,
      $columnRequestHeaders TEXT,
      $columnRequestQueryParams TEXT,
      $columnRequestBody TEXT,
      $columnRequestContentType TEXT,
      $columnRequestSize INTEGER NOT NULL DEFAULT 0,
      $columnRequestTimestamp TEXT NOT NULL,
      $columnResponseStatusCode INTEGER,
      $columnResponseHeaders TEXT,
      $columnResponseBody TEXT,
      $columnResponseContentType TEXT,
      $columnResponseSize INTEGER,
      $columnResponseTimestamp TEXT,
      $columnDurationMs INTEGER,
      $columnStatus TEXT NOT NULL,
      $columnError TEXT,
      $columnMultipartEntries TEXT
    );
  ''';

  // B-tree indexes for sub-millisecond filtering and sorting (D-18)
  static const List<String> createIndexSqlStatements = [
    'CREATE INDEX idx_records_timestamp ON $tableName ($columnRequestTimestamp DESC);',
    'CREATE INDEX idx_records_status_code ON $tableName ($columnResponseStatusCode);',
    'CREATE INDEX idx_records_method ON $tableName ($columnMethod);',
    'CREATE INDEX idx_records_duration ON $tableName ($columnDurationMs);',
    'CREATE INDEX idx_records_status ON $tableName ($columnStatus);',
  ];
}
```

---

### `lib/src/storage/database_manager.dart` (service / storage driver, file-I/O)

**Analog:** `lib/src/core/network_inspector.dart` (static coordinator) & `lib/src/utils/uuid_generator.dart`

**Imports pattern**:
```dart
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'database_constants.dart';
```

**Core connection & WAL configuration pattern** (aligned with D-19, D-20):
```dart
class DatabaseManager {
  final DatabaseFactory factory;
  final String? customPath;

  Database? _db;

  DatabaseManager({
    DatabaseFactory? factory,
    this.customPath,
  }) : factory = factory ?? databaseFactory;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) {
      return _db!;
    }
    _db = await open();
    return _db!;
  }

  Future<Database> open() async {
    final dbPath = customPath ?? p.join(await factory.getDatabasesPath(), DatabaseConstants.databaseFileName);

    return await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: DatabaseConstants.schemaVersion,
        onConfigure: (Database db) async {
          // WAL mode and NORMAL synchrony for non-blocking concurrent reads (D-19)
          await db.execute('PRAGMA journal_mode = WAL;');
          await db.execute('PRAGMA synchronous = NORMAL;');
        },
        onCreate: (Database db, int version) async {
          await db.execute(DatabaseConstants.createTableSql);
          for (final indexSql in DatabaseConstants.createIndexSqlStatements) {
            await db.execute(indexSql);
          }
        },
        onUpgrade: (Database db, int oldVersion, int newVersion) async {
          // Versioned migration pipeline hook (D-20)
        },
      ),
    );
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
```

**Error handling pattern**:
Operations guard connection state (`_db != null && _db!.isOpen`); exceptions during open or pragmas propagate to repository initialization or log cleanly without throwing into application network calls.

---

### `lib/src/storage/database_query_builder.dart` (utility / query builder, transform)

**Analog:** `lib/src/utils/payload_truncator.dart` & `lib/src/utils/body_type_detector.dart`

**Imports pattern**:
```dart
import '../models/network_status.dart';
import '../models/record_filter.dart';
import '../models/record_sort.dart';
import 'database_constants.dart';
```

**Core query builder pattern** (pure function returning structured records `(String sql, List<Object?> args)`):
```dart
abstract final class DatabaseQueryBuilder {
  const DatabaseQueryBuilder._();

  /// Builds a parameterized SELECT query matching [filter], [sort], [limit], and [offset].
  static (String sql, List<Object?> args) buildRecordsQuery({
    RecordFilter? filter,
    RecordSort? sort,
    int limit = 50,
    int offset = 0,
  }) {
    final whereClauses = <String>[];
    final whereArgs = <Object?>[];

    if (filter != null) {
      if (filter.searchQuery != null && filter.searchQuery!.trim().isNotEmpty) {
        final pattern = '%${filter.searchQuery!.trim()}%';
        whereClauses.add(
          '(${DatabaseConstants.columnUrl} LIKE ? OR '
          '${DatabaseConstants.columnPath} LIKE ? OR '
          '${DatabaseConstants.columnRequestBody} LIKE ? OR '
          '${DatabaseConstants.columnResponseBody} LIKE ?)',
        );
        whereArgs.addAll([pattern, pattern, pattern, pattern]);
      }

      if (filter.httpMethods != null && filter.httpMethods!.isNotEmpty) {
        final placeholders = List.filled(filter.httpMethods!.length, '?').join(', ');
        whereClauses.add('${DatabaseConstants.columnMethod} IN ($placeholders)');
        whereArgs.addAll(filter.httpMethods!.map((m) => m.toUpperCase()));
      }

      if (filter.statusCodes != null && filter.statusCodes!.isNotEmpty) {
        final placeholders = List.filled(filter.statusCodes!.length, '?').join(', ');
        whereClauses.add('${DatabaseConstants.columnResponseStatusCode} IN ($placeholders)');
        whereArgs.addAll(filter.statusCodes!);
      }

      if (filter.errorOnly) {
        whereClauses.add(
          '(${DatabaseConstants.columnError} IS NOT NULL OR '
          '(${DatabaseConstants.columnResponseStatusCode} IS NOT NULL AND ${DatabaseConstants.columnResponseStatusCode} >= 400) OR '
          '${DatabaseConstants.columnStatus} = ?)',
        );
        whereArgs.add(NetworkStatus.failed.toJson());
      }

      if (filter.minDurationMs != null) {
        whereClauses.add('${DatabaseConstants.columnDurationMs} >= ?');
        whereArgs.add(filter.minDurationMs!);
      }
      if (filter.maxDurationMs != null) {
        whereClauses.add('${DatabaseConstants.columnDurationMs} <= ?');
        whereArgs.add(filter.maxDurationMs!);
      }

      if (filter.startDate != null) {
        whereClauses.add('${DatabaseConstants.columnRequestTimestamp} >= ?');
        whereArgs.add(filter.startDate!.toIso8601String());
      }
      if (filter.endDate != null) {
        whereClauses.add('${DatabaseConstants.columnRequestTimestamp} <= ?');
        whereArgs.add(filter.endDate!.toIso8601String());
      }
    }

    final whereSql = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final sortField = sort?.field ?? RecordSortField.timestamp;
    final sortOrder = sort?.order ?? SortOrder.descending;

    final sortColumn = switch (sortField) {
      RecordSortField.timestamp => DatabaseConstants.columnRequestTimestamp,
      RecordSortField.duration => DatabaseConstants.columnDurationMs,
      RecordSortField.statusCode => DatabaseConstants.columnResponseStatusCode,
      RecordSortField.url => DatabaseConstants.columnUrl,
      RecordSortField.size => DatabaseConstants.columnResponseSize,
    };

    final orderSql = 'ORDER BY $sortColumn ${sortOrder == SortOrder.ascending ? 'ASC' : 'DESC'}';
    final limitSql = 'LIMIT ? OFFSET ?';
    whereArgs.addAll([limit, offset]);

    final sql = 'SELECT * FROM ${DatabaseConstants.tableName} $whereSql $orderSql $limitSql;';
    return (sql, whereArgs);
  }

  /// Builds a parameterized COUNT(*) query matching identical filter constraints.
  static (String sql, List<Object?> args) buildCountQuery({RecordFilter? filter}) {
    // Identical WHERE clauses as buildRecordsQuery without ORDER BY / LIMIT / OFFSET
    ...
    final whereSql = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';
    final sql = 'SELECT COUNT(*) FROM ${DatabaseConstants.tableName} $whereSql;';
    return (sql, whereArgs);
  }
}
```

---

### `lib/src/storage/database_pruner.dart` (utility / maintenance, batch / file-I/O)

**Analog:** `lib/src/utils/payload_truncator.dart` (bounds checking) & `lib/src/utils/redaction_engine.dart` (defensive error isolation)

**Imports pattern**:
```dart
import 'package:sqflite/sqflite.dart';

import 'database_constants.dart';
```

**Core hysteresis pruning pattern** (aligned with D-25, D-26, D-27):
```dart
abstract final class DatabasePruner {
  const DatabasePruner._();

  /// Hysteresis batch margin before pruning triggers (D-25).
  static const int hysteresisMargin = 50;

  /// Checks table count and purges the oldest records if exceeding [maxRecords] + 50.
  ///
  /// Wrapped in defensive try-catch to ensure background maintenance never
  /// throws into or disrupts application network traffic (D-27).
  static Future<void> pruneIfNecessary(Database db, int maxRecords) async {
    try {
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseConstants.tableName}',
      );
      final currentCount = Sqflite.firstIntValue(countResult) ?? 0;

      if (currentCount > (maxRecords + hysteresisMargin)) {
        // Indexed subquery pruning leveraging idx_records_timestamp (D-26)
        await db.rawDelete(
          '''
          DELETE FROM ${DatabaseConstants.tableName}
          WHERE ${DatabaseConstants.columnId} NOT IN (
            SELECT ${DatabaseConstants.columnId} FROM ${DatabaseConstants.tableName}
            ORDER BY ${DatabaseConstants.columnRequestTimestamp} DESC
            LIMIT ?
          )
          ''',
          [maxRecords],
        );
      }
    } catch (_) {
      // Background maintenance must remain completely error-isolated
    }
  }
}
```

---

### `lib/src/storage/platform/ffi_init.dart` (utility / platform bridge, static)

**Analog:** `lib/flutter_network_inspector.dart` (barrel / export)

**Conditional export pattern**:
```dart
/// Platform bridge conditionally initializing SQLite FFI on desktop platforms.
export 'ffi_init_stub.dart'
    if (dart.library.io) 'ffi_init_io.dart';
```

---

### `lib/src/storage/platform/ffi_init_stub.dart` (utility / platform bridge, static no-op)

**Analog:** `lib/src/utils/uuid_generator.dart`

**No-op stub implementation**:
```dart
/// No-op stub for Flutter Web and platforms without `dart:io`.
void initDesktopFfiIfRequired() {
  // No-op on Web
}
```

---

### `lib/src/storage/platform/ffi_init_io.dart` (utility / platform bridge, initialization)

**Analog:** `lib/src/core/network_inspector.dart`

**Desktop FFI initialization pattern** (uses `defaultTargetPlatform` to respect zero `dart:io` rule in foundational source):
```dart
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Initializes FFI SQLite database factory on Windows and Linux desktop platforms (D-31).
void initDesktopFfiIfRequired() {
  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
```

---

### `lib/src/repository/network_inspector_repository.dart` (service / interface, CRUD)

**Analog:** `lib/src/models/network_record.dart` (data contracts) & `lib/src/core/network_inspector.dart` (facade contract)

**Abstract contract pattern** (aligned with D-24, D-29):
```dart
import '../models/network_record.dart';
import '../models/record_filter.dart';
import '../models/record_sort.dart';

/// Abstract contract decoupling network inspector data access from storage engines (D-29).
abstract interface class NetworkInspectorRepository {
  /// Persists a single [record].
  Future<void> save(NetworkRecord record);

  /// Persists a batch of [records].
  Future<void> saveBatch(List<NetworkRecord> records);

  /// Retrieves a single record by its [id].
  Future<NetworkRecord?> getById(String id);

  /// Retrieves a paginated list of records matching [filter] and [sort].
  Future<List<NetworkRecord>> getRecords({
    RecordFilter? filter,
    RecordSort? sort,
    int limit = 50,
    int offset = 0,
  });

  /// Returns the total count of records matching [filter].
  Future<int> getRecordCount({RecordFilter? filter});

  /// Deletes all persisted records and clears in-memory buffers (D-28).
  Future<void> clearAll();

  /// Flushes pending in-memory write buffer queues to durable storage (D-24).
  Future<void> flush();

  /// Disposes repository resources, timer handles, and database connections (D-24).
  Future<void> dispose();
}
```

---

### `lib/src/repository/write_buffer_queue.dart` (utility / buffer queue, batch / event-driven)

**Analog:** `lib/src/utils/payload_truncator.dart` & `lib/src/utils/redaction_engine.dart`

**Imports pattern**:
```dart
import 'dart:async';

import '../models/network_record.dart';
```

**Core buffer queue & two-phase coalescing pattern** (aligned with D-21, D-22, D-23):
```dart
class WriteBufferQueue {
  final Future<void> Function(List<NetworkRecord>) onFlush;
  final Duration debounceDuration;
  final int batchSize;
  final int highWaterMark;

  final Map<String, NetworkRecord> _buffer = {};
  Timer? _debounceTimer;
  bool _isFlushing = false;

  WriteBufferQueue({
    required this.onFlush,
    this.debounceDuration = const Duration(milliseconds: 200),
    this.batchSize = 10,
    this.highWaterMark = 20,
  });

  /// Enqueues [record] into the buffer, coalescing existing entries in-place (D-22).
  void enqueue(NetworkRecord record) {
    _buffer[record.id] = record;

    if (_buffer.length >= highWaterMark) {
      _debounceTimer?.cancel();
      _debounceTimer = null;
      _triggerFlush();
    } else {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(debounceDuration, _triggerFlush);
    }
  }

  /// Immediately flushes all queued records to the underlying sink.
  Future<void> flush() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    await _triggerFlush();
  }

  Future<void> _triggerFlush() async {
    if (_isFlushing || _buffer.isEmpty) return;
    _isFlushing = true;

    try {
      final itemsToFlush = _buffer.values.toList();
      _buffer.clear();
      await onFlush(itemsToFlush);
    } catch (_) {
      // Error isolation prevents write queue failures from crashing app isolates
    } finally {
      _isFlushing = false;
      if (_buffer.isNotEmpty) {
        _debounceTimer = Timer(debounceDuration, _triggerFlush);
      }
    }
  }

  void dispose() {
    _debounceTimer?.cancel();
    _buffer.clear();
  }
}
```

---

### `lib/src/repository/sqlite_network_inspector_repository.dart` (service / repository, CRUD / batch)

**Analog:** `lib/src/core/network_inspector.dart` (initialization & lifecycle)

**Imports pattern**:
```dart
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
```

**Core CRUD & batch execution pattern** (aligned with D-21, D-22, D-24, D-28, D-30):
```dart
class SqliteNetworkInspectorRepository implements NetworkInspectorRepository {
  final DatabaseManager _dbManager;
  final int maxRecords;
  late final WriteBufferQueue _writeQueue;

  SqliteNetworkInspectorRepository({
    DatabaseFactory? databaseFactory,
    String? databasePath,
    this.maxRecords = NetworkInspectorConstants.defaultMaxRecords,
  }) : _dbManager = DatabaseManager(factory: databaseFactory, customPath: databasePath) {
    _writeQueue = WriteBufferQueue(onFlush: _persistBatch);
  }

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

    // noResult: true isolates platform channel from returning unnecessary row IDs
    await batch.commit(noResult: true);

    // Asynchronous error-isolated maintenance (D-25, D-27)
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
    return rows.map(NetworkRecord.fromMap).toList();
  }

  @override
  Future<int> getRecordCount({RecordFilter? filter}) async {
    await _writeQueue.flush();
    final db = await _dbManager.database;
    final (sql, args) = DatabaseQueryBuilder.buildCountQuery(filter: filter);
    final result = await db.rawQuery(sql, args);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<void> clearAll() async {
    _writeQueue.dispose();
    final db = await _dbManager.database;
    await db.delete(DatabaseConstants.tableName);
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
```

---

### `lib/src/repository/in_memory_network_inspector_repository.dart` (service / repository, CRUD / ring-buffer)

**Analog:** `lib/src/utils/redaction_engine.dart` (collection manipulation & defensive checks)

**Core ring-buffer pattern** (aligned with D-29, D-32):
```dart
import '../core/constants.dart';
import '../models/network_record.dart';
import '../models/record_filter.dart';
import '../models/record_sort.dart';
import 'network_inspector_repository.dart';

class InMemoryNetworkInspectorRepository implements NetworkInspectorRepository {
  final int maxRecords;
  final List<NetworkRecord> _records = [];

  InMemoryNetworkInspectorRepository({
    this.maxRecords = NetworkInspectorConstants.defaultMaxRecords,
  });

  @override
  Future<void> save(NetworkRecord record) async {
    final existingIndex = _records.indexWhere((r) => r.id == record.id);
    if (existingIndex != -1) {
      _records[existingIndex] = record;
    } else {
      _records.insert(0, record);
      if (_records.length > maxRecords) {
        _records.removeLast();
      }
    }
  }

  @override
  Future<void> saveBatch(List<NetworkRecord> records) async {
    for (final record in records) {
      await save(record);
    }
  }

  @override
  Future<NetworkRecord?> getById(String id) async {
    try {
      return _records.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<NetworkRecord>> getRecords({
    RecordFilter? filter,
    RecordSort? sort,
    int limit = 50,
    int offset = 0,
  }) async {
    // Filter in-memory
    var filtered = _records.where((record) {
      if (filter == null) return true;
      if (filter.searchQuery != null && filter.searchQuery!.trim().isNotEmpty) {
        final query = filter.searchQuery!.toLowerCase();
        final matches = record.url.toLowerCase().contains(query) ||
            record.path.toLowerCase().contains(query) ||
            (record.requestBody?.body?.toLowerCase().contains(query) ?? false) ||
            (record.responseBody?.body?.toLowerCase().contains(query) ?? false);
        if (!matches) return false;
      }
      if (filter.httpMethods != null && filter.httpMethods!.isNotEmpty) {
        if (!filter.httpMethods!.contains(record.method.toUpperCase())) return false;
      }
      if (filter.statusCodes != null && filter.statusCodes!.isNotEmpty) {
        if (!filter.statusCodes!.contains(record.responseStatusCode)) return false;
      }
      if (filter.errorOnly) {
        final isError = record.hasError ||
            (record.responseStatusCode != null && record.responseStatusCode! >= 400) ||
            record.isFailed;
        if (!isError) return false;
      }
      return true;
    }).toList();

    // Sort in-memory
    final sortField = sort?.field ?? RecordSortField.timestamp;
    final sortOrder = sort?.order ?? SortOrder.descending;

    filtered.sort((a, b) {
      final comp = switch (sortField) {
        RecordSortField.timestamp => a.requestTimestamp.compareTo(b.requestTimestamp),
        RecordSortField.duration => (a.durationMs ?? 0).compareTo(b.durationMs ?? 0),
        RecordSortField.statusCode => (a.responseStatusCode ?? 0).compareTo(b.responseStatusCode ?? 0),
        RecordSortField.url => a.url.compareTo(b.url),
        RecordSortField.size => (a.responseSize ?? 0).compareTo(b.responseSize ?? 0),
      };
      return sortOrder == SortOrder.ascending ? comp : -comp;
    });

    if (offset >= filtered.length) return [];
    final endIndex = (offset + limit < filtered.length) ? offset + limit : filtered.length;
    return filtered.sublist(offset, endIndex);
  }

  @override
  Future<int> getRecordCount({RecordFilter? filter}) async {
    final list = await getRecords(filter: filter, limit: 1000000, offset: 0);
    return list.length;
  }

  @override
  Future<void> clearAll() async {
    _records.clear();
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> dispose() async {
    _records.clear();
  }
}
```

---

### `test/repository/sqlite_repository_test.dart` (test, verification)

**Analog:** `test/models/network_record_test.dart` (test structure) & RESEARCH.md (FFI testing harness)

**Testing pattern** (lines 1-40):
```dart
import 'package:flutter_network_inspector/src/models/network_record.dart';
import 'package:flutter_network_inspector/src/models/network_status.dart';
import 'package:flutter_network_inspector/src/repository/sqlite_network_inspector_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('SqliteNetworkInspectorRepository (DB-01, D-29, D-30)', () {
    late SqliteNetworkInspectorRepository repository;

    setUp(() async {
      repository = SqliteNetworkInspectorRepository(
        databaseFactory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      await repository.initialize();
    });

    tearDown(() async {
      await repository.dispose();
    });

    test('persists and retrieves records via in-memory SQLite', () async {
      final record = NetworkRecord(
        url: 'https://api.example.com/users',
        baseUrl: 'https://api.example.com',
        path: '/users',
        method: 'GET',
        requestTimestamp: DateTime.parse('2026-10-31T12:00:00.000Z'),
      );

      await repository.save(record);
      await repository.flush();

      final fetched = await repository.getById(record.id);
      expect(fetched, isNotNull);
      expect(fetched!.url, equals('https://api.example.com/users'));
      expect(fetched.method, equals('GET'));
    });
  });
}
```

---

## Shared Patterns

### 1. Zero `dart:io` in Foundational/Shared Code
**Source:** `test/core/platform_safety_test.dart` lines 7-42  
**Apply to:** All files in `lib/src/`  
**Pattern:**  
Never import `dart:io` in files in `lib/src/` to prevent Flutter Web compilation failures. Use `package:flutter/foundation.dart` (`kIsWeb`, `defaultTargetPlatform`, `TargetPlatform.windows`) and conditional exports (`if (dart.library.io)`) instead.

```dart
// Preferred platform target check:
import 'package:flutter/foundation.dart';

if (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux) {
  // desktop specific
}
```

### 2. Error Isolation (Defensive Background Maintenance)
**Source:** `lib/src/utils/redaction_engine.dart` lines 72-94 & `lib/src/utils/payload_truncator.dart` lines 67-68  
**Apply to:** `DatabasePruner`, `WriteBufferQueue`, `DatabaseManager`  
**Pattern:**  
Background tasks (pruning, micro-batch writes, cache flushes) must catch exceptions and fail silently or log without propagating into application network threads.

```dart
try {
  await maintenanceOperation();
} catch (_) {
  // Never disrupt foreground app network execution
}
```

### 3. Pure Handwritten Dart 3 Classes (No Code Generation)
**Source:** `lib/src/models/network_record.dart` lines 194-220 & `lib/src/config/network_inspector_config.dart` lines 58-105  
**Apply to:** `DatabaseConstants`, `DatabaseQueryBuilder`, `DatabaseManager`, repository implementations  
**Pattern:**  
Construct pure Dart classes using class modifiers (`abstract interface class`, `abstract final class`), records `(sql, args)`, and switch expressions without using `build_runner`, `freezed`, or `json_serializable`.

### 4. Parameterized Query Construction
**Source:** `lib/src/models/record_filter.dart` lines 5-30  
**Apply to:** `DatabaseQueryBuilder`, `DatabasePruner`  
**Pattern:**  
Always separate SQL string templates with `?` placeholders from parameter arrays (`whereArgs`) to prevent SQL injection vulnerabilities and escaping errors.

```dart
final whereClauses = <String>[];
final whereArgs = <Object?>[];
whereClauses.add('method = ?');
whereArgs.add(method.toUpperCase());
```

---

## No Analog Found

Every file to be created or modified has a direct analog in the existing codebase or in the verified architecture patterns established in Phase 1.

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| *None* | — | — | All 22 files have existing analogs |

---

## Metadata

**Analog search scope:** `lib/src/`, `test/`, `pubspec.yaml`  
**Files scanned:** 55  
**Pattern extraction date:** 2026-10-31
