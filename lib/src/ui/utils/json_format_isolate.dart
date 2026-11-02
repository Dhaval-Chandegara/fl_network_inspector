import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Top-level worker function executed in an isolate via [compute] (D-58, D-59).
String formatJsonIsolate(String rawJson) {
  try {
    final dynamic decoded = jsonDecode(rawJson);
    return const JsonEncoder.withIndent('  ').convert(decoded);
  } catch (_) {
    return rawJson;
  }
}

/// Formats a raw JSON string with 2-space indentation, offloading to a background
/// isolate via [compute] if payload exceeds 50KB to preserve 60fps responsiveness (UI-08, D-59).
Future<String> formatJsonBody(String rawJson) async {
  if (rawJson.length > 50 * 1024) {
    try {
      return await compute(formatJsonIsolate, rawJson);
    } catch (_) {
      return formatJsonIsolate(rawJson);
    }
  }
  return formatJsonIsolate(rawJson);
}
