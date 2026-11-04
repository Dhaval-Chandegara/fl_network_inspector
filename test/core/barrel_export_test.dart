import 'package:fl_network_inspector/fl_network_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Public Barrel Export (CORE-02)', () {
    test('exposes all public classes and enums via single package import', () {
      // Configuration & Facade
      const config = NetworkInspectorConfig();
      expect(config.maxRecords, equals(500));
      expect(NetworkInspector.isEnabled, isA<bool>());
      expect(NetworkInspectorConstants.defaultMaxRecords, equals(500));

      // Repository & Storage
      final inMemoryRepo = InMemoryNetworkInspectorRepository(maxRecords: 10);
      expect(inMemoryRepo, isA<NetworkInspectorRepository>());

      final sqliteRepo = SqliteNetworkInspectorRepository(maxRecords: 10);
      expect(sqliteRepo, isA<NetworkInspectorRepository>());

      expect(NetworkInspector.repository, isNull);

      // Domain Models & Enums
      expect(BodyType.values.length, equals(6));
      expect(NetworkStatus.values.length, equals(3));

      const payload = PayloadData();
      expect(payload.byteSize, equals(0));

      const multipart = MultipartEntry(fieldName: 'test');
      expect(multipart.fieldName, equals('test'));

      const error = HttpErrorDetails(message: 'error');
      expect(error.message, equals('error'));

      const filter = RecordFilter();
      expect(filter.hasActiveFilters, isFalse);

      const sort = RecordSort();
      expect(sort.field, equals(RecordSortField.timestamp));
      expect(sort.order, equals(SortOrder.descending));

      final record = NetworkRecord(
        url: 'https://example.com',
        baseUrl: 'https://example.com',
        path: '/',
        method: 'GET',
        requestTimestamp: DateTime.now(),
      );
      expect(record.url, equals('https://example.com'));

      // Utilities
      expect(BodyTypeDetector.detect(body: '{"a":1}'), equals(BodyType.json));

      final truncated = PayloadTruncator.truncate(
        body: 'test',
        contentType: 'text/plain',
        maxBytes: 100,
      );
      expect(truncated.body, equals('test'));

      final engine = RedactionEngine();
      expect(engine.isSensitive('password'), isTrue);

      final uuid = UuidGenerator.v4();
      expect(uuid, isNotEmpty);

      // Client Adapters
      const dioInterceptor = NetworkInspectorDioInterceptor();
      expect(dioInterceptor, isNotNull);

      final httpClient = NetworkInspectorHttpClient();
      expect(httpClient, isNotNull);

      // Manual Logging & Request Tracking
      expect(const NoOpNetworkRequestTracker(), isA<NetworkRequestTracker>());

      // UI Presentation & Widgets
      expect(NetworkInspectorScreen, isNotNull);
      expect(NetworkInspectorDetailScreen, isNotNull);
      expect(NetworkInspectorWrapper, isNotNull);

      // Shake Detection
      expect(ShakeDetector, isNotNull);
    });
  });
}
