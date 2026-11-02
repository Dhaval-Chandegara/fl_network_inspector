import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Compact copy button that copies text to the system clipboard with SnackBar confirmation (UI-09, D-60).
class CopyButton extends StatelessWidget {
  final String Function() textProvider;
  final String sectionName;
  final String? tooltip;

  const CopyButton({
    super.key,
    required this.textProvider,
    required this.sectionName,
    this.tooltip,
  });

  Future<void> _handleCopy(BuildContext context) async {
    final text = textProvider();
    await Clipboard.setData(ClipboardData(text: text));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied $sectionName to clipboard'),
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.copy_rounded, size: 18),
      tooltip: tooltip ?? 'Copy $sectionName',
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      onPressed: () => _handleCopy(context),
    );
  }
}
