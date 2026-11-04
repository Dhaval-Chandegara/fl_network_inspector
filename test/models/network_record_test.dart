import 'package:fl_network_inspector/src/models/body_type.dart';
import 'package:fl_network_inspector/src/models/http_error_details.dart';
import 'package:fl_network_inspector/src/models/multipart_entry.dart';
import 'package:fl_network_inspector/src/models/network_record.dart';
import 'package:fl_network_inspector/src/models/network_status.dart';
import 'package:fl_network_inspector/src/models/payload_data.dart';
import 'package:fl_network_inspector/src/models/record_filter.dart';
import 'package:fl_network_inspector/src/models/record_sort.dart';
import 'package:fl_network_inspector/src/utils/uuid_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UuidGenerator (D-08)', () {
    test('produces valid RFC 4122 v4 UUID strings', () {
      final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        caseSensitive: false,
      );

      final id1 = UuidGenerator.v4();
      final id2 = UuidGenerator.v4();

      expect(uuidRegex.hasMatch(id1), isTrue, reason: '$id1 should match RFC 4122 v4 format');
      expect(uuidRegex.hasMatch(id2), isTrue, reason: '$id2 should match RFC 4122 v4 format');
      expect(id1, isNot(equals(id2)), reason: 'Generated UUIDs must be unique');
    });
  });

  group('NetworkRecord Lifecycle & State Transitions', () {
    final testTimestamp = DateTime.parse('2026-10-31T12:00:00.000Z');

    test('initializes as pending in-flight request by default', () {
      final record = NetworkRecord(
        url: 'https://api.example.com/v1/users',
        baseUrl: 'https://api.example.com',
        path: '/v1/users',
        method: 'GET',
        requestTimestamp: testTimestamp,
      );

      expect(record.isPending, isTrue);
      expect(record.isSuccess, isFalse);
      expect(record.isFailed, isFalse);
      expect(record.hasError, isFalse);
      expect(record.responseStatusCode, isNull);
      expect(record.durationMs, isNull);
      expect(record.id, isNotEmpty);
    });

    test('transitions to completed success state via copyWith', () {
      final initial = NetworkRecord(
        url: 'https://api.example.com/v1/users',
        baseUrl: 'https://api.example.com',
        path: '/v1/users',
        method: 'GET',
        requestTimestamp: testTimestamp,
      );

      final completed = initial.copyWith(
        status: NetworkStatus.success,
        responseStatusCode: 200,
        responseHeaders: {'content-type': 'application/json'},
        responseBody: const PayloadData(
          body: '{"users":[]}',
          byteSize: 12,
          bodyType: BodyType.json,
        ),
        durationMs: 145,
        responseTimestamp: testTimestamp.add(const Duration(milliseconds: 145)),
      );

      expect(completed.isPending, isFalse);
      expect(completed.isSuccess, isTrue);
      expect(completed.isFailed, isFalse);
      expect(completed.hasError, isFalse);
      expect(completed.responseStatusCode, equals(200));
      expect(completed.durationMs, equals(145));
    });

    test('transitions to failed error state', () {
      final initial = NetworkRecord(
        url: 'https://api.example.com/v1/auth',
        baseUrl: 'https://api.example.com',
        path: '/v1/auth',
        method: 'POST',
        requestTimestamp: testTimestamp,
      );

      final failed = initial.copyWith(
        status: NetworkStatus.failed,
        error: const HttpErrorDetails(
          message: 'Connection closed before full header was received',
          errorType: 'SocketException',
        ),
      );

      expect(failed.isPending, isFalse);
      expect(failed.isSuccess, isFalse);
      expect(failed.isFailed, isTrue);
      expect(failed.hasError, isTrue);
      expect(failed.error?.errorType, equals('SocketException'));
    });

    test('detects HTTP 4xx and 5xx responses as hasError', () {
      final notFound = NetworkRecord(
        url: 'https://api.example.com/missing',
        baseUrl: 'https://api.example.com',
        path: '/missing',
        method: 'GET',
        requestTimestamp: testTimestamp,
        responseStatusCode: 404,
        status: NetworkStatus.success,
      );

      expect(notFound.hasError, isTrue);
    });
  });

  group('NetworkRecord Serialization & Deserialization', () {
    final timestamp = DateTime.parse('2026-10-31T15:30:00.000Z');

    test('toMap and fromMap roundtrip preserves all fields', () {
      final original = NetworkRecord(
        id: '11111111-2222-3333-4444-555555555555',
        url: 'https://api.example.com/items?page=1',
        baseUrl: 'https://api.example.com',
        path: '/items',
        method: 'POST',
        requestHeaders: const {'Authorization': 'Bearer token'},
        requestQueryParams: const {'page': '1'},
        requestBody: const PayloadData(
          body: '{"name":"test"}',
          byteSize: 15,
          bodyType: BodyType.json,
          isTruncated: false,
        ),
        requestContentType: 'application/json',
        requestSize: 15,
        requestTimestamp: timestamp,
        responseStatusCode: 201,
        responseHeaders: const {'location': '/items/1'},
        responseBody: const PayloadData(
          body: '{"id":1}',
          byteSize: 8,
          bodyType: BodyType.json,
        ),
        responseContentType: 'application/json',
        responseSize: 8,
        responseTimestamp: timestamp.add(const Duration(milliseconds: 200)),
        durationMs: 200,
        status: NetworkStatus.success,
        multipartEntries: const [
          MultipartEntry(
            fieldName: 'file',
            fileName: 'doc.txt',
            contentType: 'text/plain',
            byteSize: 100,
          ),
        ],
      );

      final map = original.toMap();

      // SQLite produces stringified composite columns
      expect(map['request_headers'], isA<String>());
      expect(map['request_body'], isA<String>());
      expect(map['multipart_entries'], isA<String>());

      final restored = NetworkRecord.fromMap(map);

      expect(restored.id, equals(original.id));
      expect(restored.url, equals(original.url));
      expect(restored.baseUrl, equals(original.baseUrl));
      expect(restored.path, equals(original.path));
      expect(restored.method, equals(original.method));
      expect(restored.requestHeaders, equals({'Authorization': 'Bearer token'}));
      expect(restored.requestQueryParams, equals({'page': '1'}));
      expect(restored.requestBody, equals(original.requestBody));
      expect(restored.responseStatusCode, equals(201));
      expect(restored.responseBody, equals(original.responseBody));
      expect(restored.durationMs, equals(200));
      expect(restored.status, equals(NetworkStatus.success));
      expect(restored.multipartEntries?.first.fieldName, equals('file'));
    });

    test('fromMap handles in-memory Maps and decoded JSON structures', () {
      final inMemoryMap = {
        'id': 'abc',
        'url': 'https://example.com/api',
        'base_url': 'https://example.com',
        'path': '/api',
        'method': 'GET',
        'request_headers': {'accept': 'application/json'},
        'request_query_params': <String, dynamic>{},
        'request_timestamp': timestamp.toIso8601String(),
        'status': 'pending',
      };

      final record = NetworkRecord.fromMap(inMemoryMap);
      expect(record.id, equals('abc'));
      expect(record.requestHeaders, equals({'accept': 'application/json'}));
      expect(record.isPending, isTrue);
    });

    test('supports value equality and hashCode', () {
      final a = NetworkRecord(
        id: 'rec-1',
        url: 'https://example.com',
        baseUrl: 'https://example.com',
        path: '/',
        method: 'GET',
        requestTimestamp: timestamp,
        responseStatusCode: 200,
        status: NetworkStatus.success,
      );

      final b = NetworkRecord(
        id: 'rec-1',
        url: 'https://example.com',
        baseUrl: 'https://example.com',
        path: '/',
        method: 'GET',
        requestTimestamp: timestamp,
        responseStatusCode: 200,
        status: NetworkStatus.success,
      );

      final c = NetworkRecord(
        id: 'rec-2',
        url: 'https://example.com',
        baseUrl: 'https://example.com',
        path: '/',
        method: 'GET',
        requestTimestamp: timestamp,
        responseStatusCode: 200,
        status: NetworkStatus.success,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('RecordFilter & RecordSort', () {
    test('RecordFilter tracks active filters and supports roundtrip', () {
      const filter = RecordFilter(
        searchQuery: 'users',
        httpMethods: {'GET', 'POST'},
        statusCodes: {200, 201},
        errorOnly: true,
      );

      expect(filter.hasActiveFilters, isTrue);

      final map = filter.toMap();
      final restored = RecordFilter.fromMap(map);

      expect(restored.searchQuery, equals('users'));
      expect(restored.httpMethods, equals({'GET', 'POST'}));
      expect(restored.statusCodes, equals({200, 201}));
      expect(restored.errorOnly, isTrue);
    });

    test('RecordSort default matches newestFirst', () {
      const sort = RecordSort();
      expect(sort.field, equals(RecordSortField.timestamp));
      expect(sort.order, equals(SortOrder.descending));
      expect(sort, equals(RecordSort.newestFirst));
    });
  });
}
