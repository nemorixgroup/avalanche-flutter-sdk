import 'package:avalanche_flutter_sdk/src/chains/cchain/erc20/erc20_constants.dart';
import 'package:avalanche_flutter_sdk/src/chains/cchain/websocket/models/evm_log.dart';
import 'package:avalanche_flutter_sdk/src/utils/hex_quantity.dart';

// ---- Erc20TransferEvent ----

/// An ERC-20 `Transfer(address,address,uint256)` event decoded from an
/// [EvmLog].
///
/// The sender and the recipient are indexed topics and the amount is the
/// event data. Addresses are returned in lowercase `0x` hex.
///
/// Source: https://eips.ethereum.org/EIPS/eip-20
class Erc20TransferEvent {
  /// Creates an [Erc20TransferEvent] from already decoded values.
  const Erc20TransferEvent({
    required this.token,
    required this.from,
    required this.to,
    required this.value,
    required this.transactionHash,
    required this.blockNumber,
    required this.logIndex,
    required this.removed,
  });

  /// Decodes an ERC-20 `Transfer` event from [log].
  ///
  /// Throws a [FormatException] if the log is not an ERC-20 `Transfer`: a
  /// different event signature, a number of topics other than three (an
  /// ERC-721 `Transfer` has four), or data that is not a single 32-byte
  /// amount.
  factory Erc20TransferEvent.fromLog(EvmLog log) {
    final topic0 = log.topic0?.toLowerCase();
    if (topic0 != ERC20Constants.transferEventTopic) {
      throw FormatException('Not an ERC-20 Transfer log: topic0 is $topic0');
    }
    if (log.topics.length != 3) {
      throw FormatException(
        'Not an ERC-20 Transfer log: expected 3 topics, got '
        '${log.topics.length} (an ERC-721 Transfer has 4)',
      );
    }
    if (!_amountPattern.hasMatch(log.data)) {
      throw const FormatException(
        'Not an ERC-20 Transfer log: data is not a 32-byte amount',
      );
    }
    return Erc20TransferEvent(
      token: log.address.toLowerCase(),
      from: _addressFromTopic(log.topics[1]),
      to: _addressFromTopic(log.topics[2]),
      value: hexToBigInt(log.data),
      transactionHash: log.transactionHash,
      blockNumber: log.blockNumber,
      logIndex: log.logIndex,
      removed: log.removed,
    );
  }

  /// The ERC-20 contract that emitted the event (lowercase).
  final String token;

  /// The sender address (lowercase).
  final String from;

  /// The recipient address (lowercase).
  final String to;

  /// The amount in the token's smallest unit.
  final BigInt value;

  /// The hash of the transaction that emitted the event.
  final String transactionHash;

  /// The number of the block that contains the event.
  final int blockNumber;

  /// The index of the event log inside the block.
  final int logIndex;

  /// True if the event belongs to a chain that was reorganized away.
  ///
  /// When it is true, undo whatever you did when you first saw the transfer.
  final bool removed;

  /// The amount in human-readable units (value / 10^[decimals]).
  ///
  /// For display only: a `double` is not exact for large token amounts.
  double valueInTokens(int decimals) =>
      value.toDouble() / BigInt.from(10).pow(decimals).toDouble();

  static final RegExp _paddedAddress = RegExp(r'^0x0{24}([0-9a-fA-F]{40})$');
  static final RegExp _amountPattern = RegExp(r'^0x[0-9a-fA-F]{64}$');

  static String _addressFromTopic(String topic) {
    final match = _paddedAddress.firstMatch(topic);
    if (match == null) {
      throw FormatException(
        'Not an ERC-20 Transfer log: topic is not a padded address: $topic',
      );
    }
    return '0x${match.group(1)!.toLowerCase()}';
  }

  @override
  String toString() =>
      'Erc20TransferEvent(token: $token, from: $from, to: $to, '
      'value: $value, tx: $transactionHash, removed: $removed)';
}
