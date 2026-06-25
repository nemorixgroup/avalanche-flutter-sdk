// ---- AvalancheException ----

/// Base exception for all Avalanche Flutter SDK errors.
class AvalancheException implements Exception {
  // ---- Constructor ----

  /// Creates an [AvalancheException] with the given [message].
  const AvalancheException(this.message);

  // ---- Fields ----

  /// Human-readable description of the error.
  final String message;

  // ---- Overrides ----

  @override
  String toString() => 'AvalancheException: $message';
}
