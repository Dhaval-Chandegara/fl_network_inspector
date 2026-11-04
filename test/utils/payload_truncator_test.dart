import 'dart:convert';

import 'package:fl_network_inspector/src/models/body_type.dart';
import 'package:fl_network_inspector/src/utils/body_type_detector.dart';
import 'package:fl_network_inspector/src/utils/payload_truncator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BodyTypeDetector', () {
    test('detects empty payload for null or empty body', () {
      expect(BodyTypeDetector.detect(body: null), equals(BodyType.empty));
      expect(BodyTypeDetector.detect(body: ''), equals(BodyType.empty));
    });

    test('detects json via MIME type or structural brackets', () {
      expect(
        BodyTypeDetector.detect(
            body: '{"a":1}', contentType: 'application/json'),
        equals(BodyType.json),
      );
      expect(
        BodyTypeDetector.detect(body: '{"a":1}'),
        equals(BodyType.json),
      );
      expect(
        BodyTypeDetector.detect(body: '[1, 2, 3]'),
        equals(BodyType.json),
      );
    });

    test('detects formData via MIME or key-value pattern', () {
      expect(
        BodyTypeDetector.detect(
          body: 'username=alice&password=secret',
          contentType: 'application/x-www-form-urlencoded',
        ),
        equals(BodyType.formData),
      );
      expect(
        BodyTypeDetector.detect(body: 'key=value&foo=bar'),
        equals(BodyType.formData),
      );
    });

    test('detects multipart via MIME', () {
      expect(
        BodyTypeDetector.detect(
          body: '--boundary\ncontent',
          contentType: 'multipart/form-data; boundary=boundary',
        ),
        equals(BodyType.multipart),
      );
    });

    test('detects binary via MIME or summary prefix', () {
      expect(
        BodyTypeDetector.detect(body: 'data', contentType: 'image/png'),
        equals(BodyType.binary),
      );
      expect(
        BodyTypeDetector.detect(body: 'data', contentType: 'application/pdf'),
        equals(BodyType.binary),
      );
      expect(
        BodyTypeDetector.detect(body: '[Binary data: image/png, 1024 bytes]'),
        equals(BodyType.binary),
      );
    });

    test('falls back to text for general string content', () {
      expect(
        BodyTypeDetector.detect(body: 'Hello world', contentType: 'text/plain'),
        equals(BodyType.text),
      );
    });
  });

  group('PayloadTruncator', () {
    test('returns empty PayloadData when body is null or empty', () {
      final resNull = PayloadTruncator.truncate(
        body: null,
        contentType: 'application/json',
        maxBytes: 1000,
      );
      expect(resNull.body, isNull);
      expect(resNull.byteSize, equals(0));
      expect(resNull.isTruncated, isFalse);
      expect(resNull.bodyType, equals(BodyType.empty));

      final resEmpty = PayloadTruncator.truncate(
        body: '',
        contentType: null,
        maxBytes: 1000,
      );
      expect(resEmpty.body, isNull);
      expect(resEmpty.isTruncated, isFalse);
    });

    test('preserves payload when below maxBytes ceiling', () {
      const payload = '{"status":"ok"}';
      final res = PayloadTruncator.truncate(
        body: payload,
        contentType: 'application/json',
        maxBytes: 100,
      );

      expect(res.body, equals(payload));
      expect(res.byteSize, equals(utf8.encode(payload).length));
      expect(res.isTruncated, isFalse);
      expect(res.bodyType, equals(BodyType.json));
    });

    test('truncates oversized payload and appends banner per D-13', () {
      final largeString = 'A' * 200;
      final res = PayloadTruncator.truncate(
        body: largeString,
        contentType: 'text/plain',
        maxBytes: 50,
      );

      expect(res.isTruncated, isTrue);
      expect(res.byteSize, equals(200));
      expect(res.body, contains('[Payload truncated at 50 bytes]'));
      expect(res.body!.startsWith('A' * 50), isTrue);
      expect(
          res.body, equals('${"A" * 50}\n\n[Payload truncated at 50 bytes]'));
    });

    test(
        'handles mid-codepoint slicing on multi-byte UTF-8 safely without FormatException',
        () {
      // Emojis are 4-byte UTF-8 sequences.
      // 🚀 is [0xF0, 0x9F, 0x9A, 0x80] (4 bytes)
      final emojiString = '🚀' * 20; // 80 bytes
      expect(utf8.encode(emojiString).length, equals(80));

      // Slicing at 5 bytes cuts the second emoji mid-sequence (byte 1 of 4)
      final res = PayloadTruncator.truncate(
        body: emojiString,
        contentType: 'text/plain',
        maxBytes: 5,
      );

      expect(res.isTruncated, isTrue);
      expect(res.byteSize, equals(80));
      expect(res.body, contains('[Payload truncated at 5 bytes]'));
      // Does not throw FormatException
    });

    test('produces binary summary banner for binary content per D-14', () {
      const rawImageBytes = 'PNG_MAGIC_BYTES_12345';
      final res = PayloadTruncator.truncate(
        body: rawImageBytes,
        contentType: 'image/png',
        maxBytes: 1000,
      );

      expect(res.bodyType, equals(BodyType.binary));
      expect(res.isTruncated, isFalse);
      expect(res.body, contains('[Binary data: image/png, '));
      expect(res.body, contains('bytes]'));
    });

    test('truncateBytes handles raw byte streams and enforces limits', () {
      final bytes = List<int>.generate(100, (i) => i % 256);
      final res = PayloadTruncator.truncateBytes(
        bytes: bytes,
        contentType: 'application/octet-stream',
        maxBytes: 50,
      );

      expect(res.bodyType, equals(BodyType.binary));
      expect(res.byteSize, equals(100));
      expect(res.body,
          equals('[Binary data: application/octet-stream, 100 bytes]'));
    });
  });
}
