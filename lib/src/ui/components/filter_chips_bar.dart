import 'package:flutter/material.dart';

import '../../models/record_filter.dart';

/// Single-line horizontal scrollable quick-filter chips bar (UI-04, D-55).
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

  bool get _isAllSelected =>
      !filter.errorOnly &&
      (filter.httpMethods == null || filter.httpMethods!.isEmpty) &&
      (filter.statusCodes == null || filter.statusCodes!.isEmpty) &&
      filter.minDurationMs == null &&
      filter.maxDurationMs == null &&
      filter.startDate == null &&
      filter.endDate == null;

  bool get _isErrorsOnlySelected => filter.errorOnly;

  bool get _is2xxSelected =>
      filter.statusCodes != null &&
      filter.statusCodes!.contains(200) &&
      !filter.statusCodes!.contains(400);

  bool get _is4xx5xxSelected =>
      filter.statusCodes != null &&
      (filter.statusCodes!.contains(400) || filter.statusCodes!.contains(500)) &&
      !filter.statusCodes!.contains(200);

  bool get _isPostSelected =>
      filter.httpMethods != null &&
      filter.httpMethods!.contains('POST') &&
      filter.httpMethods!.length == 1;

  bool get _isGetSelected =>
      filter.httpMethods != null &&
      filter.httpMethods!.contains('GET') &&
      filter.httpMethods!.length == 1;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // All Chip
          FilterChip(
            label: const Text('All'),
            selected: _isAllSelected,
            onSelected: (_) {
              onFilterChanged(
                RecordFilter(searchQuery: filter.searchQuery),
              );
            },
          ),
          const SizedBox(width: 8),

          // Errors Only Chip
          FilterChip(
            label: const Text('Errors Only'),
            selected: _isErrorsOnlySelected,
            onSelected: (selected) {
              onFilterChanged(
                filter.copyWith(errorOnly: selected),
              );
            },
          ),
          const SizedBox(width: 8),

          // 2xx Chip
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

          // 4xx/5xx Chip
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
          const SizedBox(width: 8),

          // POST Chip
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

          // GET Chip
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

          // Advanced Filters Action Chip
          ActionChip(
            avatar: const Icon(Icons.tune_rounded, size: 16),
            label: const Text('Filters'),
            tooltip: 'Open filter sheet',
            onPressed: onOpenFilterSheet,
          ),
        ],
      ),
    );
  }
}
