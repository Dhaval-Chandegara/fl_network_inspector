import '../models/network_status.dart';
import '../models/record_filter.dart';
import '../models/record_sort.dart';
import 'database_constants.dart';

/// Pure static builder creating parameterized SQL statements and argument arrays
/// from [RecordFilter] and [RecordSort] specifications.
abstract final class DatabaseQueryBuilder {
  DatabaseQueryBuilder._();

  /// Builds a parameterized SELECT query with WHERE, ORDER BY, LIMIT, and OFFSET clauses.
  static (String sql, List<Object?> args) buildRecordsQuery({
    RecordFilter? filter,
    RecordSort? sort,
    int limit = 50,
    int offset = 0,
  }) {
    final (whereClause, whereArgs) = _buildWhereClause(filter);
    final sortColumn = _resolveSortColumn(sort?.field ?? RecordSortField.timestamp);
    final sortDirection = (sort?.order == SortOrder.ascending) ? 'ASC' : 'DESC';

    final sql = StringBuffer('SELECT * FROM ${DatabaseConstants.tableName}');
    if (whereClause.isNotEmpty) {
      sql.write(' WHERE $whereClause');
    }
    sql.write(' ORDER BY $sortColumn $sortDirection LIMIT ? OFFSET ?;');

    final args = <Object?>[
      ...whereArgs,
      limit,
      offset,
    ];

    return (sql.toString(), args);
  }

  /// Builds a parameterized SELECT COUNT(*) query with matching WHERE clauses.
  static (String sql, List<Object?> args) buildCountQuery({
    RecordFilter? filter,
  }) {
    final (whereClause, whereArgs) = _buildWhereClause(filter);

    final sql = StringBuffer('SELECT COUNT(*) FROM ${DatabaseConstants.tableName}');
    if (whereClause.isNotEmpty) {
      sql.write(' WHERE $whereClause');
    }
    sql.write(';');

    return (sql.toString(), whereArgs);
  }

  static (String whereClause, List<Object?> args) _buildWhereClause(RecordFilter? filter) {
    if (filter == null || !filter.hasActiveFilters) {
      return ('', <Object?>[]);
    }

    final clauses = <String>[];
    final args = <Object?>[];

    // Substring search across url, path, request_body, response_body
    if (filter.searchQuery != null && filter.searchQuery!.trim().isNotEmpty) {
      final pattern = '%${filter.searchQuery!.trim()}%';
      clauses.add(
        '(${DatabaseConstants.columnUrl} LIKE ? OR '
        '${DatabaseConstants.columnPath} LIKE ? OR '
        '${DatabaseConstants.columnRequestBody} LIKE ? OR '
        '${DatabaseConstants.columnResponseBody} LIKE ?)',
      );
      args.addAll([pattern, pattern, pattern, pattern]);
    }

    // HTTP method filter
    if (filter.httpMethods != null && filter.httpMethods!.isNotEmpty) {
      final placeholders = List.filled(filter.httpMethods!.length, '?').join(', ');
      clauses.add('${DatabaseConstants.columnMethod} IN ($placeholders)');
      args.addAll(filter.httpMethods!.map((m) => m.toUpperCase()));
    }

    // HTTP status code filter
    if (filter.statusCodes != null && filter.statusCodes!.isNotEmpty) {
      final placeholders = List.filled(filter.statusCodes!.length, '?').join(', ');
      clauses.add('${DatabaseConstants.columnResponseStatusCode} IN ($placeholders)');
      args.addAll(filter.statusCodes!);
    }

    // Error only filter
    if (filter.errorOnly) {
      clauses.add(
        '(${DatabaseConstants.columnError} IS NOT NULL OR '
        '(${DatabaseConstants.columnResponseStatusCode} IS NOT NULL AND ${DatabaseConstants.columnResponseStatusCode} >= 400) OR '
        '${DatabaseConstants.columnStatus} = ?)',
      );
      args.add(NetworkStatus.failed.toJson());
    }

    // Duration range filters
    if (filter.minDurationMs != null) {
      clauses.add('${DatabaseConstants.columnDurationMs} >= ?');
      args.add(filter.minDurationMs!);
    }
    if (filter.maxDurationMs != null) {
      clauses.add('${DatabaseConstants.columnDurationMs} <= ?');
      args.add(filter.maxDurationMs!);
    }

    // Date range filters
    if (filter.startDate != null) {
      clauses.add('${DatabaseConstants.columnRequestTimestamp} >= ?');
      args.add(filter.startDate!.toIso8601String());
    }
    if (filter.endDate != null) {
      clauses.add('${DatabaseConstants.columnRequestTimestamp} <= ?');
      args.add(filter.endDate!.toIso8601String());
    }

    return (clauses.join(' AND '), args);
  }

  static String _resolveSortColumn(RecordSortField field) {
    switch (field) {
      case RecordSortField.timestamp:
        return DatabaseConstants.columnRequestTimestamp;
      case RecordSortField.duration:
        return DatabaseConstants.columnDurationMs;
      case RecordSortField.statusCode:
        return DatabaseConstants.columnResponseStatusCode;
      case RecordSortField.url:
        return DatabaseConstants.columnUrl;
      case RecordSortField.size:
        return DatabaseConstants.columnResponseSize;
    }
  }
}
