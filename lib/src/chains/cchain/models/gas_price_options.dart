import 'package:avalanche_flutter_sdk/src/chains/cchain/models/gas_price_option.dart';

// ---- GasPriceOptions ----

/// Suggested gas price options for Avalanche C-Chain EIP-1559 transactions.
///
/// Returned by `CChainClient.suggestPriceOptions` which calls
/// the Avalanche-specific `eth_suggestPriceOptions` JSON-RPC method.
///
/// Source:
/// https://build.avax.network/docs/rpcs/c-chain#eth_suggestpriceoptions
///
/// "Returns suggested gas price options (slow, normal, fast) for the current
/// network conditions. Each option includes a maxPriorityFeePerGas and a
/// maxFeePerGas value."
class GasPriceOptions {
  /// Creates a [GasPriceOptions] with slow, normal, and fast tiers.
  const GasPriceOptions({
    required this.slow,
    required this.normal,
    required this.fast,
  });

  /// Low priority - cheaper but may take longer to be included.
  final GasPriceOption slow;

  /// Standard priority - good balance of speed and cost.
  final GasPriceOption normal;

  /// High priority - faster inclusion, higher cost.
  final GasPriceOption fast;

  @override
  String toString() => 'GasPriceOptions(\n'
      '  slow:   $slow\n'
      '  normal: $normal\n'
      '  fast:   $fast\n'
      ')';
}
