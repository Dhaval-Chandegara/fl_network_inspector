import 'dart:convert';
import 'dart:io';

import 'package:flutter_network_inspector/flutter_network_inspector.dart';
import 'package:flutter_network_inspector/src/logging/no_op_network_request_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Manual Logging API & Request Tracker (LOG-01, D-45, D-48)', () {
    late InMemoryNetworkInspectorRepository repository;

    setUp(() async {
      repository = InMemoryNetworkInspectorRepository(maxRecords: 100);
      await NetworkInspector.initialize(
        config: const NetworkInspectorConfig(enabled: true, enableAutoCapture: false),
        repository: repository,
      );
    });

    tearDown(() {
      NetworkInspector.resetForTesting();
    });

    test('startRequest creates pending record and transitions to success via onResponse', () async {
      final start = DateTime.now();
      final tracker = NetworkInspector.startRequest(
        method: 'POST',
        url: 'https://api.example.com/graphql',
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer secret-token'},
        body: {'query': 'query GetUser { user { id name } }'},
        timestamp: start,
      );

      expect(tracker.id, isNotEmpty);

      // Verify pending record in repository
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final pendingRecord = await repository.getById(tracker.id);
      expect(pendingRecord, isNotNull);
      expect(pendingRecord!.status, equals(NetworkStatus.pending));
      expect(pendingRecord.method, equals('POST'));
      expect(pendingRecord.url, equals('https://api.example.com/graphql'));
      expect(pendingRecord.requestHeaders['Authorization'], equals('[REDACTED]'));
      expect(pendingRecord.requestBody?.body, contains('GetUser'));

      // Complete via onResponse
      await tracker.onResponse(
        statusCode: 200,
        headers: {'Content-Type': 'application/json', 'X-Server': 'gateway-1'},
        body: {'data': {'user': {'id': '42', 'name': 'Alice'}}},
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));
      final completedRecord = await repository.getById(tracker.id);
      expect(completedRecord, isNotNull);
      expect(completedRecord!.status, equals(NetworkStatus.success));
      expect(completedRecord.responseStatusCode, equals(200));
      expect(completedRecord.durationMs, isNotNull);
      expect(completedRecord.durationMs, greaterThanOrEqualTo(0));
      expect(completedRecord.responseBody?.body, contains('Alice'));
      expect(completedRecord.responseHeaders?['X-Server'], equals('gateway-1'));
    });

    test('startRequest transitions to failed via onError with HttpErrorDetails', () async {
      final tracker = NetworkInspector.startRequest(
        method: 'GET',
        url: 'https://api.example.com/custom-stream',
        headers: {'Accept': 'application/json'},
      );

      expect(tracker.id, isNotEmpty);

      // Trigger failure
      final socketException = const SocketException('Connection refused by peer');
      await tracker.onError(
        error: socketException,
        stackTrace: StackTrace.current,
        statusCode: 503,
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));
      final failedRecord = await repository.getById(tracker.id);
      expect(failedRecord, isNotNull);
      expect(failedRecord!.status, equals(NetworkStatus.failed));
      expect(failedRecord.responseStatusCode, equals(503));
      expect(failedRecord.error, isNotNull);
      expect(failedRecord.error!.errorType, contains('SocketException'));
      expect(failedRecord.error!.message, contains('Connection refused'));
      expect(failedRecord.error!.statusCode, equals(503));
    });

    test('logApi creates completed record in one-shot call', () async {
      final start = DateTime.now().subtract(const Duration(milliseconds: 120));
      await NetworkInspector.logApi(
        method: 'PUT',
        url: 'https://api.example.com/users/42',
        statusCode: 200,
        requestHeaders: {'Content-Type': 'application/json', 'apiKey': 'super-secret'},
        responseHeaders: {'Content-Type': 'application/json'},
        requestBody: {'name': 'Alice Updated'},
        responseBody: {'id': 42, 'name': 'Alice Updated', 'updatedAt': '2026-11-01'},
        duration: const Duration(milliseconds: 120),
        timestamp: start,
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));
      final records = await repository.getRecords();
      expect(records, hasLength(1));

      final record = records.first;
      expect(record.method, equals('PUT'));
      expect(record.url, equals('https://api.example.com/users/42'));
      expect(record.responseStatusCode, equals(200));
      expect(record.status, equals(NetworkStatus.success));
      expect(record.durationMs, equals(120));
      expect(record.requestHeaders['apiKey'], equals('[REDACTED]'));
      expect(record.requestBody?.body, contains('Alice Updated'));
      expect(record.responseBody?.body, contains('2026-11-01'));
    });

    test('logApi with error parameter records failed status', () async {
      final errorDetails = const HttpErrorDetails(
        message: 'Request timeout after 5000ms',
        errorType: 'TimeoutException',
        statusCode: 408,
      );

      await NetworkInspector.logApi(
        method: 'POST',
        url: 'https://api.example.com/slow-endpoint',
        statusCode: 408,
        duration: const Duration(milliseconds: 5000),
        error: errorDetails,
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));
      final records = await repository.getRecords();
      expect(records, hasLength(1));

      final record = records.first;
      expect(record.status, equals(NetworkStatus.failed));
      expect(record.responseStatusCode, equals(408));
      expect(record.error, isNotNull);
      expect(record.error!.errorType, equals('TimeoutException'));
      expect(record.error!.message, contains('Request timeout'));
    });

    test('disabled mode performs zero repository writes and returns NoOpNetworkRequestTracker (D-48)', () async {
      await NetworkInspector.initialize(
        config: const NetworkInspectorConfig(enabled: false),
        repository: repository,
      );

      expect(NetworkInspector.isEnabled, isFalse);

      final tracker = NetworkInspector.startRequest(
        method: 'GET',
        url: 'https://api.example.com/noop',
      );

      // Verify const NoOpNetworkRequestTracker is returned
      expect(tracker, isA<NoOpNetworkRequestTracker>());
      expect(tracker.id, isEmpty);

      // Calling tracker methods does not throw or write
      await tracker.onResponse(statusCode: 200);
      await tracker.onError(error: Exception('test'));

      // logApi and logError in disabled mode do nothing
      await NetworkInspector.logApi(
        method: 'GET',
        url: 'https://api.example.com/noop',
        statusCode: 200,
      );
      await NetworkInspector.logError(
        method: 'GET',
        url: 'https://api.example.com/noop',
        error: Exception('disabled error'),
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));
      final count = await repository.getRecordCount();
      expect(count, equals(0));
    });
  });
}
