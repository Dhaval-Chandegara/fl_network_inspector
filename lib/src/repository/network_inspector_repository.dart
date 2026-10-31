import '../models/network_record.dart';
import '../models/record_filter.dart';
import '../models/record_sort.dart';

/// Abstract contract decoupling network transaction data access, querying,
/// and persistence from underlying storage engines (D-29).
abstract interface class NetworkInspectorRepository {
  /// Asynchronously persists or updates a single [NetworkRecord].
  Future<void> save(NetworkRecord record);

  /// Asynchronously persists or updates a batch of [NetworkRecord]s.
  Future<void> saveBatch(List<NetworkRecord> records);

  /// Retrieves a single record by its RFC 4122 v4 unique [id], or `null` if not found.
  Future<NetworkRecord?> getById(String id);

  /// Retrieves a paginated list of network records matching [filter] and ordered by [sort].
  Future<List<NetworkRecord>> getRecords({
    RecordFilter? filter,
    RecordSort? sort,
    int limit = 50,
    int offset = 0,
  });

  /// Returns the total count of network records matching [filter].
  Future<int> getRecordCount({RecordFilter? filter});

  /// Deletes all stored network records while preserving database schema and indexes (D-28).
  Future<void> clearAll();

  /// Immediately flushes all queued in-memory records to durable storage (D-24).
  Future<void> flush();

  /// Releases resources, drains queues, and closes active database connections (D-24).
  Future<void> dispose();
}
