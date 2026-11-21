import 'package:avalanche_flutter_sdk/src/utils/hex_quantity.dart';

// ---- NewHead ----

/// A block header received from an `eth_subscribe("newHeads")` subscription.
///
/// The C-Chain header carries Avalanche-specific fields (for example
/// `settledHeight` and `timestampMilliseconds`) and its layout changes
/// between network upgrades. Only the stable subset is typed; every field
/// the node sent, typed or not, stays available in [raw].
///
/// Source: https://build.avax.network/docs/rpcs/c-chain
class NewHead {
  /// Creates a [NewHead] from already parsed values.
  const NewHead({
    required this.hash,
    required this.parentHash,
    required this.number,
    required this.timestamp,
    required this.gasUsed,
    required this.gasLimit,
    required this.miner,
    required this.raw,
    this.baseFeePerGas,
    this.timestampMilliseconds,
  });

  /// Parses the `result` object of a `newHeads` notification.
  ///
  /// Throws a [TypeError] if a required field is missing and a
  /// [FormatException] if a quantity is not valid hexadecimal.
  factory NewHead.fromJson(Map<String, dynamic> json) {
    final baseFee = json['baseFeePerGas'];
    final millis = json['timestampMilliseconds'];
    return NewHead(
      hash: json['hash'] as String,
      parentHash: json['parentHash'] as String,
      number: hexToInt(json['number'] as String),
      timestamp: hexToInt(json['timestamp'] as String),
      gasUsed: hexToBigInt(json['gasUsed'] as String),
      gasLimit: hexToBigInt(json['gasLimit'] as String),
      miner: json['miner'] as String? ?? '',
      baseFeePerGas: baseFee is String ? hexToBigInt(baseFee) : null,
      timestampMilliseconds: millis is String ? hexToInt(millis) : null,
      raw: Map<String, dynamic>.unmodifiable(json),
    );
  }

  /// The block hash.
  final String hash;

  /// The hash of the parent block.
  final String parentHash;

  /// The block number.
  final int number;

  /// The block timestamp in seconds since the Unix epoch.
  final int timestamp;

  /// The gas used by the block.
  final BigInt gasUsed;

  /// The gas limit of the block.
  final BigInt gasLimit;

  /// The `miner` field of the header.
  final String miner;

  /// The base fee per gas in Wei, if the header includes it.
  final BigInt? baseFeePerGas;

  /// The block timestamp in milliseconds, if the header includes it.
  ///
  /// This is an Avalanche-specific header field.
  final int? timestampMilliseconds;

  /// The complete header exactly as sent by the node (unmodifiable).
  final Map<String, dynamic> raw;

  /// The block time in UTC, using millisecond precision when available.
  DateTime get time => DateTime.fromMillisecondsSinceEpoch(
        timestampMilliseconds ?? timestamp * 1000,
        isUtc: true,
      );

  @override
  String toString() => 'NewHead(number: $number, hash: $hash)';
}
