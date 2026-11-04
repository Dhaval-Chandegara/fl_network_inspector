import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/record_filter.dart';

/// Modal bottom sheet for advanced multi-parameter network traffic filtering (UI-04, D-55).
class FilterBottomSheet extends StatefulWidget {
  final RecordFilter initialFilter;

  const FilterBottomSheet({
    super.key,
    required this.initialFilter,
  });

  /// Presents the [FilterBottomSheet] modal and returns the updated [RecordFilter] if applied.
  static Future<RecordFilter?> show(
    BuildContext context, {
    required RecordFilter initialFilter,
    ThemeData? theme,
  }) {
    return showModalBottomSheet<RecordFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final content = FilterBottomSheet(initialFilter: initialFilter);
        return theme != null ? Theme(data: theme, child: content) : content;
      },
    );
  }

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late Set<String> _selectedMethods;
  late Set<int> _selectedStatusCodes;
  late bool _errorOnly;
  late TextEditingController _minDurationController;
  late TextEditingController _maxDurationController;
  DateTime? _startDate;
  DateTime? _endDate;

  static const List<String> _availableMethods = [
    'GET',
    'POST',
    'PUT',
    'DELETE',
    'PATCH',
    'HEAD',
    'OPTIONS',
  ];

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _selectedMethods = Set.of(widget.initialFilter.httpMethods ?? {});
    _selectedStatusCodes = Set.of(widget.initialFilter.statusCodes ?? {});
    _errorOnly = widget.initialFilter.errorOnly;
    _minDurationController = TextEditingController(
      text: widget.initialFilter.minDurationMs?.toString() ?? '',
    );
    _maxDurationController = TextEditingController(
      text: widget.initialFilter.maxDurationMs?.toString() ?? '',
    );
    _startDate = widget.initialFilter.startDate;
    _endDate = widget.initialFilter.endDate;
  }

  @override
  void dispose() {
    _minDurationController.dispose();
    _maxDurationController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _selectedMethods.clear();
      _selectedStatusCodes.clear();
      _errorOnly = false;
      _minDurationController.clear();
      _maxDurationController.clear();
      _startDate = null;
      _endDate = null;
    });
  }

  void _applyFilters() {
    final minDuration = int.tryParse(_minDurationController.text.trim());
    final maxDuration = int.tryParse(_maxDurationController.text.trim());

    final updatedFilter = widget.initialFilter.copyWith(
      httpMethods: _selectedMethods.isEmpty ? null : _selectedMethods,
      statusCodes: _selectedStatusCodes.isEmpty ? null : _selectedStatusCodes,
      errorOnly: _errorOnly,
      minDurationMs: minDuration,
      maxDurationMs: maxDuration,
      startDate: _startDate,
      endDate: _endDate,
    );

    Navigator.of(context).pop(updatedFilter);
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);

    // Limit bottom sheet height to at most 95% of screen safe area
    final safeHeight = mediaQuery.size.height - mediaQuery.padding.top;
    final maxSheetHeight = safeHeight * 0.95;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxSheetHeight,
      ),
      child: Material(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: mediaQuery.viewInsets.bottom,
            ),
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

                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Requests',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Scrollable Inner Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // HTTP Methods
                        const Text(
                          'HTTP Methods',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availableMethods.map((method) {
                            final isSelected =
                                _selectedMethods.contains(method);
                            return FilterChip(
                              label: Text(method),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedMethods.add(method);
                                  } else {
                                    _selectedMethods.remove(method);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Status Code Categories
                        const Text(
                          'Status Code Range',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              label: const Text('2xx Success'),
                              selected: _selectedStatusCodes.contains(200),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedStatusCodes
                                        .addAll([200, 201, 202, 204]);
                                  } else {
                                    _selectedStatusCodes
                                        .removeAll([200, 201, 202, 204]);
                                  }
                                });
                              },
                            ),
                            FilterChip(
                              label: const Text('3xx Redirect'),
                              selected: _selectedStatusCodes.contains(301),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedStatusCodes
                                        .addAll([301, 302, 304, 307]);
                                  } else {
                                    _selectedStatusCodes
                                        .removeAll([301, 302, 304, 307]);
                                  }
                                });
                              },
                            ),
                            FilterChip(
                              label: const Text('4xx Client Error'),
                              selected: _selectedStatusCodes.contains(400),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedStatusCodes
                                        .addAll([400, 401, 403, 404, 422]);
                                  } else {
                                    _selectedStatusCodes
                                        .removeAll([400, 401, 403, 404, 422]);
                                  }
                                });
                              },
                            ),
                            FilterChip(
                              label: const Text('5xx Server Error'),
                              selected: _selectedStatusCodes.contains(500),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedStatusCodes
                                        .addAll([500, 502, 503, 504]);
                                  } else {
                                    _selectedStatusCodes
                                        .removeAll([500, 502, 503, 504]);
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Errors Only Switch
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Errors Only',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'Show only failed network requests or status codes >= 400',
                            style: TextStyle(fontSize: 12),
                          ),
                          value: _errorOnly,
                          onChanged: (val) {
                            setState(() => _errorOnly = val);
                          },
                        ),
                        const SizedBox(height: 16),

                        // Duration Filters
                        const Text(
                          'Duration (ms)',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _minDurationController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Min (ms)',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _maxDurationController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Max (ms)',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Date Range Picker
                        const Text(
                          'Date Range',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.date_range_rounded),
                          label: Text(
                            _startDate != null && _endDate != null
                                ? '${_dateFormat.format(_startDate!)} to ${_dateFormat.format(_endDate!)}'
                                : 'Select Date Range',
                          ),
                          onPressed: _pickDateRange,
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Action buttons: Reset & Apply
                const Divider(height: 1),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _resetFilters,
                          child: const Text('Reset Filters'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _applyFilters,
                          child: const Text('Apply Filters'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
