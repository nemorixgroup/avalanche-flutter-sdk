// ---- Network Configuration ----

/// Avalanche network configuration.
///
/// Provides official RPC endpoints for Mainnet and Fuji Testnet.
/// Source: https://docs.avax.network/docs/tooling/rpc-providers
class NetworkConfig {
  // ---- Constructor ----

  /// Creates a [NetworkConfig] with the given parameters.
  const NetworkConfig({
    required this.networkId,
    required this.cChainRpcUrl,
    required this.pChainRpcUrl,
    required this.xChainRpcUrl,
    required this.glacierApiUrl,
  });

  // ---- Fields ----

  /// The numeric network ID.
  final int networkId;

  /// C-Chain JSON-RPC endpoint.
  final String cChainRpcUrl;

  /// P-Chain JSON-RPC endpoint.
  final String pChainRpcUrl;

  /// X-Chain JSON-RPC endpoint.
  final String xChainRpcUrl;

  /// Glacier Data API base URL.
  final String glacierApiUrl;

  // ---- Presets ----

  /// Avalanche Mainnet configuration.
  static const NetworkConfig mainnet = NetworkConfig(
    networkId: 1,
    cChainRpcUrl: 'https://api.avax.network/ext/bc/C/rpc',
    pChainRpcUrl: 'https://api.avax.network/ext/bc/P',
    xChainRpcUrl: 'https://api.avax.network/ext/bc/X',
    glacierApiUrl: 'https://glacier-api.avax.network',
  );

  /// Avalanche Fuji Testnet configuration.
  static const NetworkConfig fuji = NetworkConfig(
    networkId: 5,
    cChainRpcUrl: 'https://api.avax-test.network/ext/bc/C/rpc',
    pChainRpcUrl: 'https://api.avax-test.network/ext/bc/P',
    xChainRpcUrl: 'https://api.avax-test.network/ext/bc/X',
    glacierApiUrl: 'https://glacier-api.avax.network',
  );
}
