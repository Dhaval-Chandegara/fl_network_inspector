import 'package:fl_network_inspector/fl_network_inspector.dart';
import 'package:fl_network_inspector/src/ui/utils/curl_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CurlGenerator', () {
    test('generates basic GET request with URL and headers', () {
      final record = NetworkRecord(
        id: 'test-1',
        url: 'https://api.example.com/users',
        baseUrl: 'https://api.example.com',
        path: '/users',
        method: 'GET',
        requestHeaders: const {
          'Accept': 'application/json',
          'User-Agent': 'FlutterInspector/1.0',
        },
        requestTimestamp: DateTime.now(),
        status: NetworkStatus.success,
      );

      final curl = CurlGenerator.fromRecord(record);

      expect(
        curl,
        "curl -X GET \\\n"
        "  'https://api.example.com/users' \\\n"
        "  -H 'Accept: application/json' \\\n"
        "  -H 'User-Agent: FlutterInspector/1.0'",
      );
    });

    test('generates POST request with JSON body and line continuations', () {
      final record = NetworkRecord(
        id: 'test-2',
        url: 'https://api.example.com/login',
        baseUrl: 'https://api.example.com',
        path: '/login',
        method: 'POST',
        requestHeaders: const {
          'Content-Type': 'application/json',
        },
        requestBody: const PayloadData(
          body: '{"username":"alice","password":"[REDACTED]"}',
          bodyType: BodyType.json,
          byteSize: 45,
        ),
        requestTimestamp: DateTime.now(),
        status: NetworkStatus.success,
      );

      final curl = CurlGenerator.fromRecord(record);

      expect(
        curl,
        "curl -X POST \\\n"
        "  'https://api.example.com/login' \\\n"
        "  -H 'Content-Type: application/json' \\\n"
        "  --data-raw '{\"username\":\"alice\",\"password\":\"[REDACTED]\"}'",
      );
    });

    test('escapes single quotes in URL, headers, and body with bash sequence', () {
      final record = NetworkRecord(
        id: 'test-3',
        url: "https://api.example.com/search?q=alice's",
        baseUrl: 'https://api.example.com',
        path: '/search',
        method: 'POST',
        requestHeaders: const {
          "X-User's-Token": "secret'token",
        },
        requestBody: const PayloadData(
          body: "{\"message\":\"It's a test's payload\"}",
          bodyType: BodyType.json,
          byteSize: 36,
        ),
        requestTimestamp: DateTime.now(),
        status: NetworkStatus.success,
      );

      final curl = CurlGenerator.fromRecord(record);

      // Verify single quotes are escaped as '\''
      expect(curl, contains(r"https://api.example.com/search?q=alice'\''s"));
      expect(curl, contains(r"-H 'X-User'\''s-Token: secret'\''token'"));
      expect(curl, contains(r"--data-raw '{" '"message":"It' r"'\''" 's a test' r"'\''" 's payload"}' r"'"));
    });

    test('omits HTTP/2 pseudo-headers and internal tracking headers', () {
      final record = NetworkRecord(
        id: 'test-4',
        url: 'https://api.example.com/data',
        baseUrl: 'https://api.example.com',
        path: '/data',
        method: 'GET',
        requestHeaders: const {
          ':method': 'GET',
          ':path': '/data',
          ':authority': 'api.example.com',
          'x-fl-net-inspector-tracked-id': 'uuid-1234',
          'x-network-inspector-id': 'uuid-5678',
          'Authorization': 'Bearer [REDACTED]',
        },
        requestTimestamp: DateTime.now(),
        status: NetworkStatus.success,
      );

      final curl = CurlGenerator.fromRecord(record);

      expect(curl, isNot(contains(':method')));
      expect(curl, isNot(contains(':path')));
      expect(curl, isNot(contains(':authority')));
      expect(curl, isNot(contains('x-fl-net-inspector-tracked-id')));
      expect(curl, isNot(contains('x-network-inspector-id')));
      expect(curl, contains("-H 'Authorization: Bearer [REDACTED]'"));
    });
  });
}
