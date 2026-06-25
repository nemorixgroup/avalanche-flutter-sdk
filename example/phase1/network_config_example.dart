import 'package:avalanche_flutter_sdk/avalanche_flutter_sdk.dart';

/// Phase 1 - Network Configuration Examples
///
/// Demonstrates how to initialize [AvalancheClient] with different
/// network configurations.
///
/// Source: https://docs.avax.network/docs/tooling/rpc-providers
Future<void> networkConfigExamples() async {
  print('');
  print('======================================');
  print('  Phase 1: Network Configuration');
  print('======================================');

  // ---- Example 1: Fuji Testnet ----
  print('');
  print('--- Example 1: Fuji Testnet ---');

  final fujiClient = AvalancheClient(network: NetworkConfig.fuji);

  print('Network ID  : ${fujiClient.network.networkId}');
  print('C-Chain RPC : ${fujiClient.network.cChainRpcUrl}');
  print('P-Chain RPC : ${fujiClient.network.pChainRpcUrl}');
  print('X-Chain RPC : ${fujiClient.network.xChainRpcUrl}');
  print('Glacier API : ${fujiClient.network.glacierApiUrl}');

  // ---- Example 2: Mainnet ----
  print('');
  print('--- Example 2: Mainnet ---');

  final mainnetClient = AvalancheClient(network: NetworkConfig.mainnet);

  print('Network ID  : ${mainnetClient.network.networkId}');
  print('C-Chain RPC : ${mainnetClient.network.cChainRpcUrl}');
  print('P-Chain RPC : ${mainnetClient.network.pChainRpcUrl}');
  print('X-Chain RPC : ${mainnetClient.network.xChainRpcUrl}');
  print('Glacier API : ${mainnetClient.network.glacierApiUrl}');

  // ---- Example 3: NetworkId enum ----
  print('');
  print('--- Example 3: NetworkId enum ---');

  for (final id in NetworkId.values) {
    print('NetworkId.${id.name} = ${id.value}');
  }

  print('');
  print('Phase 1 examples complete.');
}
