import 'dart:convert';

import '../core/constants.dart';

/// Engine responsible for sanitizing sensitive data (passwords, tokens, credentials)
/// across HTTP headers, URL query parameters, and payload bodies (D-09).
class RedactionEngine {
  final Set<String> _normalizedSensitiveKeys;

  /// Creates a [RedactionEngine] with default sensitive keys and optional [customKeys].
  RedactionEngine({List<String> customKeys = const []})
      : _normalizedSensitiveKeys = {
          for (final key in NetworkInspectorConstants.defaultSensitiveKeys)
            normalizeKey(key),
          for (final key in customKeys) normalizeKey(key),
        };

  /// Normalizes a key for case- and delimiter-insensitive matching (D-11).
  ///
  /// Removes hyphens, underscores, dots, and converts to lowercase.
  /// Examples:
  /// - `api_key` -> `apikey`
  /// - `API-KEY` -> `apikey`
  /// - `apiKey`  -> `apikey`
  /// - `auth.token` -> `authtoken`
  static String normalizeKey(String key) {
    return key.toLowerCase().replaceAll(RegExp(r'[-_.]'), '');
  }

  /// Checks whether [key] matches any configured sensitive key.
  bool isSensitive(String key) {
    return _normalizedSensitiveKeys.contains(normalizeKey(key));
  }

  /// Redacts sensitive values in HTTP headers (D-09, D-12).
  Map<String, dynamic> redactHeaders(Map<String, dynamic> headers) {
    if (headers.isEmpty) return headers;

    final sanitized = <String, dynamic>{};
    for (final entry in headers.entries) {
      if (isSensitive(entry.key)) {
        sanitized[entry.key] = NetworkInspectorConstants.redactedPlaceholder;
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    return sanitized;
  }

  /// Redacts sensitive values in query parameters.
  Map<String, dynamic> redactQueryParams(Map<String, dynamic> params) {
    if (params.isEmpty) return params;

    final sanitized = <String, dynamic>{};
    for (final entry in params.entries) {
      if (isSensitive(entry.key)) {
        sanitized[entry.key] = NetworkInspectorConstants.redactedPlaceholder;
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    return sanitized;
  }

  /// Redacts sensitive query parameters embedded within a full [rawUrl].
  ///
  /// Uses URI parsing to safely reconstruct the URL without corrupting
  /// path encoding or fragment identifiers.
  String redactUrl(String rawUrl) {
    if (rawUrl.isEmpty) return rawUrl;

    try {
      final uri = Uri.parse(rawUrl);
      if (!uri.hasQuery) return rawUrl;

      bool modified = false;
      final updatedQuery = <String, dynamic>{};

      for (final entry in uri.queryParametersAll.entries) {
        if (isSensitive(entry.key)) {
          updatedQuery[entry.key] = NetworkInspectorConstants.redactedPlaceholder;
          modified = true;
        } else {
          updatedQuery[entry.key] = entry.value.length == 1 ? entry.value.first : entry.value;
        }
      }

      if (!modified) return rawUrl;
      return uri.replace(queryParameters: updatedQuery).toString();
    } catch (_) {
      // If URL parsing fails, return raw string to avoid breaking network streams
      return rawUrl;
    }
  }

  /// Redacts sensitive values from JSON and form URL-encoded bodies (D-10).
  ///
  /// Deeply inspects nested JSON maps and arrays at arbitrary nesting depths.
  String? redactBody(String? body, String? contentType) {
    if (body == null || body.trim().isEmpty) {
      return body;
    }

    final trimmed = body.trim();

    // 1. Attempt deep recursive JSON redaction
    if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']')) ||
        (contentType != null && contentType.toLowerCase().contains('application/json'))) {
      try {
        final decoded = jsonDecode(trimmed);
        final redactedJson = _redactRecursive(decoded);
        return jsonEncode(redactedJson);
      } catch (_) {
        // Fall through to other handlers if JSON parsing fails
      }
    }

    // 2. Attempt form URL-encoded redaction
    final lowerMime = contentType?.toLowerCase() ?? '';
    if (lowerMime.contains('application/x-www-form-urlencoded') ||
        (trimmed.contains('=') && !trimmed.contains('\n') && !trimmed.contains(' '))) {
      return _redactFormUrlEncoded(trimmed);
    }

    return body;
  }

  /// Recursively traverses JSON structures (Maps and Lists) to redact sensitive keys (D-10).
  dynamic _redactRecursive(dynamic node) {
    if (node is Map) {
      final sanitizedMap = <String, dynamic>{};
      for (final entry in node.entries) {
        final keyStr = entry.key.toString();
        if (isSensitive(keyStr)) {
          sanitizedMap[keyStr] = NetworkInspectorConstants.redactedPlaceholder;
        } else {
          sanitizedMap[keyStr] = _redactRecursive(entry.value);
        }
      }
      return sanitizedMap;
    } else if (node is List) {
      return node.map((element) => _redactRecursive(element)).toList();
    }
    return node;
  }

  /// Redacts key-value pairs in form URL-encoded strings.
  String _redactFormUrlEncoded(String formString) {
    final pairs = formString.split('&');
    final sanitizedPairs = <String>[];

    for (final pair in pairs) {
      final equalIndex = pair.indexOf('=');
      if (equalIndex == -1) {
        sanitizedPairs.add(pair);
        continue;
      }

      final keyPart = pair.substring(0, equalIndex);
      final rawKey = Uri.decodeQueryComponent(keyPart);

      if (isSensitive(rawKey)) {
        sanitizedPairs.add('$keyPart=${Uri.encodeQueryComponent(NetworkInspectorConstants.redactedPlaceholder)}');
      } else {
        sanitizedPairs.add(pair);
      }
    }

    return sanitizedPairs.join('&');
  }
}
