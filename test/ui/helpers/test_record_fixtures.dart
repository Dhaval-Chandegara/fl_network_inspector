import 'package:fl_network_inspector/src/models/network_record.dart';
import 'package:fl_network_inspector/src/models/network_status.dart';
import 'package:fl_network_inspector/src/models/payload_data.dart';
import 'package:fl_network_inspector/src/models/body_type.dart';
import 'package:fl_network_inspector/src/models/http_error_details.dart';

/// Reusable mock [NetworkRecord] fixtures for UI widget and integration tests.
class TestRecordFixtures {
  static NetworkRecord createRecord({
    String id = 'req-1',
    String url = 'https://api.example.com/v1/users',
    String method = 'GET',
    int? statusCode = 200,
    NetworkStatus status = NetworkStatus.success,
    int durationMs = 120,
    DateTime? timestamp,
    int requestBytes = 256,
    int responseBytes = 1024,
    HttpErrorDetails? error,
  }) {
    final now = timestamp ?? DateTime.now();
    final uri = Uri.parse(url);
    final baseUrl =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    final path = uri.path.isEmpty ? '/' : uri.path;

    return NetworkRecord(
      id: id,
      url: url,
      baseUrl: baseUrl,
      path: path,
      method: method,
      responseStatusCode: statusCode,
      status: status,
      durationMs: status == NetworkStatus.pending ? null : durationMs,
      requestTimestamp: now,
      responseTimestamp: status == NetworkStatus.pending
          ? null
          : now.add(Duration(milliseconds: durationMs)),
      requestHeaders: const {'Content-Type': 'application/json'},
      responseHeaders: const {'Content-Type': 'application/json'},
      requestBody: PayloadData(
        body: '{"query": "active"}',
        byteSize: requestBytes,
        bodyType: BodyType.json,
      ),
      responseBody: status == NetworkStatus.pending
          ? null
          : PayloadData(
              body: '{"users": [{"id": 1, "name": "Alice"}]}',
              byteSize: responseBytes,
              bodyType: BodyType.json,
            ),
      error: error,
    );
  }

  static NetworkRecord getSuccessRecord = createRecord(
    id: 'get-200',
    url: 'https://api.example.com/v1/users',
    method: 'GET',
    statusCode: 200,
    status: NetworkStatus.success,
    durationMs: 45,
  );

  static NetworkRecord postSuccessRecord = createRecord(
    id: 'post-201',
    url: 'https://api.example.com/v1/orders',
    method: 'POST',
    statusCode: 201,
    status: NetworkStatus.success,
    durationMs: 180,
  );

  static NetworkRecord clientErrorRecord = createRecord(
    id: 'client-404',
    url: 'https://api.example.com/v1/items/999',
    method: 'GET',
    statusCode: 404,
    status: NetworkStatus.success,
    durationMs: 82,
  );

  static NetworkRecord serverErrorRecord = createRecord(
    id: 'server-500',
    url: 'https://api.example.com/v1/checkout',
    method: 'POST',
    statusCode: 500,
    status: NetworkStatus.failed,
    durationMs: 310,
    error: const HttpErrorDetails(
      message: 'Internal Server Error',
      statusCode: 500,
    ),
  );

  static NetworkRecord pendingRecord = createRecord(
    id: 'pending-1',
    url: 'https://api.example.com/v1/upload',
    method: 'POST',
    statusCode: null,
    status: NetworkStatus.pending,
    durationMs: 0,
    responseBytes: 0,
  );

  static NetworkRecord socketFailedRecord = createRecord(
    id: 'socket-failed',
    url: 'https://unreachable.domain.org/data',
    method: 'GET',
    statusCode: null,
    status: NetworkStatus.failed,
    durationMs: 1500,
    error: const HttpErrorDetails(
      message: 'SocketException: OS Error: Connection refused',
      errorType: 'SocketException',
    ),
  );

  static List<NetworkRecord> generateRecords(int count) {
    final now = DateTime.now();
    return List.generate(count, (index) {
      final method =
          index % 3 == 0 ? 'POST' : (index % 3 == 1 ? 'GET' : 'DELETE');
      final statusCode = index % 5 == 0 ? 500 : 200;
      final status =
          statusCode == 500 ? NetworkStatus.failed : NetworkStatus.success;

      return NetworkRecord(
        id: 'rec-$index',
        url: 'https://api.example.com/items/$index',
        baseUrl: 'https://api.example.com',
        path: '/items/$index',
        method: method,
        responseStatusCode: statusCode,
        status: status,
        durationMs: 20 + index,
        requestTimestamp: now.subtract(Duration(minutes: index)),
        responseTimestamp: now
            .subtract(Duration(minutes: index))
            .add(Duration(milliseconds: 20 + index)),
        requestHeaders: const {},
        responseHeaders: const {},
      );
    });
  }
}
