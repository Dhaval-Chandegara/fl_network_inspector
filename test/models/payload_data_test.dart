import 'package:fl_network_inspector/src/models/body_type.dart';
import 'package:fl_network_inspector/src/models/payload_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PayloadData', () {
    test('default constructor initializes empty values', () {
      const data = PayloadData();

      expect(data.body, isNull);
      expect(data.byteSize, equals(0));
      expect(data.bodyType, equals(BodyType.empty));
      expect(data.isTruncated, isFalse);
      expect(data.hasContent, isFalse);
    });

    test('static const empty matches default constructor', () {
      expect(PayloadData.empty, equals(const PayloadData()));
    });

    test('copyWith modifies selected fields and preserves others', () {
      const original = PayloadData(
        body: '{"status":"ok"}',
        byteSize: 15,
        bodyType: BodyType.json,
        isTruncated: false,
      );

      final modified = original.copyWith(
        isTruncated: true,
      );

      expect(modified.body, equals('{"status":"ok"}'));
      expect(modified.byteSize, equals(15));
      expect(modified.bodyType, equals(BodyType.json));
      expect(modified.isTruncated, isTrue);
      expect(original.isTruncated, isFalse);
    });

    test('toMap and fromMap roundtrip preserves all properties', () {
      const original = PayloadData(
        body: 'Hello World',
        byteSize: 11,
        bodyType: BodyType.text,
        isTruncated: true,
      );

      final map = original.toMap();
      expect(map['body'], equals('Hello World'));
      expect(map['byte_size'], equals(11));
      expect(map['body_type'], equals('text'));
      expect(map['is_truncated'], equals(1));

      final restored = PayloadData.fromMap(map);
      expect(restored, equals(original));
    });

    test('fromMap handles bool, int, and string is_truncated variations', () {
      final fromBool = PayloadData.fromMap(const {'is_truncated': true, 'byte_size': 100});
      expect(fromBool.isTruncated, isTrue);

      final fromInt = PayloadData.fromMap(const {'is_truncated': 1, 'byte_size': 100});
      expect(fromInt.isTruncated, isTrue);

      final fromString = PayloadData.fromMap(const {'is_truncated': 'true', 'byte_size': 100});
      expect(fromString.isTruncated, isTrue);

      final fromZero = PayloadData.fromMap(const {'is_truncated': 0, 'byte_size': 100});
      expect(fromZero.isTruncated, isFalse);
    });

    test('supports value equality and hashCode', () {
      const a = PayloadData(body: 'data', byteSize: 4, bodyType: BodyType.text);
      const b = PayloadData(body: 'data', byteSize: 4, bodyType: BodyType.text);
      const c = PayloadData(body: 'different', byteSize: 9, bodyType: BodyType.text);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('BodyType Enum', () {
    test('contains all 6 required discrete types', () {
      expect(BodyType.values, containsAll([
        BodyType.json,
        BodyType.text,
        BodyType.formData,
        BodyType.multipart,
        BodyType.binary,
        BodyType.empty,
      ]));
    });

    test('fromString parses case-insensitively and falls back to text or empty', () {
      expect(BodyType.fromString('json'), equals(BodyType.json));
      expect(BodyType.fromString('JSON'), equals(BodyType.json));
      expect(BodyType.fromString('formData'), equals(BodyType.formData));
      expect(BodyType.fromString('FORMDATA'), equals(BodyType.formData));
      expect(BodyType.fromString(null), equals(BodyType.empty));
      expect(BodyType.fromString(''), equals(BodyType.empty));
      expect(BodyType.fromString('unknown_type'), equals(BodyType.text));
    });
  });
}
