import 'package:flutter/material.dart';

import '../../models/record_sort.dart';

/// AppBar popup menu button for switching transaction sorting criteria (UI-05).
class SortMenuButton extends StatelessWidget {
  final RecordSort currentSort;
  final ValueChanged<RecordSort> onSortSelected;

  const SortMenuButton({
    super.key,
    required this.currentSort,
    required this.onSortSelected,
  });

  static const RecordSort _statusCodeSort = RecordSort(
    field: RecordSortField.statusCode,
    order: SortOrder.descending,
  );

  bool _isOptionActive(RecordSort option) {
    return currentSort.field == option.field && currentSort.order == option.order;
  }

  PopupMenuItem<RecordSort> _buildItem({
    required RecordSort value,
    required String label,
  }) {
    final isActive = _isOptionActive(value);
    return PopupMenuItem<RecordSort>(
      value: value,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? const Color(0xFF2563EB) : null,
              ),
            ),
          ),
          if (isActive)
            const Icon(
              Icons.check_rounded,
              size: 18,
              color: Color(0xFF2563EB),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<RecordSort>(
      icon: const Icon(Icons.sort_rounded),
      tooltip: 'Sort records',
      onSelected: onSortSelected,
      itemBuilder: (context) => [
        _buildItem(
          value: RecordSort.newestFirst,
          label: 'Newest First',
        ),
        _buildItem(
          value: RecordSort.oldestFirst,
          label: 'Oldest First',
        ),
        _buildItem(
          value: RecordSort.fastestFirst,
          label: 'Fastest First',
        ),
        _buildItem(
          value: RecordSort.slowestFirst,
          label: 'Slowest First',
        ),
        _buildItem(
          value: _statusCodeSort,
          label: 'Status Code',
        ),
      ],
    );
  }
}
