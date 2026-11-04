import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/network_record.dart';
import 'curl_generator.dart';

/// Formats available for exporting network records (UI-11, D-62).
enum ShareFormat {
  /// Structured Markdown document with request/response summaries and code fences.
  markdown,

  /// Bash-executable cURL command with line continuations and safe escaping.
  curl,

  /// Formatted JSON payload containing record properties.
  json,
}

/// Signature for delegating share calls (useful for mocking in unit/widget tests).
typedef ShareDelegate = Future<void> Function(
  String text, {
  String? subject,
  Rect? sharePositionOrigin,
});

/// Utility for exporting network records in multiple formats with safe iPadOS anchor geometry (UI-11, D-62, D-63, D-64).
class ShareExporter {
  const ShareExporter._();

  /// Mock delegate used for testing share dispatches.
  @visibleForTesting
  static ShareDelegate? mockShareDelegate;

  /// Safely calculates a [Rect] anchor origin from [context] to prevent iPadOS/macOS popover crashes (D-64).
  ///
  /// Falls back to the center of the screen if the widget's [RenderBox] is not attached or has no size.
  static Rect calculateAnchor(BuildContext context) {
    try {
      final renderObject = context.findRenderObject();
      if (renderObject is RenderBox &&
          renderObject.hasSize &&
          renderObject.attached) {
        return renderObject.localToGlobal(Offset.zero) & renderObject.size;
      }
    } catch (_) {
      // Fallback to screen center
    }

    try {
      final size = MediaQuery.sizeOf(context);
      return size.center(Offset.zero) & const Size(1, 1);
    } catch (_) {
      return const Rect.fromLTWH(0, 0, 1, 1);
    }
  }

  /// Formats [record] as a structured Markdown document.
  static String formatMarkdown(NetworkRecord record,
      {bool excludeHeaders = false}) {
    final buffer = StringBuffer();
    buffer.writeln('# Network Request Inspection');
    buffer.writeln();
    buffer.writeln('- **Method**: ${record.method}');
    buffer.writeln('- **URL**: ${record.url}');
    buffer.writeln('- **Status**: ${record.responseStatusCode ?? 'In-Flight'}');
    if (record.durationMs != null) {
      buffer.writeln('- **Duration**: ${record.durationMs} ms');
    }
    buffer.writeln(
        '- **Timestamp**: ${record.requestTimestamp.toIso8601String()}');
    buffer.writeln();

    if (!excludeHeaders) {
      buffer.writeln('## Request Headers');
      if (record.requestHeaders.isEmpty) {
        buffer.writeln('*(none)*');
      } else {
        record.requestHeaders.forEach((k, v) {
          buffer.writeln('- `$k`: $v');
        });
      }
      buffer.writeln();
    }

    if (record.requestBody != null && record.requestBody!.hasContent) {
      buffer.writeln('## Request Body');
      buffer.writeln('```');
      buffer.writeln(record.requestBody!.body);
      buffer.writeln('```');
      buffer.writeln();
    }

    if (!excludeHeaders && record.responseHeaders != null) {
      buffer.writeln('## Response Headers');
      if (record.responseHeaders!.isEmpty) {
        buffer.writeln('*(none)*');
      } else {
        record.responseHeaders!.forEach((k, v) {
          buffer.writeln('- `$k`: $v');
        });
      }
      buffer.writeln();
    }

    if (record.responseBody != null && record.responseBody!.hasContent) {
      buffer.writeln('## Response Body');
      buffer.writeln('```');
      buffer.writeln(record.responseBody!.body);
      buffer.writeln('```');
      buffer.writeln();
    }

    if (record.error != null) {
      buffer.writeln('## Error Details');
      buffer.writeln('- **Type**: ${record.error!.errorType}');
      buffer.writeln('- **Message**: ${record.error!.message}');
      if (record.error!.stackTrace != null) {
        buffer.writeln('```');
        buffer.writeln(record.error!.stackTrace);
        buffer.writeln('```');
      }
      buffer.writeln();
    }

    return buffer.toString().trim();
  }

  /// Formats [record] into a terminal-executable cURL command.
  static String formatCurl(NetworkRecord record,
      {bool excludeHeaders = false}) {
    return CurlGenerator.fromRecord(record, includeHeaders: !excludeHeaders);
  }

  /// Formats [record] into a pretty-printed JSON document.
  ///
  /// Strips `'request_headers'` and `'response_headers'` when [excludeHeaders] is `true`.
  static String formatJson(NetworkRecord record,
      {bool excludeHeaders = false}) {
    final rawMap = record.toMap();
    final map = <String, dynamic>{};

    for (final entry in rawMap.entries) {
      if (excludeHeaders &&
          (entry.key == 'request_headers' ||
              entry.key == 'response_headers' ||
              entry.key == 'requestHeaders' ||
              entry.key == 'responseHeaders')) {
        continue;
      }
      final value = entry.value;
      if (value is String && (value.startsWith('{') || value.startsWith('['))) {
        try {
          map[entry.key] = jsonDecode(value);
          continue;
        } catch (_) {}
      }
      map[entry.key] = value;
    }

    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// Exports [record] via native OS share sheet using the specified [format].
  static Future<void> shareRecord({
    required BuildContext context,
    required NetworkRecord record,
    required ShareFormat format,
    bool excludeHeaders = false,
    Rect? sharePositionOrigin,
  }) async {
    final String text;
    switch (format) {
      case ShareFormat.markdown:
        text = formatMarkdown(record, excludeHeaders: excludeHeaders);
        break;
      case ShareFormat.curl:
        text = formatCurl(record, excludeHeaders: excludeHeaders);
        break;
      case ShareFormat.json:
        text = formatJson(record, excludeHeaders: excludeHeaders);
        break;
    }

    final origin = sharePositionOrigin ?? calculateAnchor(context);
    final statusStr = record.responseStatusCode != null
        ? '${record.responseStatusCode}'
        : 'In-Flight';
    final subject = '${record.method} ${record.path} ($statusStr)';

    if (mockShareDelegate != null) {
      await mockShareDelegate!(
        text,
        subject: subject,
        sharePositionOrigin: origin,
      );
      return;
    }

    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: subject,
        sharePositionOrigin: origin,
      ),
    );
  }
}
