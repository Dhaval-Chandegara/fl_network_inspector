/// Constants for SQLite storage schemas, column keys, and DDL statements.
abstract final class DatabaseConstants {
  DatabaseConstants._();

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

  /// All 21 column keys in the network_records table.
  static const List<String> allColumns = [
    columnId,
    columnUrl,
    columnBaseUrl,
    columnPath,
    columnMethod,
    columnRequestHeaders,
    columnRequestQueryParams,
    columnRequestBody,
    columnRequestContentType,
    columnRequestSize,
    columnRequestTimestamp,
    columnResponseStatusCode,
    columnResponseHeaders,
    columnResponseBody,
    columnResponseContentType,
    columnResponseSize,
    columnResponseTimestamp,
    columnDurationMs,
    columnStatus,
    columnError,
    columnMultipartEntries,
  ];

  /// Table creation DDL statement (D-17).
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

  /// B-tree indexes for sub-millisecond filtering and sorting (D-18).
  static const List<String> createIndexSqlStatements = [
    'CREATE INDEX idx_records_timestamp ON $tableName ($columnRequestTimestamp DESC);',
    'CREATE INDEX idx_records_status_code ON $tableName ($columnResponseStatusCode);',
    'CREATE INDEX idx_records_method ON $tableName ($columnMethod);',
    'CREATE INDEX idx_records_duration ON $tableName ($columnDurationMs);',
    'CREATE INDEX idx_records_status ON $tableName ($columnStatus);',
  ];
}
