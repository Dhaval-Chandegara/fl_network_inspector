import 'package:flutter/material.dart';

import '../../models/network_record.dart';
import '../utils/share_exporter.dart';

/// Modal bottom sheet allowing developers to export network records in multiple formats (UI-11, D-62, D-63).
class ExportActionSheet extends StatefulWidget {
  final NetworkRecord record;
  final Rect? anchorOrigin;

  const ExportActionSheet({
    super.key,
    required this.record,
    this.anchorOrigin,
  });

  /// Displays the [ExportActionSheet] in a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required NetworkRecord record,
    Rect? anchorOrigin,
    ThemeData? theme,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final content = ExportActionSheet(
          record: record,
          anchorOrigin: anchorOrigin,
        );
        return theme != null ? Theme(data: theme, child: content) : content;
      },
    );
  }

  @override
  State<ExportActionSheet> createState() => _ExportActionSheetState();
}

class _ExportActionSheetState extends State<ExportActionSheet> {
  bool _excludeHeaders = false;

  Future<void> _handleShare(ShareFormat format) async {
    final origin =
        widget.anchorOrigin ?? ShareExporter.calculateAnchor(context);
    Navigator.of(context).pop();

    await ShareExporter.shareRecord(
      context: context,
      record: widget.record,
      format: format,
      excludeHeaders: _excludeHeaders,
      sharePositionOrigin: origin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryTextColor =
        isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
    final secondaryTextColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);

    return Material(
      color: backgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF4B5563)
                        : const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Share Request Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: primaryTextColor,
                  ),
                ),
              ),

              const Divider(height: 1),

              // Exclude Headers Toggle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Material(
                  color: isDark
                      ? const Color(0xFF2C2C2C)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                  child: CheckboxListTile(
                    value: _excludeHeaders,
                    onChanged: (val) {
                      setState(() {
                        _excludeHeaders = val ?? false;
                      });
                    },
                    title: Text(
                      'Exclude all headers',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: primaryTextColor,
                      ),
                    ),
                    subtitle: Text(
                      'Redacts authorization tokens and private headers before sharing',
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor,
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.trailing,
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Option 1: Markdown Summary
              ListTile(
                leading: const Icon(
                  Icons.description_rounded,
                  color: Color(0xFF2563EB),
                ),
                title: Text(
                  'Share as Markdown Summary',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: primaryTextColor,
                  ),
                ),
                subtitle: Text(
                  'Formatted report with headers, parameters, and bodies',
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryTextColor,
                  ),
                ),
                onTap: () => _handleShare(ShareFormat.markdown),
              ),

              // Option 2: cURL Command
              ListTile(
                leading: const Icon(
                  Icons.terminal_rounded,
                  color: Color(0xFF10B981),
                ),
                title: Text(
                  'Share as cURL Command',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: primaryTextColor,
                  ),
                ),
                subtitle: Text(
                  'Bash-reproducible CLI command for terminal execution',
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryTextColor,
                  ),
                ),
                onTap: () => _handleShare(ShareFormat.curl),
              ),

              // Option 3: Full JSON
              ListTile(
                leading: const Icon(
                  Icons.data_object_rounded,
                  color: Color(0xFF8B5CF6),
                ),
                title: Text(
                  'Share as Full JSON',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: primaryTextColor,
                  ),
                ),
                subtitle: Text(
                  'Structured JSON record for programmatic ingestion',
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryTextColor,
                  ),
                ),
                onTap: () => _handleShare(ShareFormat.json),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
