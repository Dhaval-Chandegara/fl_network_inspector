import 'dart:async';

import 'package:fl_network_inspector/src/models/network_record.dart';
import 'package:fl_network_inspector/src/models/network_status.dart';
import 'package:fl_network_inspector/src/repository/write_buffer_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WriteBufferQueue', () {
    test('Test 1: Debounces writes for 200ms before triggering onFlush (D-21)',
        () async {
      final flushedBatches = <List<NetworkRecord>>[];
      final queue = WriteBufferQueue(
        onFlush: (batch) async {
          flushedBatches.add(List.from(batch));
        },
        debounceDuration: const Duration(milliseconds: 100),
      );

      final r1 = NetworkRecord(
        url: 'https://api.example.com/1',
        baseUrl: 'https://api.example.com',
        path: '/1',
        method: 'GET',
        requestTimestamp: DateTime.now(),
      );
      final r2 = NetworkRecord(
        url: 'https://api.example.com/2',
        baseUrl: 'https://api.example.com',
        path: '/2',
        method: 'GET',
        requestTimestamp: DateTime.now(),
      );
      final r3 = NetworkRecord(
        url: 'https://api.example.com/3',
        baseUrl: 'https://api.example.com',
        path: '/3',
        method: 'GET',
        requestTimestamp: DateTime.now(),
      );

      queue.enqueue(r1);
      queue.enqueue(r2);
      queue.enqueue(r3);

      expect(queue.length, equals(3));
      expect(flushedBatches, isEmpty);

      // Wait for debounce timer (100ms + buffer)
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(flushedBatches, hasLength(1));
      expect(flushedBatches.first, hasLength(3));
      expect(queue.length, equals(0));

      queue.dispose();
    });

    test(
        'Test 2: Two-phase in-memory coalescing merges pending and completed records (D-22)',
        () async {
      final flushedRecords = <NetworkRecord>[];
      final queue = WriteBufferQueue(
        onFlush: (batch) async {
          flushedRecords.addAll(batch);
        },
        debounceDuration: const Duration(milliseconds: 200),
      );

      const testId = 'shared-transaction-uuid-123';
      final pendingRecord = NetworkRecord(
        id: testId,
        url: 'https://api.example.com/auth',
        baseUrl: 'https://api.example.com',
        path: '/auth',
        method: 'POST',
        requestTimestamp: DateTime.parse('2026-10-31T20:00:00.000Z'),
        status: NetworkStatus.pending,
      );

      final completedRecord = pendingRecord.copyWith(
        responseStatusCode: 200,
        responseTimestamp: DateTime.parse('2026-10-31T20:00:00.180Z'),
        durationMs: 180,
        status: NetworkStatus.success,
      );

      // Enqueue pending then completed before flush
      queue.enqueue(pendingRecord);
      expect(queue.length, equals(1));

      queue.enqueue(completedRecord);
      expect(queue.length, equals(1)); // Coalesced in-place

      await queue.flush();

      expect(flushedRecords, hasLength(1));
      final flushed = flushedRecords.first;
      expect(flushed.id, equals(testId));
      expect(flushed.status, equals(NetworkStatus.success));
      expect(flushed.responseStatusCode, equals(200));
      expect(flushed.durationMs, equals(180));

      queue.dispose();
    });

    test(
        'Test 3: High-water mark immediately flushes upon reaching 20 items (D-23)',
        () async {
      final flushedBatches = <List<NetworkRecord>>[];
      final completer = Completer<void>();

      final queue = WriteBufferQueue(
        onFlush: (batch) async {
          flushedBatches.add(List.from(batch));
          if (!completer.isCompleted) completer.complete();
        },
        debounceDuration: const Duration(milliseconds: 500),
        highWaterMark: 20,
      );

      for (var i = 0; i < 20; i++) {
        queue.enqueue(
          NetworkRecord(
            url: 'https://api.example.com/item/$i',
            baseUrl: 'https://api.example.com',
            path: '/item/$i',
            method: 'GET',
            requestTimestamp: DateTime.now(),
          ),
        );
      }

      // Should complete quickly without waiting 500ms
      await completer.future.timeout(const Duration(milliseconds: 150));

      expect(flushedBatches, hasLength(1));
      expect(flushedBatches.first, hasLength(20));
      expect(queue.length, equals(0));

      queue.dispose();
    });

    test('Test 4: Explicit flush drains all pending records immediately (D-24)',
        () async {
      final flushedRecords = <NetworkRecord>[];
      final queue = WriteBufferQueue(
        onFlush: (batch) async {
          flushedRecords.addAll(batch);
        },
        debounceDuration: const Duration(seconds: 10), // long debounce
      );

      queue.enqueue(
        NetworkRecord(
          url: 'https://api.example.com/manual-1',
          baseUrl: 'https://api.example.com',
          path: '/manual-1',
          method: 'GET',
          requestTimestamp: DateTime.now(),
        ),
      );
      queue.enqueue(
        NetworkRecord(
          url: 'https://api.example.com/manual-2',
          baseUrl: 'https://api.example.com',
          path: '/manual-2',
          method: 'GET',
          requestTimestamp: DateTime.now(),
        ),
      );

      expect(flushedRecords, isEmpty);
      await queue.flush();
      expect(flushedRecords, hasLength(2));
      expect(queue.isEmpty, isTrue);

      queue.dispose();
    });

    test('Test 5: Error isolation protects isolate from sink failures',
        () async {
      int attempts = 0;
      final queue = WriteBufferQueue(
        onFlush: (batch) async {
          attempts++;
          throw StateError('Simulated database write error');
        },
        debounceDuration: const Duration(milliseconds: 50),
      );

      queue.enqueue(
        NetworkRecord(
          url: 'https://api.example.com/error',
          baseUrl: 'https://api.example.com',
          path: '/error',
          method: 'GET',
          requestTimestamp: DateTime.now(),
        ),
      );

      // Should not rethrow or crash
      await expectLater(queue.flush(), completes);
      expect(attempts, equals(1));

      queue.dispose();
    });
  });
}
