// ---- NetworkId ----

/// Avalanche network identifiers.
///
/// Source:
/// https://docs.avax.network/docs/api-reference/standards/avalanche-network-protocol
enum NetworkId {
  /// Avalanche Mainnet (network ID: 1).
  mainnet(1),

  /// Avalanche Fuji Testnet (network ID: 5).
  fuji(5);

  // ---- Constructor ----

  const NetworkId(this.value);

  // ---- Fields ----

  /// The numeric network ID used in API calls.
  final int value;
}
