import 'package:flutter/foundation.dart';

/// Immutable query filter criteria for searching and filtering network records.
@immutable
class RecordFilter {
  /// Substring query matching against URL, path, or body content.
  final String? searchQuery;

  /// Allowed HTTP methods (e.g. GET, POST, PUT, DELETE).
  final Set<String>? httpMethods;

  /// Status code categories or exact codes (e.g. 200, 404, 500).
  final Set<int>? statusCodes;

  /// Restricts results strictly to records with errors or status code >= 400.
  final bool errorOnly;

  /// Lower bound filter for request duration in milliseconds.
  final int? minDurationMs;

  /// Upper bound filter for request duration in milliseconds.
  final int? maxDurationMs;

  /// Filter starting timestamp.
  final DateTime? startDate;

  /// Filter ending timestamp.
  final DateTime? endDate;

  /// Creates a [RecordFilter] instance.
  const RecordFilter({
    this.searchQuery,
    this.httpMethods,
    this.statusCodes,
    this.errorOnly = false,
    this.minDurationMs,
    this.maxDurationMs,
    this.startDate,
    this.endDate,
  });

  /// Factory for an empty/default filter that matches all records.
  static const empty = RecordFilter();

  /// Returns whether this filter contains any active constraint.
  bool get hasActiveFilters =>
      (searchQuery != null && searchQuery!.trim().isNotEmpty) ||
      (httpMethods != null && httpMethods!.isNotEmpty) ||
      (statusCodes != null && statusCodes!.isNotEmpty) ||
      errorOnly ||
      minDurationMs != null ||
      maxDurationMs != null ||
      startDate != null ||
      endDate != null;

  static const _sentinel = Object();

  /// Creates a modified copy of this [RecordFilter].
  RecordFilter copyWith({
    Object? searchQuery = _sentinel,
    Object? httpMethods = _sentinel,
    Object? statusCodes = _sentinel,
    bool? errorOnly,
    Object? minDurationMs = _sentinel,
    Object? maxDurationMs = _sentinel,
    Object? startDate = _sentinel,
    Object? endDate = _sentinel,
  }) {
    return RecordFilter(
      searchQuery: identical(searchQuery, _sentinel)
          ? this.searchQuery
          : searchQuery as String?,
      httpMethods: identical(httpMethods, _sentinel)
          ? this.httpMethods
          : httpMethods as Set<String>?,
      statusCodes: identical(statusCodes, _sentinel)
          ? this.statusCodes
          : statusCodes as Set<int>?,
      errorOnly: errorOnly ?? this.errorOnly,
      minDurationMs: identical(minDurationMs, _sentinel)
          ? this.minDurationMs
          : minDurationMs as int?,
      maxDurationMs: identical(maxDurationMs, _sentinel)
          ? this.maxDurationMs
          : maxDurationMs as int?,
      startDate: identical(startDate, _sentinel)
          ? this.startDate
          : startDate as DateTime?,
      endDate:
          identical(endDate, _sentinel) ? this.endDate : endDate as DateTime?,
    );
  }

  /// Converts this filter to a map.
  Map<String, dynamic> toMap() {
    return {
      'search_query': searchQuery,
      'http_methods': httpMethods?.toList(),
      'status_codes': statusCodes?.toList(),
      'error_only': errorOnly ? 1 : 0,
      'min_duration_ms': minDurationMs,
      'max_duration_ms': maxDurationMs,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
    };
  }

  /// Deserializes a [RecordFilter] from a map.
  factory RecordFilter.fromMap(Map<String, dynamic> map) {
    final rawMethods = map['http_methods'] ?? map['httpMethods'];
    final Set<String>? httpMethods = (rawMethods is List)
        ? rawMethods.map((e) => e.toString().toUpperCase()).toSet()
        : null;

    final rawStatusCodes = map['status_codes'] ?? map['statusCodes'];
    final Set<int>? statusCodes = (rawStatusCodes is List)
        ? rawStatusCodes
            .map(
                (e) => (e is num) ? e.toInt() : int.tryParse(e.toString()) ?? 0)
            .toSet()
        : null;

    final rawErrorOnly = map['error_only'] ?? map['errorOnly'];
    final bool errorOnly = (rawErrorOnly is bool)
        ? rawErrorOnly
        : (rawErrorOnly == 1 || rawErrorOnly == '1' || rawErrorOnly == 'true');

    return RecordFilter(
      searchQuery:
          map['search_query'] as String? ?? map['searchQuery'] as String?,
      httpMethods: httpMethods,
      statusCodes: statusCodes,
      errorOnly: errorOnly,
      minDurationMs: (map['min_duration_ms'] ?? map['minDurationMs']) as int?,
      maxDurationMs: (map['max_duration_ms'] ?? map['maxDurationMs']) as int?,
      startDate: map['start_date'] != null
          ? DateTime.tryParse(map['start_date'] as String)
          : null,
      endDate: map['end_date'] != null
          ? DateTime.tryParse(map['end_date'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecordFilter &&
        other.searchQuery == searchQuery &&
        setEquals(other.httpMethods, httpMethods) &&
        setEquals(other.statusCodes, statusCodes) &&
        other.errorOnly == errorOnly &&
        other.minDurationMs == minDurationMs &&
        other.maxDurationMs == maxDurationMs &&
        other.startDate == startDate &&
        other.endDate == endDate;
  }

  @override
  int get hashCode => Object.hash(
        searchQuery,
        httpMethods != null ? Object.hashAll(httpMethods!) : null,
        statusCodes != null ? Object.hashAll(statusCodes!) : null,
        errorOnly,
        minDurationMs,
        maxDurationMs,
        startDate,
        endDate,
      );

  @override
  String toString() {
    return 'RecordFilter(searchQuery: $searchQuery, httpMethods: $httpMethods, '
        'statusCodes: $statusCodes, errorOnly: $errorOnly, minDurationMs: $minDurationMs, '
        'maxDurationMs: $maxDurationMs, startDate: $startDate, endDate: $endDate)';
  }
}
