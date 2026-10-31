import 'package:flutter_network_inspector/src/models/http_error_details.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HttpErrorDetails', () {
    test('initializes with required message and optional fields', () {
      const error = HttpErrorDetails(
        message: 'Connection timed out',
        errorType: 'TimeoutException',
        statusCode: 408,
      );

      expect(error.message, equals('Connection timed out'));
      expect(error.errorType, equals('TimeoutException'));
      expect(error.statusCode, equals(408));
      expect(error.stackTrace, isNull);
    });

    test('copyWith updates fields as expected', () {
      const original = HttpErrorDetails(
        message: 'Internal server error',
        statusCode: 500,
      );

      final updated = original.copyWith(
        stackTrace: '#0 main.dart:42',
      );

      expect(updated.message, equals('Internal server error'));
      expect(updated.statusCode, equals(500));
      expect(updated.stackTrace, equals('#0 main.dart:42'));
      expect(original.stackTrace, isNull);
    });

    test('toMap and fromMap roundtrip preserves all error details', () {
      const original = HttpErrorDetails(
        message: 'SocketException: OS Error: Connection refused',
        errorType: 'SocketException',
        stackTrace: '#0 Client.send (client.dart:123)\n#1 main (main.dart:45)',
        statusCode: null,
      );

      final map = original.toMap();
      expect(map['message'], equals('SocketException: OS Error: Connection refused'));
      expect(map['error_type'], equals('SocketException'));
      expect(map['stack_trace'], contains('Client.send'));
      expect(map['status_code'], isNull);

      final restored = HttpErrorDetails.fromMap(map);
      expect(restored, equals(original));
    });

    test('supports value equality and hashCode', () {
      const a = HttpErrorDetails(message: 'err', errorType: 'e1', statusCode: 404);
      const b = HttpErrorDetails(message: 'err', errorType: 'e1', statusCode: 404);
      const c = HttpErrorDetails(message: 'err', errorType: 'e2', statusCode: 500);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });
}
