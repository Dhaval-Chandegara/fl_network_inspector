import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_network_inspector/fl_network_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NetworkInspectorDioInterceptor (INTC-04, D-33, D-34, D-35, DATA-04)', () {
    late HttpServer server;
    late InMemoryNetworkInspectorRepository repository;
    late Dio dio;
    final receivedHeaders = <String, List<String>>{};

    setUp(() async {
      receivedHeaders.clear();
      repository = InMemoryNetworkInspectorRepository(maxRecords: 100);
      await NetworkInspector.initialize(
        config: const NetworkInspectorConfig(
          enabled: true,
          enableAutoCapture: false, // Isolate Dio adapter
          ignoredHosts: ['analytics.test.local'],
        ),
        repository: repository,
      );

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest request) async {
        request.headers.forEach((name, values) {
          receivedHeaders[name.toLowerCase()] = values;
        });

        if (request.uri.path == '/api/users') {
          if (request.method == 'GET') {
            request.response.headers.contentType = ContentType.json;
            request.response.statusCode = HttpStatus.ok;
            request.response.write(jsonEncode([
              {'id': 1, 'name': 'Alice'},
              {'id': 2, 'name': 'Bob'},
            ]));
            await request.response.close();
          } else if (request.method == 'POST') {
            final body = await utf8.decoder.bind(request).join();
            request.response.headers.contentType = ContentType.json;
            request.response.statusCode = HttpStatus.created;
            request.response.write(jsonEncode({'created': true, 'payload': body}));
            await request.response.close();
          }
        } else if (request.uri.path == '/api/upload') {
          // Drain request body
          await request.drain<void>();
          request.response.headers.contentType = ContentType.json;
          request.response.statusCode = HttpStatus.ok;
          request.response.write(jsonEncode({'status': 'uploaded'}));
          await request.response.close();
        } else if (request.uri.path == '/api/error-500') {
          request.response.statusCode = HttpStatus.internalServerError;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'error': 'Internal Server Error'}));
          await request.response.close();
        } else {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        }
      });

      dio = Dio(
        BaseOptions(
          baseUrl: 'http://${server.address.host}:${server.port}',
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );
      dio.interceptors.add(const NetworkInspectorDioInterceptor());
    });

    tearDown(() async {
      dio.close(force: true);
      await server.close(force: true);
      NetworkInspector.resetForTesting();
    });

    test('captures GET request and response lifecycle with NetworkStatus.success', () async {
      final response = await dio.get<dynamic>(
        '/api/users',
        queryParameters: {'role': 'admin', 'token': 'secret-token-123'},
        options: Options(headers: {'x-app-version': '1.0.0'}),
      );

      expect(response.statusCode, equals(200));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final records = await repository.getRecords();
      expect(records.length, equals(1));

      final record = records.first;
      expect(record.method, equals('GET'));
      expect(record.path, equals('/api/users'));
      expect(record.status, equals(NetworkStatus.success));
      expect(record.responseStatusCode, equals(200));
      expect(record.durationMs, isNotNull);
      expect(record.durationMs! >= 0, isTrue);

      // Verify query params were redacted
      expect(record.requestQueryParams['role'], equals('admin'));
      expect(
        record.requestQueryParams['token'],
        equals(NetworkInspectorConstants.redactedPlaceholder),
      );

      // Verify response body
      expect(record.responseBody, isNotNull);
      expect(record.responseBody!.body, contains('Alice'));
      expect(record.responseBody!.bodyType, equals(BodyType.json));

      // Verify synthetic tracking header was injected
      expect(
        receivedHeaders.containsKey(NetworkInspectorConstants.headerInspectorId),
        isTrue,
      );
    });

    test('captures POST request with JSON payload', () async {
      final response = await dio.post<dynamic>(
        '/api/users',
        data: {'name': 'Charlie', 'password': 'super-secret-password'},
      );

      expect(response.statusCode, equals(201));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final records = await repository.getRecords();
      expect(records.length, equals(1));

      final record = records.first;
      expect(record.method, equals('POST'));
      expect(record.status, equals(NetworkStatus.success));
      expect(record.responseStatusCode, equals(201));

      // Request body should have password redacted
      expect(record.requestBody, isNotNull);
      expect(
        record.requestBody!.body,
        contains(NetworkInspectorConstants.redactedPlaceholder),
      );
      expect(record.requestBody!.body, contains('Charlie'));
    });

    test('extracts FormData multipart metadata without raw binary bytes (DATA-04)', () async {
      final formData = FormData.fromMap({
        'username': 'john_doe',
        'avatar': MultipartFile.fromBytes(
          List.generate(1024, (i) => i % 256),
          filename: 'avatar.png',
          contentType: DioMediaType('image', 'png'),
        ),
        'document': MultipartFile.fromBytes(
          List.generate(2048, (i) => i % 256),
          filename: 'report.pdf',
          contentType: DioMediaType('application', 'pdf'),
        ),
      });

      final response = await dio.post<dynamic>('/api/upload', data: formData);
      expect(response.statusCode, equals(200));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final records = await repository.getRecords();
      expect(records.length, equals(1));

      final record = records.first;
      expect(record.method, equals('POST'));
      expect(record.status, equals(NetworkStatus.success));
      expect(record.multipartEntries, isNotNull);
      expect(record.multipartEntries!.length, equals(3));

      // Verify field entry
      final userEntry = record.multipartEntries!.firstWhere(
        (e) => e.fieldName == 'username',
      );
      expect(userEntry.fileName, isNull);
      expect(userEntry.byteSize, equals(utf8.encode('john_doe').length));

      // Verify file entries have metadata and NO raw binary stored
      final avatarEntry = record.multipartEntries!.firstWhere(
        (e) => e.fieldName == 'avatar',
      );
      expect(avatarEntry.fileName, equals('avatar.png'));
      expect(avatarEntry.contentType, equals('image/png'));
      expect(avatarEntry.byteSize, equals(1024));

      final docEntry = record.multipartEntries!.firstWhere(
        (e) => e.fieldName == 'document',
      );
      expect(docEntry.fileName, equals('report.pdf'));
      expect(docEntry.contentType, equals('application/pdf'));
      expect(docEntry.byteSize, equals(2048));

      // Request body summary
      expect(record.requestBody, isNotNull);
      expect(record.requestBody!.bodyType, equals(BodyType.formData));
      expect(record.requestBody!.body, contains('1 fields, 2 files'));
    });

    test('captures DioException on HTTP 500 with NetworkStatus.failed (INTC-07)', () async {
      try {
        await dio.get<dynamic>('/api/error-500');
        fail('Expected DioException');
      } on DioException catch (e) {
        expect(e.response?.statusCode, equals(500));
      }

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final records = await repository.getRecords();
      expect(records.length, equals(1));

      final record = records.first;
      expect(record.method, equals('GET'));
      expect(record.status, equals(NetworkStatus.failed));
      expect(record.responseStatusCode, equals(500));
      expect(record.error, isNotNull);
      expect(record.error!.errorType, equals('badResponse'));
      expect(record.error!.statusCode, equals(500));
    });

    test('guards against repeat registrations on the same Dio instance (D-34)', () async {
      // Intentionally register the interceptor a second time
      dio.interceptors.add(const NetworkInspectorDioInterceptor());

      final response = await dio.get<dynamic>('/api/users');
      expect(response.statusCode, equals(200));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final records = await repository.getRecords();
      // Exactly 1 record created despite 2 registered interceptors
      expect(records.length, equals(1));
    });

    test('bypasses capture for blacklisted hosts (D-36)', () async {
      final blacklistedDio = Dio(
        BaseOptions(baseUrl: 'http://analytics.test.local:8080'),
      );
      blacklistedDio.interceptors.add(const NetworkInspectorDioInterceptor());

      try {
        await blacklistedDio.get<dynamic>('/ping');
      } catch (_) {
        // Will fail to resolve host, but shouldn't record anything
      }

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final count = await repository.getRecordCount();
      expect(count, equals(0));
    });

    test('retried requests generate fresh records with distinct UUIDs (D-35)', () async {
      // Simulate retry interceptor: on error, retries once
      final retryDio = Dio(
        BaseOptions(baseUrl: 'http://${server.address.host}:${server.port}'),
      );
      retryDio.interceptors.add(const NetworkInspectorDioInterceptor());
      retryDio.interceptors.add(
        InterceptorsWrapper(
          onError: (err, handler) async {
            if (err.requestOptions.path == '/api/error-500' &&
                err.requestOptions.extra['retry_done'] != true) {
              err.requestOptions.extra['retry_done'] = true;
              // Retry by calling fetch with the same options
              try {
                final res = await retryDio.fetch<dynamic>(err.requestOptions);
                return handler.resolve(res);
              } on DioException catch (retryErr) {
                return handler.next(retryErr);
              }
            }
            handler.next(err);
          },
        ),
      );

      try {
        await retryDio.get<dynamic>('/api/error-500');
      } catch (_) {
        // Both initial and retry fail with 500
      }

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final records = await repository.getRecords();
      // Both attempts captured with distinct IDs
      expect(records.length, equals(2));
      expect(records[0].id, isNot(equals(records[1].id)));
    });

    test('no-ops when NetworkInspector is disabled (D-03)', () async {
      NetworkInspector.resetForTesting();
      await NetworkInspector.initialize(
        config: const NetworkInspectorConfig(enabled: false),
        repository: repository,
      );

      final disabledDio = Dio(
        BaseOptions(baseUrl: 'http://${server.address.host}:${server.port}'),
      );
      disabledDio.interceptors.add(const NetworkInspectorDioInterceptor());

      final response = await disabledDio.get<dynamic>('/api/users');
      expect(response.statusCode, equals(200));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final count = await repository.getRecordCount();
      expect(count, equals(0));
    });
  });
}
