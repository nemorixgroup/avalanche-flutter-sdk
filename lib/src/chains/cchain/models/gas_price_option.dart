// ---- GasPriceOption ----

/// A single gas price option for an EIP-1559 transaction on Avalanche C-Chain.
///
/// Contains the two fields required for EIP-1559 transactions:
/// - [maxPriorityFeePerGas]: the maximum tip per gas unit above the base fee
/// - [maxFeePerGas]: the total maximum fee per gas unit (base fee + tip)
///
/// Source:
/// https://build.avax.network/docs/rpcs/c-chain#eth_suggestpriceoptions
class GasPriceOption {
  /// Creates a [GasPriceOption] with the given fee values in Wei.
  const GasPriceOption({
    required this.maxPriorityFeePerGas,
    required this.maxFeePerGas,
  });

  /// Maximum priority fee per gas unit (tip), in Wei.
  final BigInt maxPriorityFeePerGas;

  /// Maximum total fee per gas unit (base fee + tip), in Wei.
  final BigInt maxFeePerGas;

  /// Effective gas price paid =
  ///         min(maxFeePerGas, baseFee + maxPriorityFeePerGas).
  ///
  /// Per Avalanche docs: both base fee and priority fee are burned.
  /// Source: https://build.avax.network/docs/rpcs/other/guides/txn-fees
  BigInt effectiveFee(BigInt baseFee) {
    return bigIntMin(maxFeePerGas, baseFee + maxPriorityFeePerGas);
  }

  /// Returns [maxPriorityFeePerGas] in nAVAX (Gwei equivalent).
  double get maxPriorityFeePerGasInNAvax =>
      maxPriorityFeePerGas.toDouble() / 1e9;

  /// Returns [maxFeePerGas] in nAVAX (Gwei equivalent).
  double get maxFeePerGasInNAvax => maxFeePerGas.toDouble() / 1e9;

  @override
  String toString() =>
      'GasPriceOption(maxPriorityFeePerGas: $maxPriorityFeePerGas Wei, '
      'maxFeePerGas: $maxFeePerGas Wei)';
}

/// Returns the minimum of two [BigInt] values.
BigInt bigIntMin(BigInt a, BigInt b) => a < b ? a : b;
