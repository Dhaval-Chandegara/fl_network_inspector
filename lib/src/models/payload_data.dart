import 'package:flutter/foundation.dart';

import 'body_type.dart';

/// Immutable container encapsulating payload body content and metadata.
@immutable
class PayloadData {
  /// The string representation of the payload body (or formatted summary for binary/multipart).
  final String? body;

  /// The raw payload size in bytes.
  final int byteSize;

  /// The detected payload format classification.
  final BodyType bodyType;

  /// Whether the body content was truncated due to configured size limits.
  final bool isTruncated;

  /// Creates a [PayloadData] instance.
  const PayloadData({
    this.body,
    this.byteSize = 0,
    this.bodyType = BodyType.empty,
    this.isTruncated = false,
  });

  /// Factory for an empty payload.
  static const empty = PayloadData();

  /// Returns whether this payload contains body content.
  bool get hasContent => body != null && body!.isNotEmpty;

  /// Creates a copy of this [PayloadData] with updated properties.
  PayloadData copyWith({
    String? body,
    int? byteSize,
    BodyType? bodyType,
    bool? isTruncated,
  }) {
    return PayloadData(
      body: body ?? this.body,
      byteSize: byteSize ?? this.byteSize,
      bodyType: bodyType ?? this.bodyType,
      isTruncated: isTruncated ?? this.isTruncated,
    );
  }

  /// Converts this model into a database- and JSON-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'body': body,
      'byte_size': byteSize,
      'body_type': bodyType.toJson(),
      'is_truncated': isTruncated ? 1 : 0,
    };
  }

  /// Deserializes a [PayloadData] from a database row or JSON map.
  factory PayloadData.fromMap(Map<String, dynamic> map) {
    final rawTruncated = map['is_truncated'];
    final bool isTruncated;
    if (rawTruncated is bool) {
      isTruncated = rawTruncated;
    } else if (rawTruncated is int) {
      isTruncated = rawTruncated == 1;
    } else if (rawTruncated is String) {
      isTruncated = rawTruncated.toLowerCase() == 'true' || rawTruncated == '1';
    } else {
      isTruncated = false;
    }

    final rawSize = map['byte_size'] ?? map['byteSize'] ?? 0;
    final int byteSize = (rawSize is num) ? rawSize.toInt() : int.tryParse(rawSize.toString()) ?? 0;

    return PayloadData(
      body: map['body'] as String?,
      byteSize: byteSize,
      bodyType: BodyType.fromString(
        map['body_type'] as String? ?? map['bodyType'] as String?,
      ),
      isTruncated: isTruncated,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PayloadData &&
        other.body == body &&
        other.byteSize == byteSize &&
        other.bodyType == bodyType &&
        other.isTruncated == isTruncated;
  }

  @override
  int get hashCode => Object.hash(body, byteSize, bodyType, isTruncated);

  @override
  String toString() {
    return 'PayloadData(body: ${body != null ? (body!.length > 50 ? "${body!.substring(0, 50)}..." : body) : null}, '
        'byteSize: $byteSize, bodyType: $bodyType, isTruncated: $isTruncated)';
  }
}
