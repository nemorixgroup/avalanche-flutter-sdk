import 'package:avalanche_flutter_sdk/src/utils/hex_quantity.dart';

// ---- AcceptedTransaction ----

/// A transaction received from `eth_subscribe("newAcceptedTransactions")`
/// when the subscription was created with `fullTx: true`.
///
/// The stream carries every transaction accepted on the chain. The fee
/// fields differ by type: legacy transactions (`type` 0) have no
/// [maxFeePerGas], [maxPriorityFeePerGas], [accessList] or [yParity].
/// [to] is null for contract creation.
///
/// Source: https://build.avax.network/docs/rpcs/c-chain
class AcceptedTransaction {
  /// Creates an [AcceptedTransaction] from already parsed values.
  const AcceptedTransaction({
    required this.hash,
    required this.blockHash,
    required this.blockNumber,
    required this.transactionIndex,
    required this.from,
    required this.value,
    required this.gas,
    required this.gasPrice,
    required this.nonce,
    required this.input,
    required this.type,
    required this.v,
    required this.r,
    required this.s,
    this.to,
    this.chainId,
    this.maxFeePerGas,
    this.maxPriorityFeePerGas,
    this.accessList,
    this.yParity,
  });

  /// Parses the `result` object of a `newAcceptedTransactions`
  /// notification created with `fullTx: true`.
  ///
  /// Throws a [TypeError] if a required field is missing and a
  /// [FormatException] if a quantity is not valid hexadecimal.
  factory AcceptedTransaction.fromJson(Map<String, dynamic> json) {
    final to = json['to'];
    final chainId = json['chainId'];
    final maxFee = json['maxFeePerGas'];
    final maxPriority = json['maxPriorityFeePerGas'];
    final accessList = json['accessList'];
    final yParity = json['yParity'];
    return AcceptedTransaction(
      hash: json['hash'] as String,
      blockHash: json['blockHash'] as String,
      blockNumber: hexToInt(json['blockNumber'] as String),
      transactionIndex: hexToInt(json['transactionIndex'] as String),
      from: json['from'] as String,
      to: to is String ? to : null,
      value: hexToBigInt(json['value'] as String),
      gas: hexToBigInt(json['gas'] as String),
      gasPrice: hexToBigInt(json['gasPrice'] as String),
      nonce: hexToInt(json['nonce'] as String),
      input: json['input'] as String? ?? '0x',
      type: hexToInt(json['type'] as String),
      chainId: chainId is String ? hexToInt(chainId) : null,
      v: hexToBigInt(json['v'] as String),
      r: hexToBigInt(json['r'] as String),
      s: hexToBigInt(json['s'] as String),
      maxFeePerGas: maxFee is String ? hexToBigInt(maxFee) : null,
      maxPriorityFeePerGas:
          maxPriority is String ? hexToBigInt(maxPriority) : null,
      accessList: accessList is List<dynamic>
          ? List<Object?>.unmodifiable(accessList)
          : null,
      yParity: yParity is String ? hexToInt(yParity) : null,
    );
  }

  /// The transaction hash.
  final String hash;

  /// The hash of the block that accepted the transaction.
  final String blockHash;

  /// The number of the block that accepted the transaction.
  final int blockNumber;

  /// The index of the transaction inside the block.
  final int transactionIndex;

  /// The sender address (lowercase).
  final String from;

  /// The recipient address, or null for contract creation.
  final String? to;

  /// The value sent, in Wei.
  final BigInt value;

  /// The gas limit of the transaction.
  final BigInt gas;

  /// The gas price in Wei, as reported by the node.
  final BigInt gasPrice;

  /// The sender nonce.
  final int nonce;

  /// The calldata as a `0x` hex string. It can be large.
  final String input;

  /// The transaction type: 0 legacy, 2 EIP-1559.
  final int type;

  /// The chain ID, if the transaction carries one.
  final int? chainId;

  /// The signature `v` value.
  final BigInt v;

  /// The signature `r` value.
  final BigInt r;

  /// The signature `s` value.
  final BigInt s;

  /// The EIP-1559 maximum fee per gas in Wei (type 2 only).
  final BigInt? maxFeePerGas;

  /// The EIP-1559 maximum priority fee per gas in Wei (type 2 only).
  final BigInt? maxPriorityFeePerGas;

  /// The EIP-2930 access list (type 2 only).
  final List<Object?>? accessList;

  /// The signature y parity, 0 or 1 (type 2 only).
  final int? yParity;

  /// True if the transaction creates a contract ([to] is null).
  bool get isContractCreation => to == null;

  /// True for an EIP-1559 (type 2) transaction.
  bool get isEip1559 => type == 2;

  /// The value in AVAX (value / 10^18), for display only.
  double get valueInAvax => value.toDouble() / 1e18;

  @override
  String toString() => 'AcceptedTransaction(hash: $hash, from: $from, to: $to, '
      'block: $blockNumber)';
}
