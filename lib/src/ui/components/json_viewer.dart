import 'package:flutter/material.dart';

import '../../models/body_type.dart';
import '../utils/json_format_isolate.dart';
import 'copy_button.dart';

/// Zero-dependency syntax-colorized JSON viewer with Raw / Pretty toggle and background isolate parsing (UI-08, D-58).
class JsonViewerWidget extends StatefulWidget {
  final String? rawPayload;
  final BodyType bodyType;
  final bool isTruncated;
  final String title;

  const JsonViewerWidget({
    super.key,
    required this.rawPayload,
    this.bodyType = BodyType.json,
    this.isTruncated = false,
    this.title = 'Payload Body',
  });

  @override
  State<JsonViewerWidget> createState() => _JsonViewerWidgetState();
}

class _JsonViewerWidgetState extends State<JsonViewerWidget> {
  bool _isPretty = true;
  bool _isFormatting = false;
  String? _formattedJson;

  @override
  void initState() {
    super.initState();
    _formatContent();
  }

  @override
  void didUpdateWidget(covariant JsonViewerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawPayload != widget.rawPayload) {
      _formatContent();
    }
  }

  Future<void> _formatContent() async {
    final raw = widget.rawPayload;
    if (raw == null || raw.isEmpty) {
      setState(() {
        _formattedJson = null;
        _isFormatting = false;
      });
      return;
    }

    if (widget.bodyType != BodyType.json) {
      setState(() {
        _formattedJson = raw;
        _isFormatting = false;
      });
      return;
    }

    if (raw.length > 50 * 1024) {
      setState(() => _isFormatting = true);
      final formatted = await formatJsonBody(raw);
      if (mounted) {
        setState(() {
          _formattedJson = formatted;
          _isFormatting = false;
        });
      }
    } else {
      setState(() {
        _formattedJson = formatJsonIsolate(raw);
        _isFormatting = false;
      });
    }
  }

  List<TextSpan> _buildJsonSpans(String json, bool isDark) {
    final keyColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
    final stringColor =
        isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
    final numberColor =
        isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
    final boolColor =
        isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
    final nullColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final defaultColor = isDark ? Colors.white70 : const Color(0xFF1F2937);

    final spans = <TextSpan>[];
    final regex = RegExp(
      r'("([^"\\]|\\.)*")\s*:\s*|'
      r'("([^"\\]|\\.)*")|'
      r'(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)|'
      r'\b(true|false)\b|'
      r'\b(null)\b',
    );

    int lastMatchEnd = 0;
    for (final match in regex.allMatches(json)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: json.substring(lastMatchEnd, match.start),
          style: TextStyle(color: defaultColor),
        ));
      }

      final matchedText = match.group(0)!;
      if (matchedText.endsWith(':') || matchedText.contains('":')) {
        // Key
        final colonIndex = matchedText.indexOf(':');
        final keyText = matchedText.substring(0, colonIndex);
        final colonAndSpace = matchedText.substring(colonIndex);
        spans.add(TextSpan(
          text: keyText,
          style: TextStyle(color: keyColor, fontWeight: FontWeight.w600),
        ));
        spans.add(TextSpan(
          text: colonAndSpace,
          style: TextStyle(color: defaultColor),
        ));
      } else if (matchedText.startsWith('"')) {
        // String value
        spans.add(TextSpan(
          text: matchedText,
          style: TextStyle(color: stringColor),
        ));
      } else if (matchedText == 'true' || matchedText == 'false') {
        // Boolean
        spans.add(TextSpan(
          text: matchedText,
          style: TextStyle(color: boolColor, fontWeight: FontWeight.w600),
        ));
      } else if (matchedText == 'null') {
        // Null
        spans.add(TextSpan(
          text: matchedText,
          style: TextStyle(color: nullColor, fontStyle: FontStyle.italic),
        ));
      } else {
        // Number
        spans.add(TextSpan(
          text: matchedText,
          style: TextStyle(color: numberColor),
        ));
      }
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < json.length) {
      spans.add(TextSpan(
        text: json.substring(lastMatchEnd),
        style: TextStyle(color: defaultColor),
      ));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final payload = widget.rawPayload;

    if (payload == null || payload.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No payload body recorded',
          style: TextStyle(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          ),
        ),
      );
    }

    final displayText = _isPretty ? (_formattedJson ?? payload) : payload;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252525) : const Color(0xFFF3F4F6),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${payload.length} chars)',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF6B7280),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() => _isPretty = !_isPretty);
                  },
                  child: Text(_isPretty ? 'Raw' : 'Pretty'),
                ),
                CopyButton(
                  textProvider: () => displayText,
                  sectionName: widget.title,
                ),
              ],
            ),
          ),

          // Truncation banner
          if (widget.isTruncated)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFFFEF3C7),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 18, color: Color(0xFFD97706)),
                  SizedBox(width: 8),
                  Text(
                    '[Body truncated at 1MB]',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ),

          // Body text view
          if (_isFormatting)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Formatting payload...',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _isPretty && widget.bodyType == BodyType.json
                    ? SelectableText.rich(
                        TextSpan(
                          children: _buildJsonSpans(displayText, isDark),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                          ),
                        ),
                      )
                    : SelectableText(
                        displayText,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          height: 1.4,
                          color:
                              isDark ? Colors.white70 : const Color(0xFF1F2937),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
