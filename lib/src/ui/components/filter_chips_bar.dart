import 'package:flutter/material.dart';

import '../../models/record_filter.dart';

/// Single-line horizontal scrollable quick-filter chips bar (UI-04, D-55).
///
/// Features a prominent leading 'Filters' chip displaying active filter count,
/// followed by quick toggles for common developer workflows (Errors Only, GET, POST, etc.).
class FilterChipsBar extends StatelessWidget {
  final RecordFilter filter;
  final ValueChanged<RecordFilter> onFilterChanged;
  final VoidCallback onOpenFilterSheet;

  const FilterChipsBar({
    super.key,
    required this.filter,
    required this.onFilterChanged,
    required this.onOpenFilterSheet,
  });

  int get activeFilterCount {
    int count = 0;
    if (filter.errorOnly) count++;
    if (filter.httpMethods != null && filter.httpMethods!.isNotEmpty) {
      count += filter.httpMethods!.length;
    }
    if (filter.statusCodes != null && filter.statusCodes!.isNotEmpty) {
      count++;
    }
    if (filter.minDurationMs != null || filter.maxDurationMs != null) count++;
    if (filter.startDate != null || filter.endDate != null) count++;
    return count;
  }

  bool get _isErrorsOnlySelected => filter.errorOnly;

  bool get _isGetSelected =>
      filter.httpMethods != null &&
      filter.httpMethods!.contains('GET') &&
      filter.httpMethods!.length == 1;

  bool get _isPostSelected =>
      filter.httpMethods != null &&
      filter.httpMethods!.contains('POST') &&
      filter.httpMethods!.length == 1;

  bool get _isPutSelected =>
      filter.httpMethods != null &&
      filter.httpMethods!.contains('PUT') &&
      filter.httpMethods!.length == 1;

  bool get _isDeleteSelected =>
      filter.httpMethods != null &&
      filter.httpMethods!.contains('DELETE') &&
      filter.httpMethods!.length == 1;

  bool get _is2xxSelected =>
      filter.statusCodes != null &&
      filter.statusCodes!.contains(200) &&
      !filter.statusCodes!.contains(400);

  bool get _is4xx5xxSelected =>
      filter.statusCodes != null &&
      (filter.statusCodes!.contains(400) || filter.statusCodes!.contains(500)) &&
      !filter.statusCodes!.contains(200);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final count = activeFilterCount;
    final hasActive = count > 0;

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // 1. Main Leading Filters Chip with count badge
          ActionChip(
            avatar: Icon(
              Icons.tune_rounded,
              size: 16,
              color: hasActive
                  ? (isDark ? Colors.white : Colors.white)
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
            ),
            label: Text(
              hasActive ? 'Filters ($count)' : 'Filters',
              style: TextStyle(
                fontWeight: hasActive ? FontWeight.bold : FontWeight.w600,
                color: hasActive
                    ? Colors.white
                    : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B)),
              ),
            ),
            backgroundColor: hasActive
                ? const Color(0xFF2563EB)
                : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF1F5F9)),
            side: BorderSide(
              color: hasActive
                  ? const Color(0xFF1D4ED8)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            tooltip: 'Open filter sheet',
            onPressed: onOpenFilterSheet,
          ),
          const SizedBox(width: 8),

          // 2. Errors Only Quick Chip
          FilterChip(
            avatar: _isErrorsOnlySelected
                ? const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFEF4444))
                : null,
            label: const Text('Errors Only'),
            selected: _isErrorsOnlySelected,
            selectedColor: const Color(0x33EF4444),
            checkmarkColor: const Color(0xFFEF4444),
            onSelected: (selected) {
              onFilterChanged(
                filter.copyWith(errorOnly: selected),
              );
            },
          ),
          const SizedBox(width: 8),

          // 3. GET Quick Chip
          FilterChip(
            label: const Text('GET'),
            selected: _isGetSelected,
            onSelected: (selected) {
              final methods = selected ? {'GET'} : <String>{};
              onFilterChanged(
                filter.copyWith(httpMethods: methods.isEmpty ? null : methods),
              );
            },
          ),
          const SizedBox(width: 8),

          // 4. POST Quick Chip
          FilterChip(
            label: const Text('POST'),
            selected: _isPostSelected,
            onSelected: (selected) {
              final methods = selected ? {'POST'} : <String>{};
              onFilterChanged(
                filter.copyWith(httpMethods: methods.isEmpty ? null : methods),
              );
            },
          ),
          const SizedBox(width: 8),

          // 5. PUT Quick Chip
          FilterChip(
            label: const Text('PUT'),
            selected: _isPutSelected,
            onSelected: (selected) {
              final methods = selected ? {'PUT'} : <String>{};
              onFilterChanged(
                filter.copyWith(httpMethods: methods.isEmpty ? null : methods),
              );
            },
          ),
          const SizedBox(width: 8),

          // 6. DELETE Quick Chip
          FilterChip(
            label: const Text('DELETE'),
            selected: _isDeleteSelected,
            onSelected: (selected) {
              final methods = selected ? {'DELETE'} : <String>{};
              onFilterChanged(
                filter.copyWith(httpMethods: methods.isEmpty ? null : methods),
              );
            },
          ),
          const SizedBox(width: 8),

          // 7. 2xx Quick Chip
          FilterChip(
            label: const Text('2xx'),
            selected: _is2xxSelected,
            onSelected: (selected) {
              final codes = selected ? {200, 201, 202, 204, 206} : <int>{};
              onFilterChanged(
                filter.copyWith(statusCodes: codes.isEmpty ? null : codes),
              );
            },
          ),
          const SizedBox(width: 8),

          // 8. 4xx/5xx Quick Chip
          FilterChip(
            label: const Text('4xx/5xx'),
            selected: _is4xx5xxSelected,
            onSelected: (selected) {
              final codes = selected
                  ? {400, 401, 403, 404, 422, 500, 502, 503, 504}
                  : <int>{};
              onFilterChanged(
                filter.copyWith(statusCodes: codes.isEmpty ? null : codes),
              );
            },
          ),
        ],
      ),
    );
  }
}
