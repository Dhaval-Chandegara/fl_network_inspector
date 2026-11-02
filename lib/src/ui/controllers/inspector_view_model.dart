import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../models/network_record.dart';
import '../../models/record_filter.dart';
import '../../models/record_sort.dart';
import '../../repository/network_inspector_repository.dart';

/// ViewModel managing state, paginated scrolling, filtering, and data operations for the inspector (UI-02, D-56).
class InspectorViewModel extends ChangeNotifier {
  final NetworkInspectorRepository repository;

  static const int pageSize = 50;

  List<NetworkRecord> _records = [];
  int _offset = 0;
  int _totalCount = 0;
  bool _isLoading = false;
  bool _isInitialLoading = true;
  bool _hasMore = false;
  String? _errorMessage;
  RecordFilter _filter = const RecordFilter();
  RecordSort _sort = RecordSort.newestFirst;

  bool _isDisposed = false;
  Timer? _searchDebounceTimer;

  InspectorViewModel({required this.repository}) {
    loadInitial();
  }

  List<NetworkRecord> get records => List.unmodifiable(_records);
  int get offset => _offset;
  int get totalCount => _totalCount;
  bool get isLoading => _isLoading;
  bool get isInitialLoading => _isInitialLoading;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;
  RecordFilter get filter => _filter;
  RecordSort get sort => _sort;

  /// Fetches initial batch of records and total count.
  Future<void> loadInitial() async {
    _isInitialLoading = true;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final initialRecords = await repository.getRecords(
        filter: _filter,
        sort: _sort,
        limit: pageSize,
        offset: 0,
      );
      final count = await repository.getRecordCount(filter: _filter);

      if (_isDisposed) return;
      _records = List.of(initialRecords);
      _offset = initialRecords.length;
      _totalCount = count;
      _hasMore = initialRecords.length == pageSize;
      _errorMessage = null;
    } catch (e) {
      if (_isDisposed) return;
      _errorMessage = 'Failed to load network records: check storage permissions and tap Retry.';
    } finally {
      if (!_isDisposed) {
        _isInitialLoading = false;
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Appends the next batch of 50 records during threshold infinite scroll.
  Future<void> loadMore() async {
    if (_isLoading || !_hasMore || _isInitialLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      final nextBatch = await repository.getRecords(
        filter: _filter,
        sort: _sort,
        limit: pageSize,
        offset: _offset,
      );

      if (_isDisposed) return;
      _records.addAll(nextBatch);
      _offset += nextBatch.length;
      _hasMore = nextBatch.length == pageSize;
    } catch (e) {
      if (_isDisposed) return;
      // Do not replace list on pagination failure, just stop loading
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Refreshes the record list from offset 0 (for pull-to-refresh).
  Future<void> refresh() async {
    _offset = 0;
    _hasMore = true;
    await loadInitial();
  }

  /// Updates the query filter and resets pagination.
  Future<void> updateFilter(RecordFilter newFilter) async {
    _filter = newFilter;
    _offset = 0;
    _hasMore = true;
    await loadInitial();
  }

  /// Sets the active filter (UI-04, D-55).
  Future<void> setFilter(RecordFilter filter) => updateFilter(filter);

  /// Updates the sort criteria and resets pagination.
  Future<void> updateSort(RecordSort newSort) async {
    _sort = newSort;
    _offset = 0;
    _hasMore = true;
    await loadInitial();
  }

  /// Sets the active sorting criteria (UI-05).
  Future<void> setSort(RecordSort sort) => updateSort(sort);

  /// Debounces text input by 300ms before querying repository (UI-03, D-54).
  void onSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      final trimmed = query.trim();
      final newFilter = _filter.copyWith(
        searchQuery: trimmed.isEmpty ? null : trimmed,
      );
      updateFilter(newFilter);
    });
  }

  /// Clears search query immediately without debounce (D-54).
  void clearSearch() {
    _searchDebounceTimer?.cancel();
    final newFilter = _filter.copyWith(searchQuery: null);
    updateFilter(newFilter);
  }

  /// Purges all captured records from the repository and resets in-memory view.
  Future<void> clearAll() async {
    try {
      await repository.clearAll();
      if (_isDisposed) return;
      _records.clear();
      _offset = 0;
      _totalCount = 0;
      _hasMore = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      if (_isDisposed) return;
      _errorMessage = 'Failed to clear records: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _searchDebounceTimer?.cancel();
    super.dispose();
  }
}
