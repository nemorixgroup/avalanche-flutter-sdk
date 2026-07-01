import 'dart:typed_data';

import 'package:pointycastle/export.dart' hide PublicKey;

// ---- CB58 ----

/// CB58 encoding and decoding, the binary-to-text format used across
/// the Avalanche ecosystem for private keys, node IDs, and addresses.
///
/// Source: https://support.avax.network/en/articles/4587395-what-is-cb58
/// "CB58 is the concatenation of the data bytes and a checksum. The
/// checksum is created by taking the last four bytes of the SHA256
/// hash of the data bytes. This concatenated output is then mapped to
/// a base-58 string."
///
/// Verified against the official AvalancheJS implementation:
/// https://github.com/ava-labs/avalanchejs/blob/master/src/utils/base58.ts
class CB58 {
  // ---- Constants ----

  /// The Base58 alphabet used by Bitcoin and Avalanche (CB58).
  /// Excludes visually ambiguous characters: 0 (zero), O (capital o),
  /// I (capital i), l (lowercase L).
  static const String _alphabet =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  static const int _checksumLength = 4;

  // ---- Public API: Encode ----

  /// Encodes raw [data] bytes into a CB58 string.
  ///
  /// Computes `data + SHA256(data)[-4:]`, then encodes the result in
  /// Base58.
  static String encode(Uint8List data) {
    final checksum = _sha256(data).sublist(32 - _checksumLength);
    final payload = Uint8List.fromList([...data, ...checksum]);
    return _base58Encode(payload);
  }

  // ---- Public API: Decode ----

  /// Decodes a CB58 [encoded] string back into its raw data bytes.
  ///
  /// Verifies the embedded checksum and throws [ArgumentError] if it
  /// does not match the recomputed SHA256 checksum of the data.
  static Uint8List decode(String encoded) {
    final payload = _base58Decode(encoded);

    if (payload.length < _checksumLength) {
      throw ArgumentError(
        'Invalid CB58 string: payload too short to contain a checksum.',
      );
    }

    final data = payload.sublist(0, payload.length - _checksumLength);
    final embeddedChecksum = payload.sublist(
      payload.length - _checksumLength,
    );

    final expectedChecksum = _sha256(data).sublist(32 - _checksumLength);

    if (!_bytesEqual(embeddedChecksum, expectedChecksum)) {
      throw ArgumentError(
        'Invalid CB58 string: checksum mismatch. '
        'The string may have been mistyped or corrupted.',
      );
    }

    return data;
  }

  // ---- Internal: SHA-256 ----

  static Uint8List _sha256(Uint8List data) {
    final digest = SHA256Digest();
    return digest.process(data);
  }

  // ---- Internal: Base58 Encode ----

  static String _base58Encode(Uint8List input) {
    if (input.isEmpty) return '';

    // Count leading zero bytes; each becomes a leading '1' in the
    // output, per standard Base58 convention.
    var leadingZeros = 0;
    while (leadingZeros < input.length && input[leadingZeros] == 0) {
      leadingZeros++;
    }

    // Convert the byte array to a big integer, then repeatedly divide
    // by 58 to extract Base58 digits.
    var value = BigInt.zero;
    for (final byte in input) {
      value = (value << 8) | BigInt.from(byte);
    }

    final digits = <int>[];
    final base = BigInt.from(58);
    while (value > BigInt.zero) {
      final remainder = (value % base).toInt();
      digits.add(remainder);
      value = value ~/ base;
    }

    final buffer = StringBuffer()..write('1' * leadingZeros);
    for (final digit in digits.reversed) {
      buffer.write(_alphabet[digit]);
    }

    return buffer.toString();
  }

  // ---- Internal: Base58 Decode ----

  static Uint8List _base58Decode(String input) {
    if (input.isEmpty) {
      throw ArgumentError('Cannot decode an empty CB58 string.');
    }

    // Count leading '1' characters; each represents a leading zero
    // byte in the output.
    var leadingOnes = 0;
    while (leadingOnes < input.length && input[leadingOnes] == '1') {
      leadingOnes++;
    }

    var value = BigInt.zero;
    final base = BigInt.from(58);

    for (var i = 0; i < input.length; i++) {
      final charIndex = _alphabet.indexOf(input[i]);
      if (charIndex == -1) {
        throw ArgumentError(
          'Invalid CB58 character "${input[i]}" at position $i.',
        );
      }
      value = value * base + BigInt.from(charIndex);
    }

    // Convert the big integer back to bytes.
    final bytes = <int>[];
    while (value > BigInt.zero) {
      bytes.add((value & BigInt.from(0xff)).toInt());
      value = value >> 8;
    }

    final reversedBytes = bytes.reversed.toList();

    return Uint8List.fromList([
      ...List<int>.filled(leadingOnes, 0),
      ...reversedBytes,
    ]);
  }

  // ---- Internal: Constant-ish Comparison ----

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}
