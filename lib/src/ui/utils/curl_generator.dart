import '../../core/constants.dart';
import '../../models/network_record.dart';

/// Generates terminal-executable bash cURL commands with single-quote escaping (UI-10, D-61).
class CurlGenerator {
  const CurlGenerator._();

  /// Formats a [NetworkRecord] into a multi-line, bash-safe cURL command.
  ///
  /// Set [includeHeaders] to `false` to omit request headers (e.g. for privacy).
  static String fromRecord(NetworkRecord record, {bool includeHeaders = true}) {
    final buffer = StringBuffer();
    buffer.write("curl -X ${record.method.toUpperCase()} \\\n  '${_escapeBash(record.url)}'");

    if (includeHeaders) {
      for (final entry in record.requestHeaders.entries) {
        final key = entry.key;
        final lowerKey = key.toLowerCase();
        // Omit HTTP/2 pseudo-headers and internal inspector correlation headers
        if (key.startsWith(':') ||
            lowerKey == NetworkInspectorConstants.internalTrackingHeader.toLowerCase() ||
            lowerKey == NetworkInspectorConstants.headerInspectorId.toLowerCase()) {
          continue;
        }
        final value = entry.value?.toString() ?? '';
        buffer.write(" \\\n  -H '${_escapeBash(key)}: ${_escapeBash(value)}'");
      }
    }

    final body = record.requestBody?.body;
    if (body != null && body.isNotEmpty) {
      buffer.write(" \\\n  --data-raw '${_escapeBash(body)}'");
    }

    return buffer.toString();
  }

  /// Escapes single quotes for safe bash wrapping by replacing `'` with `'\''`.
  static String _escapeBash(String input) {
    return input.replaceAll("'", r"'\''");
  }
}
