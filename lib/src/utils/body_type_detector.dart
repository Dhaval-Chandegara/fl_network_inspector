import '../models/body_type.dart';

/// Utility that inspects MIME content types and payload body structures
/// to classify the payload format into a discrete [BodyType].
abstract final class BodyTypeDetector {
  const BodyTypeDetector._();

  /// Standard prefix for binary stream summaries.
  static const String binarySummaryPrefix = '[Binary data:';

  /// Detects the [BodyType] from the [body] text and declared [contentType].
  static BodyType detect({String? body, String? contentType}) {
    if (body == null || body.isEmpty) {
      return BodyType.empty;
    }

    final lowerMime = contentType?.toLowerCase() ?? '';

    // Check for binary content types or existing binary summary banner
    if (lowerMime.startsWith('image/') ||
        lowerMime.startsWith('video/') ||
        lowerMime.startsWith('audio/') ||
        lowerMime.contains('application/octet-stream') ||
        lowerMime.contains('application/pdf') ||
        lowerMime.contains('application/zip') ||
        lowerMime.contains('application/gzip') ||
        body.startsWith(binarySummaryPrefix)) {
      return BodyType.binary;
    }

    // Check for multipart form data
    if (lowerMime.contains('multipart/form-data')) {
      return BodyType.multipart;
    }

    // Check for url-encoded form data
    if (lowerMime.contains('application/x-www-form-urlencoded')) {
      return BodyType.formData;
    }

    // Check for JSON by MIME type
    if (lowerMime.contains('application/json')) {
      return BodyType.json;
    }

    final trimmed = body.trim();

    // Check for JSON by structural inspection
    if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
      return BodyType.json;
    }

    // Check for form URL encoded by key-value structure
    if (trimmed.contains('=') && !trimmed.contains('\n') && !trimmed.contains(' ')) {
      return BodyType.formData;
    }

    return BodyType.text;
  }
}
