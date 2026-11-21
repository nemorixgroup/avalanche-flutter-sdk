import 'package:avalanche_flutter_sdk/src/utils/hex_quantity.dart';

// ---- EvmLog ----

/// An event log received from an `eth_subscribe("logs")` subscription.
///
/// During a chain reorganization the node resends logs of the old chain
/// with [removed] set to `true`, so a handler must process both cases.
///
/// Source: https://build.avax.network/docs/rpcs/c-chain
class EvmLog {
  /// Creates an [EvmLog] from already parsed values.
  const EvmLog({
    required this.address,
    required this.topics,
    required this.data,
    required this.blockNumber,
    required this.blockHash,
    required this.transactionHash,
    required this.transactionIndex,
    required this.logIndex,
    required this.removed,
  });

  /// Parses the `result` object of a `logs` notification.
  ///
  /// Throws a [TypeError] if a required field is missing and a
  /// [FormatException] if a quantity is not valid hexadecimal.
  factory EvmLog.fromJson(Map<String, dynamic> json) {
    final topics = json['topics'] as List<dynamic>? ?? <dynamic>[];
    return EvmLog(
      address: json['address'] as String,
      topics: List<String>.unmodifiable(topics.cast<String>()),
      data: json['data'] as String? ?? '0x',
      blockNumber: hexToInt(json['blockNumber'] as String),
      blockHash: json['blockHash'] as String,
      transactionHash: json['transactionHash'] as String,
      transactionIndex: hexToInt(json['transactionIndex'] as String),
      logIndex: hexToInt(json['logIndex'] as String),
      removed: json['removed'] as bool? ?? false,
    );
  }

  /// The address of the contract that emitted the log (lowercase).
  final String address;

  /// The indexed topics. The first one identifies the event signature.
  final List<String> topics;

  /// The non-indexed event data as a `0x` hex string.
  final String data;

  /// The number of the block that contains the log.
  final int blockNumber;

  /// The hash of the block that contains the log.
  final String blockHash;

  /// The hash of the transaction that emitted the log.
  final String transactionHash;

  /// The index of the transaction inside the block.
  final int transactionIndex;

  /// The index of the log inside the block.
  final int logIndex;

  /// True if the log belongs to a chain that was reorganized away.
  final bool removed;

  /// The first topic (the event signature hash), or null if there are none.
  String? get topic0 => topics.isEmpty ? null : topics.first;

  @override
  String toString() =>
      'EvmLog(address: $address, tx: $transactionHash, removed: $removed)';
}
