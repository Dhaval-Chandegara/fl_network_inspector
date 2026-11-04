import 'package:fl_network_inspector/src/models/http_error_details.dart';
import 'package:fl_network_inspector/src/models/network_record.dart';
import 'package:fl_network_inspector/src/models/network_status.dart';
import 'package:fl_network_inspector/src/models/payload_data.dart';
import 'package:fl_network_inspector/src/models/record_filter.dart';
import 'package:fl_network_inspector/src/models/record_sort.dart';
import 'package:fl_network_inspector/src/repository/in_memory_network_inspector_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InMemoryNetworkInspectorRepository', () {
    late InMemoryNetworkInspectorRepository repository;

    setUp(() {
      repository = InMemoryNetworkInspectorRepository(maxRecords: 3);
    });

    tearDown(() async {
      await repository.dispose();
    });

    test('saves, retrieves, and coalesces in-place by ID', () async {
      const testId = 'in-memory-id-1';
      final pending = NetworkRecord(
        id: testId,
        url: 'https://api.example.com/status',
        baseUrl: 'https://api.example.com',
        path: '/status',
        method: 'GET',
        requestTimestamp: DateTime.now(),
        status: NetworkStatus.pending,
      );

      await repository.save(pending);
      expect(await repository.getRecordCount(), equals(1));

      final fetchedPending = await repository.getById(testId);
      expect(fetchedPending?.status, equals(NetworkStatus.pending));

      // Update in-place (coalescing)
      final completed = pending.copyWith(
        responseStatusCode: 200,
        status: NetworkStatus.success,
      );
      await repository.save(completed);

      expect(await repository.getRecordCount(), equals(1)); // count does not increase
      final fetchedCompleted = await repository.getById(testId);
      expect(fetchedCompleted?.status, equals(NetworkStatus.success));
      expect(fetchedCompleted?.responseStatusCode, equals(200));
    });

    test('evicts oldest records via FIFO ring-buffer when exceeding maxRecords', () async {
      final r1 = NetworkRecord(
        id: 'r1',
        url: 'https://api.example.com/1',
        baseUrl: 'https://api.example.com',
        path: '/1',
        method: 'GET',
        requestTimestamp: DateTime.parse('2026-10-31T01:00:00.000Z'),
      );
      final r2 = NetworkRecord(
        id: 'r2',
        url: 'https://api.example.com/2',
        baseUrl: 'https://api.example.com',
        path: '/2',
        method: 'GET',
        requestTimestamp: DateTime.parse('2026-10-31T02:00:00.000Z'),
      );
      final r3 = NetworkRecord(
        id: 'r3',
        url: 'https://api.example.com/3',
        baseUrl: 'https://api.example.com',
        path: '/3',
        method: 'GET',
        requestTimestamp: DateTime.parse('2026-10-31T03:00:00.000Z'),
      );
      final r4 = NetworkRecord(
        id: 'r4',
        url: 'https://api.example.com/4',
        baseUrl: 'https://api.example.com',
        path: '/4',
        method: 'GET',
        requestTimestamp: DateTime.parse('2026-10-31T04:00:00.000Z'),
      );

      await repository.saveBatch([r1, r2, r3]);
      expect(await repository.getRecordCount(), equals(3));

      // Adding 4th record with maxRecords = 3 should evict r1 (the oldest inserted)
      await repository.save(r4);
      expect(await repository.getRecordCount(), equals(3));

      expect(await repository.getById('r1'), isNull);
      expect(await repository.getById('r2'), isNotNull);
      expect(await repository.getById('r3'), isNotNull);
      expect(await repository.getById('r4'), isNotNull);
    });

    test('filters records by search query, method, status code, and errorOnly', () async {
      final repo = InMemoryNetworkInspectorRepository(maxRecords: 10);
      final r1 = NetworkRecord(
        url: 'https://api.example.com/search?q=flutter',
        baseUrl: 'https://api.example.com',
        path: '/search',
        method: 'GET',
        requestTimestamp: DateTime.now(),
        responseStatusCode: 200,
        responseBody: const PayloadData(body: '{"results":["doc1"]}'),
      );
      final r2 = NetworkRecord(
        url: 'https://api.example.com/auth/login',
        baseUrl: 'https://api.example.com',
        path: '/auth/login',
        method: 'POST',
        requestTimestamp: DateTime.now(),
        responseStatusCode: 401,
        status: NetworkStatus.failed,
        error: const HttpErrorDetails(message: 'Unauthorized'),
      );

      await repo.saveBatch([r1, r2]);

      // Search query across body
      final searchResults = await repo.getRecords(
        filter: const RecordFilter(searchQuery: 'doc1'),
      );
      expect(searchResults, hasLength(1));
      expect(searchResults.first.path, equals('/search'));

      // Method filter
      final postResults = await repo.getRecords(
        filter: const RecordFilter(httpMethods: {'POST'}),
      );
      expect(postResults, hasLength(1));
      expect(postResults.first.method, equals('POST'));

      // Status code filter
      final status401 = await repo.getRecords(
        filter: const RecordFilter(statusCodes: {401}),
      );
      expect(status401, hasLength(1));

      // Error only filter
      final errors = await repo.getRecords(
        filter: const RecordFilter(errorOnly: true),
      );
      expect(errors, hasLength(1));
      expect(errors.first.path, equals('/auth/login'));
    });

    test('sorts and paginates records', () async {
      final repo = InMemoryNetworkInspectorRepository(maxRecords: 10);
      final r1 = NetworkRecord(
        url: 'https://api.example.com/c',
        baseUrl: 'https://api.example.com',
        path: '/c',
        method: 'GET',
        requestTimestamp: DateTime.parse('2026-10-31T01:00:00.000Z'),
        durationMs: 300,
      );
      final r2 = NetworkRecord(
        url: 'https://api.example.com/a',
        baseUrl: 'https://api.example.com',
        path: '/a',
        method: 'GET',
        requestTimestamp: DateTime.parse('2026-10-31T02:00:00.000Z'),
        durationMs: 100,
      );
      final r3 = NetworkRecord(
        url: 'https://api.example.com/b',
        baseUrl: 'https://api.example.com',
        path: '/b',
        method: 'GET',
        requestTimestamp: DateTime.parse('2026-10-31T03:00:00.000Z'),
        durationMs: 500,
      );

      await repo.saveBatch([r1, r2, r3]);

      // Sort by duration ascending -> r2 (100), r1 (300), r3 (500)
      final byDuration = await repo.getRecords(
        sort: const RecordSort(
          field: RecordSortField.duration,
          order: SortOrder.ascending,
        ),
      );
      expect(byDuration.map((r) => r.durationMs), equals([100, 300, 500]));

      // Pagination limit and offset on duration sort
      final paged = await repo.getRecords(
        sort: const RecordSort(
          field: RecordSortField.duration,
          order: SortOrder.ascending,
        ),
        limit: 1,
        offset: 1,
      );
      expect(paged, hasLength(1));
      expect(paged.first.durationMs, equals(300));
    });

    test('clearAll, flush, and dispose work as expected', () async {
      await repository.save(
        NetworkRecord(
          url: 'https://api.example.com/test',
          baseUrl: 'https://api.example.com',
          path: '/test',
          method: 'GET',
          requestTimestamp: DateTime.now(),
        ),
      );
      expect(await repository.getRecordCount(), equals(1));

      await repository.flush();
      await repository.clearAll();
      expect(await repository.getRecordCount(), equals(0));

      await repository.dispose();
      expect(await repository.getRecordCount(), equals(0));
    });
  });
}
