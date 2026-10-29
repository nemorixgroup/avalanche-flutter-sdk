// ---- GlacierErc20Transfer ----

/// An ERC-20 token transfer returned by the Glacier Data API.
///
/// Items of `transactions:listErc20`. These are token transfer events, not
/// full transactions, so they carry no gas or status fields.
///
/// Source:
/// build.avax.network/docs/api-reference/data-api/evm-transactions/listErc20Transactions
class GlacierErc20Transfer {
  /// Creates a [GlacierErc20Transfer] from the given fields.
  const GlacierErc20Transfer({
    required this.txHash,
    required this.blockNumber,
    required this.blockTimestamp,
    required this.from,
    required this.to,
    required this.logIndex,
    required this.value,
    required this.tokenAddress,
    required this.tokenName,
    required this.tokenSymbol,
    required this.tokenDecimals,
  });

  /// Parses a [GlacierErc20Transfer] from a Glacier transfer object.
  factory GlacierErc20Transfer.fromJson(Map<String, dynamic> json) {
    final token =
        json['erc20Token'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return GlacierErc20Transfer(
      txHash: json['txHash'] as String,
      blockNumber: json['blockNumber'] as String,
      blockTimestamp: json['blockTimestamp'] as int,
      from: _addressOf(json['from']),
      to: _addressOf(json['to']),
      logIndex: json['logIndex'] as int? ?? 0,
      value: BigInt.parse(json['value'] as String? ?? '0'),
      tokenAddress: token['address'] as String? ?? '',
      tokenName: token['name'] as String? ?? '',
      tokenSymbol: token['symbol'] as String? ?? '',
      tokenDecimals: token['decimals'] as int? ?? 18,
    );
  }

  /// The hash of the transaction that emitted this transfer.
  final String txHash;

  /// The block number as a string.
  final String blockNumber;

  /// Unix timestamp (seconds) of the block.
  final int blockTimestamp;

  /// The sender address.
  final String from;

  /// The recipient address.
  final String to;

  /// The log index of the transfer event within the block.
  final int logIndex;

  /// The raw amount transferred, in the token's smallest unit.
  final BigInt value;

  /// The ERC-20 contract address.
  final String tokenAddress;

  /// The token name (e.g. "USD Coin").
  final String tokenName;

  /// The token symbol (e.g. "USDC").
  final String tokenSymbol;

  /// The token decimals (e.g. 6 for USDC).
  final int tokenDecimals;

  /// Returns the amount in human-readable units (value / 10^decimals).
  double get valueInTokens =>
      value.toDouble() / BigInt.from(10).pow(tokenDecimals).toDouble();

  static String _addressOf(Object? node) {
    if (node is Map<String, dynamic>) {
      return node['address'] as String? ?? '';
    }
    return '';
  }

  @override
  String toString() =>
      'GlacierErc20Transfer(txHash: $txHash, symbol: $tokenSymbol, '
      'value: $value)';
}
