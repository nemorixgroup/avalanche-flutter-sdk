// ---- GlacierTransaction ----

/// A native transaction returned by the Glacier Data API.
///
/// Used for the items of `transactions:listNative` and for the
/// `nativeTransaction` object returned by `GET /chains/{chainId}/transactions/{txHash}`.
///
/// Sources:
/// - build.avax.network/docs/api-reference/data-api/evm-transactions/listNativeTransactions
/// - build.avax.network/docs/api-reference/data-api/evm-transactions/getTransaction
class GlacierTransaction {
  /// Creates a [GlacierTransaction] from the given fields.
  const GlacierTransaction({
    required this.txHash,
    required this.blockNumber,
    required this.blockTimestamp,
    required this.from,
    required this.to,
    required this.value,
    required this.gasUsed,
    required this.gasPrice,
    required this.txStatus,
    required this.chainId,
  });

  /// Parses a [GlacierTransaction] from a Glacier native transaction object.
  factory GlacierTransaction.fromJson(Map<String, dynamic> json) {
    return GlacierTransaction(
      txHash: json['txHash'] as String,
      blockNumber: json['blockNumber'] as String,
      blockTimestamp: json['blockTimestamp'] as int,
      from: _addressOf(json['from']),
      to: _addressOf(json['to']),
      value: json['value'] as String? ?? '0',
      gasUsed: json['gasUsed'] as String? ?? '0',
      gasPrice: json['gasPrice'] as String? ?? '0',
      txStatus: json['txStatus'] as String? ?? '',
      chainId: json['chainId'] as String? ?? '',
    );
  }

  /// The transaction hash.
  final String txHash;

  /// The block number as a string (values can be large).
  final String blockNumber;

  /// Unix timestamp (seconds) of the block.
  final int blockTimestamp;

  /// The sender address.
  final String from;

  /// The recipient address (empty for contract creation).
  final String to;

  /// The value transferred in Wei, as a string to avoid overflow.
  final String value;

  /// Gas used by the transaction.
  final String gasUsed;

  /// Gas price in Wei, as reported by Glacier.
  final String gasPrice;

  /// Transaction status as reported by Glacier: "1" success, "0" failure.
  final String txStatus;

  /// The chain ID.
  final String chainId;

  /// Returns true if the transaction was successful.
  bool get isSuccess => txStatus == '1';

  /// Returns the value in AVAX (value / 10^18).
  double get valueInAvax =>
      (BigInt.tryParse(value) ?? BigInt.zero).toDouble() / 1e18;

  static String _addressOf(Object? node) {
    if (node is Map<String, dynamic>) {
      return node['address'] as String? ?? '';
    }
    return '';
  }

  @override
  String toString() =>
      'GlacierTransaction(txHash: $txHash, from: $from, to: $to, '
      'value: $value)';
}
