import '../core/constants.dart';
import '../models/network_record.dart';
import '../models/network_status.dart';
import '../models/record_filter.dart';
import '../models/record_sort.dart';
import 'network_inspector_repository.dart';

/// In-memory ring-buffer fallback implementation of [NetworkInspectorRepository] (D-32).
///
/// Used when running on Flutter Web (`kIsWeb`) or when database persistence is disabled
/// (`enableDatabase: false`). Holds records up to [maxRecords] in RAM with FIFO ring-buffer
/// eviction and two-phase in-memory coalescing.
class InMemoryNetworkInspectorRepository implements NetworkInspectorRepository {
  /// Maximum number of records retained in memory before older entries are evicted.
  final int maxRecords;

  final List<NetworkRecord> _records = [];

  /// Creates an [InMemoryNetworkInspectorRepository].
  InMemoryNetworkInspectorRepository({
    this.maxRecords = NetworkInspectorConstants.defaultMaxRecords,
  });

  @override
  Future<void> save(NetworkRecord record) async {
    final existingIndex = _records.indexWhere((r) => r.id == record.id);
    if (existingIndex != -1) {
      // Two-phase coalescing in-place (D-22)
      _records[existingIndex] = record;
    } else {
      _records.insert(0, record);
      if (_records.length > maxRecords) {
        _records.removeLast(); // FIFO eviction
      }
    }
  }

  @override
  Future<void> saveBatch(List<NetworkRecord> records) async {
    for (final record in records) {
      await save(record);
    }
  }

  @override
  Future<NetworkRecord?> getById(String id) async {
    for (final r in _records) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  Future<List<NetworkRecord>> getRecords({
    RecordFilter? filter,
    RecordSort? sort,
    int limit = 50,
    int offset = 0,
  }) async {
    final filtered = _applyFilter(filter);
    _applySort(filtered, sort);

    if (offset >= filtered.length) {
      return [];
    }
    final end = (offset + limit < filtered.length) ? offset + limit : filtered.length;
    return filtered.sublist(offset, end);
  }

  @override
  Future<int> getRecordCount({RecordFilter? filter}) async {
    if (filter == null || !filter.hasActiveFilters) {
      return _records.length;
    }
    return _applyFilter(filter).length;
  }

  @override
  Future<void> clearAll() async {
    _records.clear();
  }

  @override
  Future<void> flush() async {
    // No-op for in-memory ring-buffer
  }

  @override
  Future<void> dispose() async {
    _records.clear();
  }

  List<NetworkRecord> _applyFilter(RecordFilter? filter) {
    if (filter == null || !filter.hasActiveFilters) {
      return List<NetworkRecord>.from(_records);
    }

    return _records.where((record) {
      // Substring search query across url, path, request_body, response_body
      if (filter.searchQuery != null && filter.searchQuery!.trim().isNotEmpty) {
        final query = filter.searchQuery!.trim().toLowerCase();
        final matchesUrl = record.url.toLowerCase().contains(query);
        final matchesPath = record.path.toLowerCase().contains(query);
        final matchesReq = record.requestBody?.body?.toLowerCase().contains(query) ?? false;
        final matchesRes = record.responseBody?.body?.toLowerCase().contains(query) ?? false;
        if (!matchesUrl && !matchesPath && !matchesReq && !matchesRes) {
          return false;
        }
      }

      // HTTP method filter
      if (filter.httpMethods != null && filter.httpMethods!.isNotEmpty) {
        final methods = filter.httpMethods!.map((m) => m.toUpperCase()).toSet();
        if (!methods.contains(record.method.toUpperCase())) {
          return false;
        }
      }

      // HTTP status code filter
      if (filter.statusCodes != null && filter.statusCodes!.isNotEmpty) {
        if (record.responseStatusCode == null ||
            !filter.statusCodes!.contains(record.responseStatusCode)) {
          return false;
        }
      }

      // Error only filter
      if (filter.errorOnly) {
        if (!record.hasError && record.status != NetworkStatus.failed) {
          return false;
        }
      }

      // Duration bounds
      if (filter.minDurationMs != null) {
        if (record.durationMs == null || record.durationMs! < filter.minDurationMs!) {
          return false;
        }
      }
      if (filter.maxDurationMs != null) {
        if (record.durationMs == null || record.durationMs! > filter.maxDurationMs!) {
          return false;
        }
      }

      // Timestamp bounds
      if (filter.startDate != null) {
        if (record.requestTimestamp.isBefore(filter.startDate!)) {
          return false;
        }
      }
      if (filter.endDate != null) {
        if (record.requestTimestamp.isAfter(filter.endDate!)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  void _applySort(List<NetworkRecord> list, RecordSort? sort) {
    final sortField = sort?.field ?? RecordSortField.timestamp;
    final sortOrder = sort?.order ?? SortOrder.descending;

    list.sort((a, b) {
      int comparison;
      switch (sortField) {
        case RecordSortField.timestamp:
          comparison = a.requestTimestamp.compareTo(b.requestTimestamp);
          break;
        case RecordSortField.duration:
          comparison = (a.durationMs ?? 0).compareTo(b.durationMs ?? 0);
          break;
        case RecordSortField.statusCode:
          comparison = (a.responseStatusCode ?? 0).compareTo(b.responseStatusCode ?? 0);
          break;
        case RecordSortField.url:
          comparison = a.url.compareTo(b.url);
          break;
        case RecordSortField.size:
          comparison = (a.responseSize ?? 0).compareTo(b.responseSize ?? 0);
          break;
      }
      return sortOrder == SortOrder.ascending ? comparison : -comparison;
    });
  }
}
