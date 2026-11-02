import 'dart:async';
import 'dart:convert';

import 'package:flutter_network_inspector/src/interceptor/stream/stream_tap_transformer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StreamTapTransformer (INTC-03, D-41, D-43)', () {
    test('forwards byte chunks downstream synchronously while accumulating buffer', () async {
      final inputData = ['Hello ', 'World!', ' How are you?'];
      final inputBytes = inputData.map(utf8.encode).toList();

      List<int>? completedBytes;
      bool? wasTruncated;
      int? reportedTotalBytes;

      final transformer = createStreamTapTransformer(
        maxBodyBytes: 1024,
        isBinary: false,
        onComplete: (bytes, isTruncated, totalBytes) {
          completedBytes = bytes;
          wasTruncated = isTruncated;
          reportedTotalBytes = totalBytes;
        },
        onError: (_, __, ___, ____) {},
      );

      final stream = Stream<List<int>>.fromIterable(inputBytes).transform(transformer);

      // Downstream consumer reads stream
      final resultString = await stream.transform(utf8.decoder).join();

      expect(resultString, equals('Hello World! How are you?'));
      expect(completedBytes, isNotNull);
      expect(utf8.decode(completedBytes!), equals('Hello World! How are you?'));
      expect(wasTruncated, isFalse);
      expect(reportedTotalBytes, equals(utf8.encode('Hello World! How are you?').length));
    });

    test('truncates buffer at maxBodyBytes while streaming full content downstream', () async {
      // 50 bytes total
      final chunk1 = List.filled(20, 65); // 20 'A's
      final chunk2 = List.filled(20, 66); // 20 'B's
      final chunk3 = List.filled(10, 67); // 10 'C's

      List<int>? completedBytes;
      bool? wasTruncated;
      int? reportedTotalBytes;

      final transformer = createStreamTapTransformer(
        maxBodyBytes: 30, // Limit to 30 bytes
        isBinary: false,
        onComplete: (bytes, isTruncated, totalBytes) {
          completedBytes = bytes;
          wasTruncated = isTruncated;
          reportedTotalBytes = totalBytes;
        },
        onError: (_, __, ___, ____) {},
      );

      final stream = Stream.fromIterable([chunk1, chunk2, chunk3]).transform(transformer);

      // Downstream consumer receives all 50 bytes intact
      final allBytes = await stream.fold<List<int>>([], (prev, elem) => prev..addAll(elem));
      expect(allBytes.length, equals(50));

      // Inspector buffer is truncated at exactly 30 bytes
      expect(completedBytes?.length, equals(30));
      expect(wasTruncated, isTrue);
      expect(reportedTotalBytes, equals(50));

      // First 20 are 'A', next 10 are 'B'
      expect(completedBytes!.sublist(0, 20), equals(chunk1));
      expect(completedBytes!.sublist(20, 30), equals(chunk2.sublist(0, 10)));
    });

    test('handles stream error: forwards to sink and invokes onError with partial bytes', () async {
      final controller = StreamController<List<int>>();

      Object? capturedError;
      List<int>? capturedPartialBytes;
      int? capturedTotalBytes;

      final transformer = createStreamTapTransformer(
        maxBodyBytes: 1024,
        isBinary: false,
        onComplete: (_, __, ___) {},
        onError: (error, _, partialBytes, totalBytes) {
          capturedError = error;
          capturedPartialBytes = partialBytes;
          capturedTotalBytes = totalBytes;
        },
      );

      final transformedStream = controller.stream.transform(transformer);

      final receivedChunks = <List<int>>[];
      Object? consumerError;

      transformedStream.listen(
        receivedChunks.add,
        onError: (Object e) {
          consumerError = e;
        },
      );

      controller.add(utf8.encode('partial data before failure'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final testException = Exception('Socket aborted unexpectedly');
      controller.addError(testException);
      await controller.close();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(consumerError, equals(testException));
      expect(capturedError, equals(testException));
      expect(utf8.decode(capturedPartialBytes!), equals('partial data before failure'));
      expect(capturedTotalBytes, equals(utf8.encode('partial data before failure').length));
    });

    test('isBinary: true bypasses buffer accumulation and forwards bytes directly', () async {
      final binaryChunk1 = List.generate(50, (i) => i % 256);
      final binaryChunk2 = List.generate(50, (i) => (i + 50) % 256);

      List<int>? completedBytes;
      bool? wasTruncated;
      int? reportedTotalBytes;

      final transformer = createStreamTapTransformer(
        maxBodyBytes: 1024,
        isBinary: true,
        onComplete: (bytes, isTruncated, totalBytes) {
          completedBytes = bytes;
          wasTruncated = isTruncated;
          reportedTotalBytes = totalBytes;
        },
        onError: (_, __, ___, ____) {},
      );

      final stream = Stream.fromIterable([binaryChunk1, binaryChunk2]).transform(transformer);

      final consumerBytes = await stream.fold<List<int>>([], (prev, elem) => prev..addAll(elem));
      expect(consumerBytes.length, equals(100));

      // Buffer remains empty to prevent memory pressure
      expect(completedBytes, isEmpty);
      expect(wasTruncated, isFalse);
      expect(reportedTotalBytes, equals(100));
    });
  });
}
