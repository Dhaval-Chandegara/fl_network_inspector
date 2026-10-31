import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'database_constants.dart';

/// Callback type for versioned schema migrations.
typedef MigrationHandler = Future<void> Function(Database db);

/// Manages the embedded SQLite database lifecycle, WAL pragma configuration,
/// table creation, and incremental versioned schema migrations.
class DatabaseManager {
  /// The SQLite database factory used to open databases.
  final DatabaseFactory factory;

  /// Optional custom path for the database file (e.g. inMemoryDatabasePath).
  final String? customPath;

  final Map<int, MigrationHandler> _migrations;
  Database? _db;

  /// Creates a [DatabaseManager].
  ///
  /// If [factory] is omitted, defaults to [databaseFactory].
  /// If [customPath] is omitted, resolves [DatabaseConstants.databaseFileName]
  /// inside the default databases path.
  DatabaseManager({
    DatabaseFactory? factory,
    this.customPath,
    Map<int, MigrationHandler>? migrations,
  })  : factory = factory ?? databaseFactory,
        _migrations = Map<int, MigrationHandler>.from(migrations ?? const {});

  /// Returns the cached open [Database] instance, opening it if not already open.
  Future<Database> get database async {
    if (_db != null && _db!.isOpen) {
      return _db!;
    }
    _db = await open();
    return _db!;
  }

  /// Whether the database is currently open.
  bool get isOpen => _db != null && _db!.isOpen;

  /// Registers a migration handler for a specific [targetVersion].
  void registerMigration(int targetVersion, MigrationHandler handler) {
    _migrations[targetVersion] = handler;
  }

  /// Opens the SQLite database with WAL journal mode, NORMAL synchrony,
  /// table initialization, and incremental migration handling.
  Future<Database> open({int? version}) async {
    final effectiveVersion = version ?? DatabaseConstants.schemaVersion;
    final dbPath = customPath ??
        p.join(
          await factory.getDatabasesPath(),
          DatabaseConstants.databaseFileName,
        );

    final db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: effectiveVersion,
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
          // Execute registered migration handlers sequentially from oldVersion + 1 to newVersion (D-20)
          for (var v = oldVersion + 1; v <= newVersion; v++) {
            final migration = _migrations[v];
            if (migration != null) {
              await migration(db);
            }
          }
        },
      ),
    );

    _db = db;
    return db;
  }

  /// Closes the database connection if open and resets the cached instance.
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
