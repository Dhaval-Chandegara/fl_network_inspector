import 'package:flutter/foundation.dart';

/// Available sorting fields for network transactions.
enum RecordSortField {
  /// Sort by request timestamp.
  timestamp,

  /// Sort by total transaction duration.
  duration,

  /// Sort by HTTP response status code.
  statusCode,

  /// Sort alphabetically by full request URL.
  url,

  /// Sort by response payload size.
  size;

  String toJson() => name;

  static RecordSortField fromString(String? value) {
    if (value == null) return RecordSortField.timestamp;
    return RecordSortField.values.firstWhere(
      (field) => field.name.toLowerCase() == value.toLowerCase(),
      orElse: () => RecordSortField.timestamp,
    );
  }
}

/// Ordering direction for sorting.
enum SortOrder {
  ascending,
  descending;

  String toJson() => name;

  static SortOrder fromString(String? value) {
    if (value == null) return SortOrder.descending;
    return SortOrder.values.firstWhere(
      (order) => order.name.toLowerCase() == value.toLowerCase(),
      orElse: () => SortOrder.descending,
    );
  }
}

/// Configuration specifying sorting criteria for captured network transactions.
@immutable
class RecordSort {
  /// The field by which records are sorted.
  final RecordSortField field;

  /// The sort direction (ascending vs descending).
  final SortOrder order;

  /// Creates a [RecordSort] specification.
  const RecordSort({
    this.field = RecordSortField.timestamp,
    this.order = SortOrder.descending,
  });

  /// Factory for default ordering: newest transactions first.
  static const newestFirst = RecordSort(
    field: RecordSortField.timestamp,
    order: SortOrder.descending,
  );

  /// Factory for oldest transactions first.
  static const oldestFirst = RecordSort(
    field: RecordSortField.timestamp,
    order: SortOrder.ascending,
  );

  /// Factory for slowest transactions first.
  static const slowestFirst = RecordSort(
    field: RecordSortField.duration,
    order: SortOrder.descending,
  );

  /// Factory for fastest transactions first.
  static const fastestFirst = RecordSort(
    field: RecordSortField.duration,
    order: SortOrder.ascending,
  );

  /// Creates a copy of this [RecordSort] with updated properties.
  RecordSort copyWith({
    RecordSortField? field,
    SortOrder? order,
  }) {
    return RecordSort(
      field: field ?? this.field,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'field': field.toJson(),
      'order': order.toJson(),
    };
  }

  factory RecordSort.fromMap(Map<String, dynamic> map) {
    return RecordSort(
      field: RecordSortField.fromString(map['field'] as String?),
      order: SortOrder.fromString(map['order'] as String?),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecordSort && other.field == field && other.order == order;
  }

  @override
  int get hashCode => Object.hash(field, order);

  @override
  String toString() => 'RecordSort(field: $field, order: $order)';
}
