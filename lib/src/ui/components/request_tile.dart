import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/network_record.dart';
import '../../models/network_status.dart';
import 'status_badge.dart';

/// Material 3 Card list tile displaying captured HTTP request metadata (D-53, UI-01).
class RequestTile extends StatelessWidget {
  /// The captured network record model.
  final NetworkRecord record;

  /// Callback when the tile is tapped.
  final VoidCallback? onTap;

  static final DateFormat _timeFormat = DateFormat('HH:mm:ss');

  const RequestTile({
    super.key,
    required this.record,
    this.onTap,
  });

  String _formatUrlPath(String rawUrl) {
    try {
      final uri = Uri.parse(rawUrl);
      final path = uri.path.isEmpty ? '/' : uri.path;
      if (uri.hasQuery) {
        return '$path?${uri.query}';
      }
      return path;
    } catch (_) {
      return rawUrl;
    }
  }

  String _formatPayloadSize() {
    final reqBytes = record.requestBody?.byteSize ?? 0;
    final resBytes = record.responseBody?.byteSize ?? 0;
    final totalBytes = reqBytes + resBytes;
    if (totalBytes < 1024) {
      return '$totalBytes B';
    }
    return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = StatusBadge.getColor(
      statusCode: record.statusCode,
      status: record.status,
    );
    final urlPath = _formatUrlPath(record.url);
    final formattedTime = _timeFormat.format(record.timestamp);
    final sizeText = _formatPayloadSize();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top line: MethodBadge + StatusBadge + URL endpoint path
              Row(
                children: [
                  MethodBadge(method: record.method),
                  const SizedBox(width: 6),
                  StatusBadge(
                    statusCode: record.statusCode,
                    status: record.status,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      urlPath,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Second line: timestamp, duration, payload size, trailing dot
              Row(
                children: [
                  Text(
                    formattedTime,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: isDark
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                  if (record.status != NetworkStatus.pending &&
                      record.durationMs != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      '${record.durationMs} ms',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: isDark
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                  const SizedBox(width: 12),
                  Text(
                    sizeText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: isDark
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
