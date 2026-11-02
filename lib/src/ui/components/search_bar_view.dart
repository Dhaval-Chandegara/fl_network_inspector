import 'package:flutter/material.dart';

/// Persistent Material 3 search bar with debounced input and clear button (UI-03, D-54).
class SearchBarView extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final TextEditingController? controller;

  const SearchBarView({
    super.key,
    required this.onChanged,
    required this.onClear,
    this.controller,
  });

  @override
  State<SearchBarView> createState() => _SearchBarViewState();
}

class _SearchBarViewState extends State<SearchBarView> {
  late final TextEditingController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController();
      _ownsController = true;
    }
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleClear() {
    _controller.clear();
    widget.onClear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SearchBar(
        controller: _controller,
        hintText: 'Search by URL, method, status, payload...',
        hintStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          ),
        ),
        textStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        leading: const Icon(
          Icons.search_rounded,
          size: 20,
          color: Color(0xFF64748B),
        ),
        trailing: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded, size: 20),
              tooltip: 'Clear search query',
              onPressed: _handleClear,
            ),
        ],
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(
          isDark ? const Color(0xFF1E1E1E) : Colors.white,
        ),
        side: WidgetStatePropertyAll(
          BorderSide(
            color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}
