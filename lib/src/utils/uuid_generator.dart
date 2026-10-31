import 'package:uuid/uuid.dart';

/// RFC 4122 v4 UUID generator utility for unique request IDs and transaction correlation.
abstract final class UuidGenerator {
  const UuidGenerator._();

  static const Uuid _uuid = Uuid();

  /// Generates a cryptographically random RFC 4122 v4 UUID string.
  static String v4() => _uuid.v4();
}
