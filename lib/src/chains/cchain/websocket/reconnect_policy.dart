// ---- ReconnectPolicy ----

/// How `CChainWebSocketClient` reconnects after it loses the connection.
///
/// Without a policy the client does not reconnect: every active stream ends
/// with an error. With a policy it retries with exponential backoff: the
/// delay starts at [initialDelay], doubles after each failed attempt and is
/// capped at [maxDelay].
class ReconnectPolicy {
  /// Creates a [ReconnectPolicy].
  ///
  /// Use a non-zero [initialDelay]: a zero delay retries in a tight loop.
  const ReconnectPolicy({
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.maxAttempts,
  });

  /// The wait before the first attempt after a connection loss.
  final Duration initialDelay;

  /// The longest wait between two attempts.
  final Duration maxDelay;

  /// The number of failed attempts after which the client gives up, or null
  /// to keep trying until the connection is restored or the client is
  /// closed.
  ///
  /// The count restarts at every connection loss.
  final int? maxAttempts;

  /// The wait before attempt number [attempt] (the first attempt is 1).
  Duration delayForAttempt(int attempt) {
    var delay = initialDelay;
    for (var i = 1; i < attempt; i++) {
      delay *= 2;
      if (delay >= maxDelay) return maxDelay;
    }
    return delay > maxDelay ? maxDelay : delay;
  }
}
