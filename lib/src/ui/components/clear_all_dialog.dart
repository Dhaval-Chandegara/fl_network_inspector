import 'package:flutter/material.dart';

/// Material 3 confirmation dialog before permanently clearing captured network records (UI-06, D-28).
class ClearAllDialog extends StatelessWidget {
  const ClearAllDialog({super.key});

  /// Shows the [ClearAllDialog] and returns `true` if confirmed, or `false`/`null` if dismissed.
  static Future<bool?> show(BuildContext context, {ThemeData? theme}) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        const dialog = ClearAllDialog();
        return theme != null ? Theme(data: theme, child: dialog) : dialog;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Text(
        'Clear All Records',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: const Text(
        'Are you sure you want to permanently delete all captured network records? This action cannot be undone.',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Keep Records',
            style: TextStyle(
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(
            'Clear Records',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
