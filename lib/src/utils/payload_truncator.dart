import 'dart:convert';

import '../models/body_type.dart';
import '../models/payload_data.dart';
import 'body_type_detector.dart';

/// Utility providing memory-safe byte-bounded payload truncation and binary summarization.
///
/// Prevents Out-Of-Memory (OOM) vulnerabilities from unbounded payload buffering (D-02)
/// and handles multi-byte UTF-8 boundary slicing without FormatException crashes (D-13).
abstract final class PayloadTruncator {
  const PayloadTruncator._();

  /// Formats an informational summary for binary content streams (D-14).
  static String formatBinarySummary(String mimeType, int sizeBytes) {
    return '[Binary data: $mimeType, $sizeBytes bytes]';
  }

  /// Formats the truncation indicator appended to oversized payloads (D-13).
  static String formatTruncationBanner(int maxBytes) {
    return '\n\n[Payload truncated at $maxBytes bytes]';
  }

  /// Truncates a [body] string if its UTF-8 encoded byte size exceeds [maxBytes].
  static PayloadData truncate({
    required String? body,
    required String? contentType,
    required int maxBytes,
  }) {
    if (body == null || body.isEmpty) {
      return const PayloadData();
    }

    final lowerMime = contentType?.toLowerCase() ?? '';

    // Handle binary streams without keeping raw binary buffers in memory (D-14)
    if (_isBinaryMime(lowerMime) && !body.startsWith(BodyTypeDetector.binarySummaryPrefix)) {
      final originalBytes = utf8.encode(body);
      final summary = formatBinarySummary(
        contentType ?? 'application/octet-stream',
        originalBytes.length,
      );
      return PayloadData(
        body: summary,
        byteSize: originalBytes.length,
        bodyType: BodyType.binary,
        isTruncated: false,
      );
    }

    final bytes = utf8.encode(body);
    final originalSize = bytes.length;
    final detectedType = BodyTypeDetector.detect(body: body, contentType: contentType);

    if (originalSize <= maxBytes) {
      return PayloadData(
        body: body,
        byteSize: originalSize,
        bodyType: detectedType,
        isTruncated: false,
      );
    }

    // Slice bytes cleanly at the ceiling limit
    final slicedBytes = bytes.sublist(0, maxBytes);

    // Safely decode with allowMalformed: true to avoid crashes when cutting mid-codepoint
    final decodedText = utf8.decode(slicedBytes, allowMalformed: true);
    final truncatedBody = '$decodedText${formatTruncationBanner(maxBytes)}';

    return PayloadData(
      body: truncatedBody,
      byteSize: originalSize,
      bodyType: detectedType,
      isTruncated: true,
    );
  }

  /// Truncates raw [bytes] safely and converts to [PayloadData].
  static PayloadData truncateBytes({
    required List<int>? bytes,
    required String? contentType,
    required int maxBytes,
  }) {
    if (bytes == null || bytes.isEmpty) {
      return const PayloadData();
    }

    final totalSize = bytes.length;
    final lowerMime = contentType?.toLowerCase() ?? '';

    if (_isBinaryMime(lowerMime)) {
      final summary = formatBinarySummary(
        contentType ?? 'application/octet-stream',
        totalSize,
      );
      return PayloadData(
        body: summary,
        byteSize: totalSize,
        bodyType: BodyType.binary,
        isTruncated: false,
      );
    }

    final bool isTruncated = totalSize > maxBytes;
    final slice = isTruncated ? bytes.sublist(0, maxBytes) : bytes;
    final decodedText = utf8.decode(slice, allowMalformed: true);
    final finalBody = isTruncated ? '$decodedText${formatTruncationBanner(maxBytes)}' : decodedText;

    return PayloadData(
      body: finalBody,
      byteSize: totalSize,
      bodyType: BodyTypeDetector.detect(body: finalBody, contentType: contentType),
      isTruncated: isTruncated,
    );
  }

  static bool _isBinaryMime(String mime) {
    return mime.startsWith('image/') ||
        mime.startsWith('video/') ||
        mime.startsWith('audio/') ||
        mime.contains('application/octet-stream') ||
        mime.contains('application/pdf') ||
        mime.contains('application/zip') ||
        mime.contains('application/gzip');
  }
}
