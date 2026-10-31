import 'package:flutter_network_inspector/src/models/multipart_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MultipartEntry', () {
    test('enforces null filePath default for privacy (D-15)', () {
      const entry = MultipartEntry(
        fieldName: 'avatar',
        fileName: 'profile.jpg',
        contentType: 'image/jpeg',
        byteSize: 20480,
      );

      expect(entry.filePath, isNull, reason: 'filePath must be null by default per D-15');
      expect(entry.fieldName, equals('avatar'));
      expect(entry.fileName, equals('profile.jpg'));
      expect(entry.contentType, equals('image/jpeg'));
      expect(entry.byteSize, equals(20480));
    });

    test('copyWith preserves or updates properties correctly', () {
      const original = MultipartEntry(
        fieldName: 'document',
        fileName: 'report.pdf',
        byteSize: 1024,
      );

      final withPath = original.copyWith(filePath: '/tmp/report.pdf');
      expect(withPath.filePath, equals('/tmp/report.pdf'));
      expect(withPath.fileName, equals('report.pdf'));
      expect(original.filePath, isNull);
    });

    test('toMap and fromMap roundtrip preserves all fields', () {
      const original = MultipartEntry(
        fieldName: 'attachment',
        fileName: 'receipt.png',
        contentType: 'image/png',
        byteSize: 4096,
        filePath: '/storage/receipt.png',
      );

      final map = original.toMap();
      expect(map['field_name'], equals('attachment'));
      expect(map['file_name'], equals('receipt.png'));
      expect(map['content_type'], equals('image/png'));
      expect(map['byte_size'], equals(4096));
      expect(map['file_path'], equals('/storage/receipt.png'));

      final restored = MultipartEntry.fromMap(map);
      expect(restored, equals(original));
    });

    test('supports value equality and hashCode', () {
      const a = MultipartEntry(fieldName: 'f', fileName: 'a.txt', byteSize: 10);
      const b = MultipartEntry(fieldName: 'f', fileName: 'a.txt', byteSize: 10);
      const c = MultipartEntry(fieldName: 'f', fileName: 'b.txt', byteSize: 20);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });
}
