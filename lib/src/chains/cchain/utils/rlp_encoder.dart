import 'dart:typed_data';

/// Recursive Length Prefix (RLP) encoder for Ethereum transactions.
///
/// RLP is the primary encoding method used to serialize objects in
/// Ethereum and Avalanche C-Chain. Used internally to build EIP-1559
/// transaction payloads before signing and broadcast.
///
/// Supports encoding:
/// - [BigInt]: as minimal big-endian bytes (zero -> empty bytes)
/// - [int]: as minimal big-endian bytes (zero -> empty bytes)
/// - [Uint8List]: as byte string
/// - [List]: as RLP list of recursively encoded items
///
/// Source:
/// https://ethereum.org/en/developers/docs/data-structures-and-encoding/rlp/
class RlpEncoder {
  RlpEncoder._();

  // ---- Public API ----

  /// Encodes [input] using RLP encoding.
  ///
  /// Throws [ArgumentError] if [input] contains an unsupported type.
  static Uint8List encode(dynamic input) {
    if (input is List && input is! Uint8List) {
      return _encodeList(input);
    }
    return _encodeBytes(_toBytes(input));
  }

  // ---- Internal: List encoding ----

  static Uint8List _encodeList(List<dynamic> items) {
    final encodedItems = items.map(encode).toList();
    final payload = _concat(encodedItems);
    return Uint8List.fromList([
      ..._encodeLength(payload.length, 0xc0),
      ...payload,
    ]);
  }

  // ---- Internal: Byte string encoding ----

  static Uint8List _encodeBytes(Uint8List bytes) {
    if (bytes.length == 1 && bytes[0] < 0x80) {
      return bytes; // single byte [0x00, 0x7f]: encode as-is
    }
    return Uint8List.fromList([
      ..._encodeLength(bytes.length, 0x80),
      ...bytes,
    ]);
  }

  // ---- Internal: Type conversion ----

  static Uint8List _toBytes(dynamic input) {
    if (input is Uint8List) return input;
    if (input is BigInt) return _bigIntToBytes(input);
    if (input is int) return _bigIntToBytes(BigInt.from(input));
    throw ArgumentError(
      'RlpEncoder: unsupported type ${input.runtimeType}. '
      'Supported: BigInt, int, Uint8List, List.',
    );
  }

  static Uint8List _bigIntToBytes(BigInt value) {
    if (value == BigInt.zero) return Uint8List(0); // zero = empty bytes
    if (value < BigInt.zero) {
      throw ArgumentError('RlpEncoder: negative values are not supported.');
    }
    final hex = value.toRadixString(16);
    final padded = hex.length.isOdd ? '0$hex' : hex;
    return Uint8List.fromList(
      List.generate(
        padded.length ~/ 2,
        (i) => int.parse(padded.substring(i * 2, i * 2 + 2), radix: 16),
      ),
    );
  }

  // ---- Internal: Length prefix ----

  /// Encodes the length prefix for strings (offset=0x80)
  /// or lists (offset=0xc0).
  ///
  /// Per RLP spec:
  /// - length < 56: single byte = offset + length
  /// - length >= 56: (offset + 55 + len(len)) || big-endian(length)
  static List<int> _encodeLength(int length, int offset) {
    if (length < 56) {
      return [length + offset];
    }
    final hex = length.toRadixString(16);
    final padded = hex.length.isOdd ? '0$hex' : hex;
    final lengthBytes = List<int>.generate(
      padded.length ~/ 2,
      (i) => int.parse(padded.substring(i * 2, i * 2 + 2), radix: 16),
    );
    return [offset + 55 + lengthBytes.length, ...lengthBytes];
  }

  // ---- Internal: Concat ----

  static Uint8List _concat(List<Uint8List> arrays) {
    final totalLength = arrays.fold(0, (sum, arr) => sum + arr.length);
    final result = Uint8List(totalLength);
    var offset = 0;
    for (final arr in arrays) {
      result.setAll(offset, arr);
      offset += arr.length;
    }
    return result;
  }
}
