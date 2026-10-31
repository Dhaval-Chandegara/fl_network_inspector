import 'package:flutter/foundation.dart';

/// Metadata representing an individual entry within a multipart/form-data upload.
///
/// Raw binary content is discarded per architectural design (D-16).
/// [filePath] defaults to `null` to protect local device filesystem privacy (D-15).
@immutable
class MultipartEntry {
  /// The parameter or form field name.
  final String fieldName;

  /// The original uploaded file name, if available.
  final String? fileName;

  /// The declared MIME type (e.g., `image/png`, `application/pdf`).
  final String? contentType;

  /// The size in bytes of the uploaded file/entry.
  final int byteSize;

  /// The local file system path, only populated if explicitly permitted by configuration (D-15).
  final String? filePath;

  /// Creates a [MultipartEntry] instance.
  const MultipartEntry({
    required this.fieldName,
    this.fileName,
    this.contentType,
    this.byteSize = 0,
    this.filePath,
  });

  /// Creates a copy of this [MultipartEntry] with updated properties.
  MultipartEntry copyWith({
    String? fieldName,
    String? fileName,
    String? contentType,
    int? byteSize,
    String? filePath,
  }) {
    return MultipartEntry(
      fieldName: fieldName ?? this.fieldName,
      fileName: fileName ?? this.fileName,
      contentType: contentType ?? this.contentType,
      byteSize: byteSize ?? this.byteSize,
      filePath: filePath ?? this.filePath,
    );
  }

  /// Converts this entry into a database- and JSON-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'field_name': fieldName,
      'file_name': fileName,
      'content_type': contentType,
      'byte_size': byteSize,
      'file_path': filePath,
    };
  }

  /// Deserializes a [MultipartEntry] from a map.
  factory MultipartEntry.fromMap(Map<String, dynamic> map) {
    final rawSize = map['byte_size'] ?? map['byteSize'] ?? 0;
    final int byteSize = (rawSize is num) ? rawSize.toInt() : int.tryParse(rawSize.toString()) ?? 0;

    return MultipartEntry(
      fieldName: (map['field_name'] ?? map['fieldName'] ?? '') as String,
      fileName: map['file_name'] as String? ?? map['fileName'] as String?,
      contentType: map['content_type'] as String? ?? map['contentType'] as String?,
      byteSize: byteSize,
      filePath: map['file_path'] as String? ?? map['filePath'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MultipartEntry &&
        other.fieldName == fieldName &&
        other.fileName == fileName &&
        other.contentType == contentType &&
        other.byteSize == byteSize &&
        other.filePath == filePath;
  }

  @override
  int get hashCode => Object.hash(fieldName, fileName, contentType, byteSize, filePath);

  @override
  String toString() {
    return 'MultipartEntry(fieldName: $fieldName, fileName: $fileName, '
        'contentType: $contentType, byteSize: $byteSize, filePath: $filePath)';
  }
}
