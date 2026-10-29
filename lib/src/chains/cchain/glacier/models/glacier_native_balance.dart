// ---- GlacierNativeBalance ----

/// Native AVAX balance returned by the Glacier Data API.
///
/// Source:
/// build.avax.network/docs/api-reference/data-api/evm-balances/getNativeBalance
class GlacierNativeBalance {
  /// Creates a [GlacierNativeBalance] from the given fields.
  const GlacierNativeBalance({
    required this.balance,
    required this.chainId,
    required this.name,
    required this.symbol,
    required this.decimals,
  });

  /// Parses a [GlacierNativeBalance] from the Glacier API JSON response.
  ///
  /// Expects the `nativeTokenBalance` object from the API response.
  factory GlacierNativeBalance.fromJson(Map<String, dynamic> json) {
    return GlacierNativeBalance(
      balance: BigInt.parse(json['balance'] as String),
      chainId: json['chainId'] as String,
      name: json['name'] as String? ?? '',
      symbol: json['symbol'] as String? ?? '',
      decimals: json['decimals'] as int? ?? 18,
    );
  }

  /// The raw balance in the smallest unit (Wei for AVAX).
  final BigInt balance;

  /// The chain ID (e.g. "43114" for Mainnet, "43113" for Fuji).
  final String chainId;

  /// The token name (e.g. "Avalanche").
  final String name;

  /// The token symbol (e.g. "AVAX").
  final String symbol;

  /// The number of decimals (18 for AVAX).
  final int decimals;

  /// Returns the balance in AVAX (balance / 10^decimals).
  double get balanceInAvax =>
      balance.toDouble() / BigInt.from(10).pow(decimals).toDouble();

  @override
  String toString() =>
      'GlacierNativeBalance(balance: $balance, symbol: $symbol, '
      'chainId: $chainId)';
}
