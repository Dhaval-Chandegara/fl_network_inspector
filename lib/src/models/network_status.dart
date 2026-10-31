/// Status lifecycle state of an HTTP transaction.
enum NetworkStatus {
  /// Request has been sent/intercepted and is awaiting server response.
  pending,

  /// Request completed with a valid HTTP response.
  success,

  /// Request encountered a network error, socket exception, timeout, or failure.
  failed;

  /// Serializes the [NetworkStatus] to its string representation.
  String toJson() => name;

  /// Parses a string representation into a [NetworkStatus].
  static NetworkStatus fromString(String? value) {
    if (value == null || value.trim().isEmpty) return NetworkStatus.pending;
    return NetworkStatus.values.firstWhere(
      (status) => status.name.toLowerCase() == value.trim().toLowerCase(),
      orElse: () => NetworkStatus.pending,
    );
  }
}
