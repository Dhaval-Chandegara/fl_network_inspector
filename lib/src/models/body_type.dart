/// Enumeration of supported payload body types in network requests and responses.
enum BodyType {
  /// Structured JSON format.
  json,

  /// Plain text, HTML, XML, or unstructured string content.
  text,

  /// URL-encoded form data (`application/x-www-form-urlencoded`).
  formData,

  /// Multi-part form data containing parameters and file upload references.
  multipart,

  /// Binary octet stream or raw byte content.
  binary,

  /// Empty or absent request/response body.
  empty;

  /// Serializes the [BodyType] to its string representation.
  String toJson() => name;

  /// Parses a string representation into a [BodyType].
  static BodyType fromString(String? value) {
    if (value == null || value.trim().isEmpty) return BodyType.empty;
    return BodyType.values.firstWhere(
      (type) => type.name.toLowerCase() == value.trim().toLowerCase(),
      orElse: () => BodyType.text,
    );
  }
}
