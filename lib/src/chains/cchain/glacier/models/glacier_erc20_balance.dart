// ---- GlacierErc20Balance ----

/// ERC-20 token balance returned by the Glacier Data API.
///
/// Source:
/// build.avax.network/docs/api-reference/data-api/evm-balances/listErc20Balances
class GlacierErc20Balance {
  /// Creates a [GlacierErc20Balance] from the given fields.
  const GlacierErc20Balance({
    required this.address,
    required this.balance,
    required this.chainId,
    required this.name,
    required this.symbol,
    required this.decimals,
    this.logoUri,
    this.price,
    this.priceCurrency,
  });

  /// Parses a [GlacierErc20Balance] from a Glacier `erc20TokenBalances` item.
  ///
  /// The API returns `price` as an object `{currencyCode, value}` where
  /// `value` is a string; both are optional.
  factory GlacierErc20Balance.fromJson(Map<String, dynamic> json) {
    double? price;
    String? priceCurrency;
    final priceNode = json['price'];
    if (priceNode is Map<String, dynamic>) {
      final rawValue = priceNode['value'];
      price = rawValue is String ? double.tryParse(rawValue) : null;
      priceCurrency = priceNode['currencyCode'] as String?;
    }

    return GlacierErc20Balance(
      address: json['address'] as String,
      balance: BigInt.parse(json['balance'] as String),
      chainId: json['chainId'] as String,
      name: json['name'] as String? ?? '',
      symbol: json['symbol'] as String? ?? '',
      decimals: json['decimals'] as int? ?? 18,
      logoUri: json['logoUri'] as String?,
      price: price,
      priceCurrency: priceCurrency,
    );
  }

  /// The contract address of the ERC-20 token.
  final String address;

  /// The raw token balance in the smallest unit.
  final BigInt balance;

  /// The chain ID.
  final String chainId;

  /// The token name (e.g. "USD Coin").
  final String name;

  /// The token symbol (e.g. "USDC").
  final String symbol;

  /// The number of decimals (e.g. 6 for USDC, 18 for most tokens).
  final int decimals;

  /// Optional logo URI for the token.
  final String? logoUri;

  /// Optional unit price of the token, in [priceCurrency].
  final double? price;

  /// Currency code of [price] (e.g. "usd"). Glacier defaults to USD.
  final String? priceCurrency;

  /// Returns the balance in human-readable units (balance / 10^decimals).
  double get balanceInTokens =>
      balance.toDouble() / BigInt.from(10).pow(decimals).toDouble();

  @override
  String toString() =>
      'GlacierErc20Balance(symbol: $symbol, balance: $balance, '
      'address: $address)';
}
