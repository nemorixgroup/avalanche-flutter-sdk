// ---- WebSocketStatus ----

/// The state changes reported by `CChainWebSocketClient.status`.
enum WebSocketStatus {
  /// The connection was opened with `connect()`.
  connected,

  /// The connection was lost and the client is trying to restore it.
  ///
  /// Only reported when the client has a `ReconnectPolicy`.
  reconnecting,

  /// The connection was restored and every active subscription was
  /// re-established.
  ///
  /// Events emitted while the client was disconnected are not replayed: this
  /// is the moment to fill the gap, for example with `eth_getLogs` or the
  /// `GlacierClient`.
  reconnected,

  /// The connection is closed: `close()` was called, the connection was lost
  /// and no `ReconnectPolicy` is set, or the policy ran out of attempts.
  disconnected,
}
