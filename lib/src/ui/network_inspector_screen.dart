import 'package:flutter/material.dart';

import '../core/network_inspector.dart';
import '../models/network_record.dart';
import '../models/record_filter.dart';
import '../repository/network_inspector_repository.dart';
import 'components/clear_all_dialog.dart';
import 'components/filter_bottom_sheet.dart';
import 'components/filter_chips_bar.dart';
import 'components/request_tile.dart';
import 'components/search_bar_view.dart';
import 'components/sort_menu_button.dart';
import 'controllers/inspector_view_model.dart';
import 'controllers/theme_controller.dart';
import 'network_inspector_detail_screen.dart';

/// Full-screen in-app Material 3 debugging screen for browsing captured HTTP traffic (UI-01, UI-03, UI-04, UI-05).
class NetworkInspectorScreen extends StatefulWidget {
  final NetworkInspectorRepository? repository;
  final InspectorViewModel? viewModel;
  final ThemeController? themeController;
  final void Function(NetworkRecord record)? onSelectRecord;

  const NetworkInspectorScreen({
    super.key,
    this.repository,
    this.viewModel,
    this.themeController,
    this.onSelectRecord,
  });

  @override
  State<NetworkInspectorScreen> createState() => _NetworkInspectorScreenState();
}

class _NetworkInspectorScreenState extends State<NetworkInspectorScreen> {
  late final InspectorViewModel _viewModel;
  late final ThemeController _themeController;
  late final ScrollController _scrollController;
  bool _ownsViewModel = false;
  bool _ownsThemeController = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    if (widget.viewModel != null) {
      _viewModel = widget.viewModel!;
    } else {
      final repo = widget.repository ?? NetworkInspector.repository;
      if (repo == null) {
        throw StateError(
          'NetworkInspector is not initialized and no repository was provided.',
        );
      }
      _viewModel = InspectorViewModel(repository: repo);
      _ownsViewModel = true;
    }

    if (widget.themeController != null) {
      _themeController = widget.themeController!;
    } else {
      _themeController = ThemeController();
      _ownsThemeController = true;
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent * 0.8 &&
        !_viewModel.isLoading &&
        _viewModel.hasMore) {
      _viewModel.loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    if (_ownsViewModel) {
      _viewModel.dispose();
    }
    if (_ownsThemeController) {
      _themeController.dispose();
    }
    super.dispose();
  }

  Future<void> _handleClearAll() async {
    final confirmed = await ClearAllDialog.show(context);
    if (confirmed == true && mounted) {
      await _viewModel.clearAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All network records cleared'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _openFilterSheet() async {
    final updated = await FilterBottomSheet.show(
      context,
      initialFilter: _viewModel.filter,
    );
    if (updated != null && mounted) {
      _viewModel.setFilter(updated);
    }
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor:
            isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor:
            isDark ? Colors.white : const Color(0xFF111827),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2563EB),
        brightness: brightness,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeController,
      builder: (context, themeMode, _) {
        final platformBrightness =
            MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light;
        final activeBrightness = themeMode == ThemeMode.system
            ? platformBrightness
            : (themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light);
        final theme = _buildTheme(activeBrightness);

        return Theme(
          data: theme,
          child: AnimatedBuilder(
            animation: _viewModel,
            builder: (context, _) {
              return Scaffold(
                appBar: AppBar(
                  title: Row(
                    children: [
                      const Text(
                        'Network Inspector',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: activeBrightness == Brightness.dark
                              ? const Color(0xFF2C2C2C)
                              : const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_viewModel.totalCount}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: activeBrightness == Brightness.dark
                                ? const Color(0xFF9CA3AF)
                                : const Color(0xFF4B5563),
                          ),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    SortMenuButton(
                      currentSort: _viewModel.sort,
                      onSortSelected: _viewModel.setSort,
                    ),
                    IconButton(
                      icon: Icon(
                        themeMode == ThemeMode.dark
                            ? Icons.dark_mode
                            : (themeMode == ThemeMode.light
                                ? Icons.light_mode
                                : Icons.brightness_auto),
                      ),
                      tooltip: 'Switch Theme',
                      onPressed: _themeController.toggleTheme,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Clear all records',
                      onPressed: _handleClearAll,
                    ),
                  ],
                ),
                body: Column(
                  children: [
                    SearchBarView(
                      onChanged: _viewModel.onSearchChanged,
                      onClear: _viewModel.clearSearch,
                    ),
                    FilterChipsBar(
                      filter: _viewModel.filter,
                      onFilterChanged: _viewModel.setFilter,
                      onOpenFilterSheet: _openFilterSheet,
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: _buildBody(context),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_viewModel.isInitialLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_viewModel.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Color(0xFFDC2626),
              ),
              const SizedBox(height: 16),
              Text(
                _viewModel.errorMessage ??
                    'Failed to load network records: check storage permissions and tap Retry.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _viewModel.loadInitial,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_viewModel.records.isEmpty) {
      final isFiltered = _viewModel.filter.hasActiveFilters;

      return RefreshIndicator(
        onRefresh: _viewModel.refresh,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isFiltered ? Icons.search_off_rounded : Icons.radar,
                          size: 64,
                          color: const Color(0xFF64748B),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isFiltered ? 'No Matching Requests' : 'No Captured Traffic',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isFiltered
                              ? 'Try adjusting your search terms or clearing active filters to see more results.'
                              : 'Trigger network calls in your application to inspect HTTP requests and responses here.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF64748B),
                            height: 1.5,
                          ),
                        ),
                        if (isFiltered) ...[
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: () {
                              _viewModel.clearSearch();
                              _viewModel.setFilter(const RecordFilter());
                            },
                            child: const Text('Reset Filters'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    final records = _viewModel.records;
    final hasMore = _viewModel.hasMore;

    return RefreshIndicator(
      onRefresh: _viewModel.refresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: records.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == records.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          final record = records[index];
          return RequestTile(
            record: record,
            onTap: () {
              if (widget.onSelectRecord != null) {
                widget.onSelectRecord!(record);
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) =>
                        NetworkInspectorDetailScreen(record: record),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}
