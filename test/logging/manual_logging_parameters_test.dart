import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_network_inspector/flutter_network_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Manual Logging Parameters & Error Facade (LOG-02, D-46, D-47)', () {
    late InMemoryNetworkInspectorRepository repository;

    setUp(() async {
      repository = InMemoryNetworkInspectorRepository(maxRecords: 100);
      await NetworkInspector.initialize(
        config: const NetworkInspectorConfig(
          enabled: true,
          enableAutoCapture: false,
          maxBodyBytes: 100, // Small limit for testing truncation
        ),
        repository: repository,
      );
    });

    tearDown(() {
      NetworkInspector.resetForTesting();
    });

    test('processes Map body: JSON encoded and sensitive keys redacted (D-46)', () async {
      await NetworkInspector.logApi(
        method: 'POST',
        url: 'https://api.example.com/auth/login',
        statusCode: 200,
        requestBody: {
          'username': 'john_doe',
          'password': 'my-super-secret-password',
          'token': 'secret-auth-token',
        },
        responseBody: {
          'user': {'id': 1, 'name': 'John'},
          'access_token': 'jwt.token.here',
        },
      );

      final records = await repository.getRecords();
      expect(records, hasLength(1));

      final record = records.first;
      expect(record.requestBody, isNotNull);
      expect(record.requestBody!.bodyType, equals(BodyType.json));
      expect(record.requestBody!.body, contains('"username":"john_doe"'));
      expect(record.requestBody!.body, contains('"password":"[REDACTED]"'));
      expect(record.requestBody!.body, contains('"token":"[REDACTED]"'));

      expect(record.responseBody, isNotNull);
      expect(record.responseBody!.bodyType, equals(BodyType.json));
      expect(record.responseBody!.body, contains('"name":"John"'));
      expect(record.responseBody!.body, contains('"access_token":"[REDACTED]"'));
    });

    test('processes List body: JSON array encoded and sensitive items redacted', () async {
      await NetworkInspector.logApi(
        method: 'POST',
        url: 'https://api.example.com/batch',
        statusCode: 200,
        requestBody: [
          {'id': 1, 'secret': 'secret-1'},
          {'id': 2, 'secret': 'secret-2'},
        ],
      );

      final records = await repository.getRecords();
      expect(records, hasLength(1));

      final record = records.first;
      expect(record.requestBody!.bodyType, equals(BodyType.json));
      expect(record.requestBody!.body, contains('"id":1'));
      expect(record.requestBody!.body, contains('"secret":"[REDACTED]"'));
    });

    test('processes Uint8List binary body: records metadata banner without raw bytes (D-43, D-46)', () async {
      final binaryBytes = Uint8List.fromList(List.generate(256, (i) => i % 256));

      await NetworkInspector.logApi(
        method: 'POST',
        url: 'https://api.example.com/upload-avatar',
        statusCode: 201,
        requestHeaders: {'Content-Type': 'image/jpeg'},
        requestBody: binaryBytes,
        responseHeaders: {'Content-Type': 'image/png'},
        responseBody: binaryBytes,
      );

      final records = await repository.getRecords();
      expect(records, hasLength(1));

      final record = records.first;
      expect(record.requestBody!.bodyType, equals(BodyType.binary));
      expect(record.requestBody!.body, contains('[Binary data: image/jpeg, 256 bytes]'));
      expect(record.requestBody!.byteSize, equals(256));

      expect(record.responseBody!.bodyType, equals(BodyType.binary));
      expect(record.responseBody!.body, contains('[Binary data: image/png, 256 bytes]'));
      expect(record.responseBody!.byteSize, equals(256));
    });

    test('processes raw String body with truncation at maxBodyBytes (D-02, D-13)', () async {
      final longString = 'A' * 200;

      await NetworkInspector.logApi(
        method: 'POST',
        url: 'https://api.example.com/large-text',
        statusCode: 200,
        requestBody: longString,
      );

      final records = await repository.getRecords();
      expect(records, hasLength(1));

      final record = records.first;
      expect(record.requestBody!.isTruncated, isTrue);
      expect(record.requestBody!.byteSize, equals(200));
      expect(record.requestBody!.body, contains('[Payload truncated at 100 bytes]'));
    });

    test('processes MultipartEntry list: extracts metadata entries without raw bytes (DATA-04)', () async {
      final multipart = [
        const MultipartEntry(
          fieldName: 'description',
          contentType: 'text/plain',
          byteSize: 22,
        ),
        const MultipartEntry(
          fieldName: 'avatar',
          fileName: 'profile.png',
          contentType: 'image/png',
          byteSize: 50000,
        ),
      ];

      await NetworkInspector.logApi(
        method: 'POST',
        url: 'https://api.example.com/profile',
        statusCode: 200,
        requestBody: multipart,
      );

      final records = await repository.getRecords();
      expect(records, hasLength(1));

      final record = records.first;
      expect(record.requestBody!.bodyType, equals(BodyType.multipart));
      expect(record.requestBody!.body, contains('[Multipart: 2 entries]'));
      expect(record.multipartEntries, isNotNull);
      expect(record.multipartEntries, hasLength(2));
      expect(record.multipartEntries![0].fieldName, equals('description'));
      expect(record.multipartEntries![1].fileName, equals('profile.png'));
      expect(record.multipartEntries![1].byteSize, equals(50000));
    });

    test('standalone logError creates fresh record with NetworkStatus.failed and HttpErrorDetails (D-47)', () async {
      final error = const SocketException('Network unreachable');
      final stack = StackTrace.current;

      await NetworkInspector.logError(
        method: 'GET',
        url: 'https://api.example.com/standalone-fail',
        error: error,
        stackTrace: stack,
        statusCode: 504,
        headers: {'X-Attempt': '1'},
        body: {'reason': 'gateway timeout'},
      );

      final records = await repository.getRecords();
      expect(records, hasLength(1));

      final record = records.first;
      expect(record.id, isNotEmpty);
      expect(record.status, equals(NetworkStatus.failed));
      expect(record.responseStatusCode, equals(504));
      expect(record.error, isNotNull);
      expect(record.error!.errorType, contains('SocketException'));
      expect(record.error!.message, contains('Network unreachable'));
      expect(record.error!.statusCode, equals(504));
      expect(record.error!.stackTrace, contains('manual_logging_parameters_test.dart'));
      expect(record.requestBody?.body, contains('gateway timeout'));
    });

    test('linked logError updates existing record with failure details without duplicating (D-47)', () async {
      // First, create a pending or initial request via startRequest
      final tracker = NetworkInspector.startRequest(
        method: 'POST',
        url: 'https://api.example.com/order/checkout',
        body: {'orderId': 1001, 'amount': 99.99},
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));
      final initialCount = await repository.getRecordCount();
      expect(initialCount, equals(1));

      // Now call logError linking to tracker.id
      final failure = const HttpException('Payment gateway rejected transaction');
      await NetworkInspector.logError(
        id: tracker.id,
        method: 'POST',
        url: 'https://api.example.com/order/checkout',
        error: failure,
        statusCode: 402,
        headers: {'Content-Type': 'application/json'},
        body: {'error': 'INSUFFICIENT_FUNDS'},
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));

      // Must NOT create a duplicate record
      final records = await repository.getRecords();
      expect(records, hasLength(1));

      final record = records.first;
      expect(record.id, equals(tracker.id));
      expect(record.status, equals(NetworkStatus.failed));
      expect(record.responseStatusCode, equals(402));
      expect(record.error, isNotNull);
      expect(record.error!.errorType, contains('HttpException'));
      expect(record.error!.message, contains('Payment gateway rejected'));
      expect(record.responseBody?.body, contains('INSUFFICIENT_FUNDS'));
    });
  });
}
