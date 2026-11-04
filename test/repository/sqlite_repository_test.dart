import 'package:fl_network_inspector/src/models/http_error_details.dart';
import 'package:fl_network_inspector/src/models/network_record.dart';
import 'package:fl_network_inspector/src/models/network_status.dart';
import 'package:fl_network_inspector/src/models/record_filter.dart';
import 'package:fl_network_inspector/src/models/record_sort.dart';
import 'package:fl_network_inspector/src/repository/sqlite_network_inspector_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('SqliteNetworkInspectorRepository', () {
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

    test('saves and retrieves record by id', () async {
      final record = NetworkRecord(
        url: 'https://api.example.com/login',
        baseUrl: 'https://api.example.com',
        path: '/login',
        method: 'POST',
        requestTimestamp: DateTime.parse('2026-10-31T10:00:00.000Z'),
        responseStatusCode: 200,
        status: NetworkStatus.success,
      );

      await repository.save(record);

      final retrieved = await repository.getById(record.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals(record.id));
      expect(retrieved.url, equals(record.url));
      expect(retrieved.responseStatusCode, equals(200));
    });

    test('saveBatch and getRecords supports pagination (limit and offset)', () async {
      final baseTime = DateTime.parse('2026-10-31T12:00:00.000Z');
      final records = List.generate(
        5,
        (i) => NetworkRecord(
          url: 'https://api.example.com/item/$i',
          baseUrl: 'https://api.example.com',
          path: '/item/$i',
          method: 'GET',
          requestTimestamp: baseTime.add(Duration(minutes: i)),
        ),
      );

      await repository.saveBatch(records);

      // Default sort is timestamp DESC -> items 4, 3, 2, 1, 0
      final page = await repository.getRecords(limit: 2, offset: 1);
      expect(page, hasLength(2));
      expect(page[0].path, equals('/item/3'));
      expect(page[1].path, equals('/item/2'));
    });

    test('filters records by HTTP method, status code, search query, and errorOnly', () async {
      final r1 = NetworkRecord(
        url: 'https://api.example.com/users',
        baseUrl: 'https://api.example.com',
        path: '/users',
        method: 'POST',
        requestTimestamp: DateTime.parse('2026-10-31T01:00:00.000Z'),
        responseStatusCode: 201,
        status: NetworkStatus.success,
      );
      final r2 = NetworkRecord(
        url: 'https://api.example.com/users',
        baseUrl: 'https://api.example.com',
        path: '/users',
        method: 'GET',
        requestTimestamp: DateTime.parse('2026-10-31T02:00:00.000Z'),
        responseStatusCode: 200,
        status: NetworkStatus.success,
      );
      final r3 = NetworkRecord(
        url: 'https://api.example.com/checkout',
        baseUrl: 'https://api.example.com',
        path: '/checkout',
        method: 'POST',
        requestTimestamp: DateTime.parse('2026-10-31T03:00:00.000Z'),
        responseStatusCode: 500,
        status: NetworkStatus.failed,
        error: const HttpErrorDetails(message: 'Server error'),
      );

      await repository.saveBatch([r1, r2, r3]);

      // Method filter
      final postRecords = await repository.getRecords(
        filter: const RecordFilter(httpMethods: {'POST'}),
      );
      expect(postRecords, hasLength(2));

      // Status code filter
      final status200Records = await repository.getRecords(
        filter: const RecordFilter(statusCodes: {200}),
      );
      expect(status200Records, hasLength(1));
      expect(status200Records.first.path, equals('/users'));

      // Search query filter
      final checkoutRecords = await repository.getRecords(
        filter: const RecordFilter(searchQuery: 'checkout'),
      );
      expect(checkoutRecords, hasLength(1));
      expect(checkoutRecords.first.path, equals('/checkout'));

      // Error only filter
      final errorRecords = await repository.getRecords(
        filter: const RecordFilter(errorOnly: true),
      );
      expect(errorRecords, hasLength(1));
      expect(errorRecords.first.id, equals(r3.id));
    });

    test('sorts records by duration descending', () async {
      final r1 = NetworkRecord(
        url: 'https://api.example.com/fast',
        baseUrl: 'https://api.example.com',
        path: '/fast',
        method: 'GET',
        requestTimestamp: DateTime.parse('2026-10-31T01:00:00.000Z'),
        durationMs: 50,
      );
      final r2 = NetworkRecord(
        url: 'https://api.example.com/slow',
        baseUrl: 'https://api.example.com',
        path: '/slow',
        method: 'GET',
        requestTimestamp: DateTime.parse('2026-10-31T02:00:00.000Z'),
        durationMs: 1500,
      );

      await repository.saveBatch([r1, r2]);

      final sorted = await repository.getRecords(
        sort: const RecordSort(
          field: RecordSortField.duration,
          order: SortOrder.descending,
        ),
      );

      expect(sorted, hasLength(2));
      expect(sorted.first.durationMs, equals(1500));
      expect(sorted.last.durationMs, equals(50));
    });

    test('getRecordCount returns accurate counts with and without filter', () async {
      final r1 = NetworkRecord(
        url: 'https://api.example.com/1',
        baseUrl: 'https://api.example.com',
        path: '/1',
        method: 'GET',
        requestTimestamp: DateTime.now(),
        responseStatusCode: 200,
      );
      final r2 = NetworkRecord(
        url: 'https://api.example.com/2',
        baseUrl: 'https://api.example.com',
        path: '/2',
        method: 'POST',
        requestTimestamp: DateTime.now(),
        responseStatusCode: 404,
        status: NetworkStatus.failed,
      );

      await repository.saveBatch([r1, r2]);

      final totalCount = await repository.getRecordCount();
      expect(totalCount, equals(2));

      final postCount = await repository.getRecordCount(
        filter: const RecordFilter(httpMethods: {'POST'}),
      );
      expect(postCount, equals(1));
    });

    test('clearAll removes all records and allows subsequent writes (D-28)', () async {
      final record = NetworkRecord(
        url: 'https://api.example.com/clear',
        baseUrl: 'https://api.example.com',
        path: '/clear',
        method: 'GET',
        requestTimestamp: DateTime.now(),
      );

      await repository.save(record);
      expect(await repository.getRecordCount(), equals(1));

      await repository.clearAll();
      expect(await repository.getRecordCount(), equals(0));

      // Subsequent save works
      await repository.save(record);
      expect(await repository.getRecordCount(), equals(1));
    });

    test('flush and dispose lifecycle methods execute cleanly (D-24)', () async {
      final record = NetworkRecord(
        url: 'https://api.example.com/lifecycle',
        baseUrl: 'https://api.example.com',
        path: '/lifecycle',
        method: 'GET',
        requestTimestamp: DateTime.now(),
      );

      await repository.save(record);
      await repository.flush();

      final retrieved = await repository.getById(record.id);
      expect(retrieved, isNotNull);

      await repository.dispose();
    });
  });
}
