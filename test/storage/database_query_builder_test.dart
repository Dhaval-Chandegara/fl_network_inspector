import 'package:fl_network_inspector/src/models/network_status.dart';
import 'package:fl_network_inspector/src/models/record_filter.dart';
import 'package:fl_network_inspector/src/models/record_sort.dart';
import 'package:fl_network_inspector/src/storage/database_constants.dart';
import 'package:fl_network_inspector/src/storage/database_query_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DatabaseQueryBuilder', () {
    test('builds default query without filters', () {
      final (sql, args) = DatabaseQueryBuilder.buildRecordsQuery();

      expect(
        sql,
        equals(
          'SELECT * FROM ${DatabaseConstants.tableName} '
          'ORDER BY ${DatabaseConstants.columnRequestTimestamp} DESC LIMIT ? OFFSET ?;',
        ),
      );
      expect(args, equals([50, 0]));
    });

    test('parameterizes searchQuery across 4 columns', () {
      const filter = RecordFilter(searchQuery: 'users/profile');
      final (sql, args) =
          DatabaseQueryBuilder.buildRecordsQuery(filter: filter);

      expect(
        sql,
        contains(
          '(${DatabaseConstants.columnUrl} LIKE ? OR '
          '${DatabaseConstants.columnPath} LIKE ? OR '
          '${DatabaseConstants.columnRequestBody} LIKE ? OR '
          '${DatabaseConstants.columnResponseBody} LIKE ?)',
        ),
      );
      expect(args[0], equals('%users/profile%'));
      expect(args[1], equals('%users/profile%'));
      expect(args[2], equals('%users/profile%'));
      expect(args[3], equals('%users/profile%'));
      expect(args[4], equals(50)); // limit
      expect(args[5], equals(0)); // offset
    });

    test('generates IN clauses for httpMethods and statusCodes', () {
      const filter = RecordFilter(
        httpMethods: {'get', 'post'},
        statusCodes: {200, 201, 204},
      );
      final (sql, args) =
          DatabaseQueryBuilder.buildRecordsQuery(filter: filter);

      expect(sql, contains('${DatabaseConstants.columnMethod} IN (?, ?)'));
      expect(
          sql,
          contains(
              '${DatabaseConstants.columnResponseStatusCode} IN (?, ?, ?)'));
      expect(args, contains('GET'));
      expect(args, contains('POST'));
      expect(args, contains(200));
      expect(args, contains(201));
      expect(args, contains(204));
    });

    test('generates errorOnly WHERE clause', () {
      const filter = RecordFilter(errorOnly: true);
      final (sql, args) =
          DatabaseQueryBuilder.buildRecordsQuery(filter: filter);

      expect(
        sql,
        contains(
          '(${DatabaseConstants.columnError} IS NOT NULL OR '
          '(${DatabaseConstants.columnResponseStatusCode} IS NOT NULL AND ${DatabaseConstants.columnResponseStatusCode} >= 400) OR '
          '${DatabaseConstants.columnStatus} = ?)',
        ),
      );
      expect(args, contains(NetworkStatus.failed.toJson()));
    });

    test('generates duration and timestamp range clauses', () {
      final start = DateTime.parse('2026-10-01T00:00:00.000Z');
      final end = DateTime.parse('2026-10-31T23:59:59.000Z');

      final filter = RecordFilter(
        minDurationMs: 100,
        maxDurationMs: 5000,
        startDate: start,
        endDate: end,
      );

      final (sql, args) =
          DatabaseQueryBuilder.buildRecordsQuery(filter: filter);

      expect(sql, contains('${DatabaseConstants.columnDurationMs} >= ?'));
      expect(sql, contains('${DatabaseConstants.columnDurationMs} <= ?'));
      expect(sql, contains('${DatabaseConstants.columnRequestTimestamp} >= ?'));
      expect(sql, contains('${DatabaseConstants.columnRequestTimestamp} <= ?'));

      expect(args, contains(100));
      expect(args, contains(5000));
      expect(args, contains('2026-10-01T00:00:00.000Z'));
      expect(args, contains('2026-10-31T23:59:59.000Z'));
    });

    test('maps all RecordSort fields and directions correctly', () {
      final testCases = [
        (
          RecordSortField.timestamp,
          SortOrder.ascending,
          DatabaseConstants.columnRequestTimestamp,
          'ASC'
        ),
        (
          RecordSortField.timestamp,
          SortOrder.descending,
          DatabaseConstants.columnRequestTimestamp,
          'DESC'
        ),
        (
          RecordSortField.duration,
          SortOrder.ascending,
          DatabaseConstants.columnDurationMs,
          'ASC'
        ),
        (
          RecordSortField.duration,
          SortOrder.descending,
          DatabaseConstants.columnDurationMs,
          'DESC'
        ),
        (
          RecordSortField.statusCode,
          SortOrder.ascending,
          DatabaseConstants.columnResponseStatusCode,
          'ASC'
        ),
        (
          RecordSortField.statusCode,
          SortOrder.descending,
          DatabaseConstants.columnResponseStatusCode,
          'DESC'
        ),
        (
          RecordSortField.url,
          SortOrder.ascending,
          DatabaseConstants.columnUrl,
          'ASC'
        ),
        (
          RecordSortField.url,
          SortOrder.descending,
          DatabaseConstants.columnUrl,
          'DESC'
        ),
        (
          RecordSortField.size,
          SortOrder.ascending,
          DatabaseConstants.columnResponseSize,
          'ASC'
        ),
        (
          RecordSortField.size,
          SortOrder.descending,
          DatabaseConstants.columnResponseSize,
          'DESC'
        ),
      ];

      for (final (field, order, expectedCol, expectedDir) in testCases) {
        final (sql, _) = DatabaseQueryBuilder.buildRecordsQuery(
          sort: RecordSort(field: field, order: order),
        );
        expect(
          sql,
          contains('ORDER BY $expectedCol $expectedDir'),
          reason: 'Failed for $field $order',
        );
      }
    });

    test(
        'buildCountQuery produces matching WHERE clause without ORDER BY or LIMIT',
        () {
      const filter = RecordFilter(
        searchQuery: 'api/test',
        errorOnly: true,
      );

      final (sql, args) = DatabaseQueryBuilder.buildCountQuery(filter: filter);

      expect(
          sql.startsWith(
              'SELECT COUNT(*) FROM ${DatabaseConstants.tableName} WHERE'),
          isTrue);
      expect(sql.contains('ORDER BY'), isFalse);
      expect(sql.contains('LIMIT'), isFalse);
      expect(sql.contains('OFFSET'), isFalse);
      expect(
          args, hasLength(5)); // 4 search query pattern copies + 1 error status
    });
  });
}
