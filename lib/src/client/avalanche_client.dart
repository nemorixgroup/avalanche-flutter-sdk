import 'package:avalanche_flutter_sdk/src/client/network_config.dart';

// ---- AvalancheClient ----

/// Main entry point for the Avalanche Flutter SDK.
///
/// Provides access to all Avalanche chain clients and services.
///
/// Example:
/// ```dart
/// final client = AvalancheClient(network: NetworkConfig.fuji);
/// ```
class AvalancheClient {
  // ---- Constructor ----

  /// Creates an [AvalancheClient] connected to the given [network].
  AvalancheClient({required this.network});

  // ---- Fields ----

  /// The network configuration (Mainnet or Fuji Testnet).
  final NetworkConfig network;
}
