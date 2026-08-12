import 'package:avalanche_flutter_sdk/src/chains/cchain/cchain_client.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/models/gas_price_option.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/models/gas_price_options.dart';

// ---- GasEstimator ----

/// Estimates EIP-1559 gas fees for Avalanche C-Chain transactions.
///
/// Wraps [CChainClient] and provides higher-level gas estimation using
/// the Avalanche-specific `eth_suggestPriceOptions` method, which returns
/// ready-to-use slow/normal/fast fee options.
///
/// EIP-1559 fee model on Avalanche:
/// ```dart
/// effectiveFee = min(maxFeePerGas, baseFee + maxPriorityFeePerGas)
/// ```
///
/// Note: Unlike Ethereum, on Avalanche BOTH the base fee AND the priority
/// fee are burned. No fee goes to validators.
///
/// Sources:
/// - https://build.avax.network/docs/rpcs/c-chain#eth_suggestpriceoptions
/// - https://build.avax.network/docs/rpcs/other/guides/txn-fees
class GasEstimator {
  // ---- Constructor ----

  /// Creates a [GasEstimator] backed by the given [CChainClient].
  GasEstimator(this._client);

  // ---- Fields ----

  final CChainClient _client;

  /// Standard gas limit for a simple AVAX transfer (EIP-1559).
  ///
  /// 21,000 gas is the fixed cost for a simple ETH/AVAX transfer.
  /// Source: Ethereum Yellow Paper - intrinsic gas cost.
  static const int avaxTransferGasLimit = 21000;

  // ---- Public API ----

  /// Returns all three gas price options (slow, normal, fast).
  ///
  /// Uses `eth_suggestPriceOptions` - Avalanche-specific method.
  /// Recommended for most use cases since it provides ready-to-use values.
  ///
  /// Source: https://build.avax.network/docs/rpcs/c-chain#eth_suggestpriceoptions
  Future<GasPriceOptions> getPriceOptions() => _client.suggestPriceOptions();

  /// Returns the current base fee in Wei.
  ///
  /// Uses `eth_baseFee` - Avalanche-specific method.
  /// Minimum value: 1 nAVAX (1 Gwei = 10^9 Wei).
  ///
  /// Source: https://build.avax.network/docs/rpcs/c-chain#eth_basefee
  Future<BigInt> getBaseFee() => _client.getBaseFee();

  /// Returns the [GasPriceOption] for the [speed] tier.
  ///
  /// Convenience method to get a single option without dealing with
  /// the full [GasPriceOptions] object.
  Future<GasPriceOption> getOption(GasSpeed speed) async {
    final options = await getPriceOptions();
    switch (speed) {
      case GasSpeed.slow:
        return options.slow;
      case GasSpeed.normal:
        return options.normal;
      case GasSpeed.fast:
        return options.fast;
    }
  }

  /// Estimates the total transaction fee in Wei for a simple AVAX transfer.
  ///
  /// Uses [GasSpeed.normal] by default.
  /// Total fee = maxFeePerGas * gasLimit (worst case).
  /// Actual fee = effectiveFee * gasLimit.
  Future<BigInt> estimateTransferFee({
    GasSpeed speed = GasSpeed.normal,
  }) async {
    final option = await getOption(speed);
    return option.maxFeePerGas * BigInt.from(avaxTransferGasLimit);
  }
}

// ---- GasSpeed ----

/// The speed tier for gas price estimation.
enum GasSpeed {
  /// Lower cost, may take longer to be included in a block.
  slow,

  /// Balanced cost and speed - recommended for most transactions.
  normal,

  /// Higher cost, prioritized for faster inclusion.
  fast,
}
