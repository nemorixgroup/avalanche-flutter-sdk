import 'dart:convert';
import 'dart:typed_data';

import 'package:avalanche_flutter_sdk/src/crypto/public_key.dart';
import 'package:pointycastle/export.dart' hide PublicKey;

// ---- EvmAddress ----

/// An EVM-compatible address for the Avalanche C-Chain.
///
/// Derived from a secp256k1 public key using keccak256, following the
/// same algorithm as Ethereum. Compatible with MetaMask, Core Wallet,
/// and all EVM tools.
///
/// Derivation process:
/// 1. Take the raw uncompressed public key (64 bytes, no 0x04 prefix)
/// 2. Apply keccak256 → 32-byte hash
/// 3. Take the last 20 bytes → raw address
/// 4. Apply EIP-55 checksum → mixed-case hex with 0x prefix
///
/// Sources:
/// - Avalanche C-Chain: https://docs.avax.network/specs/cryptographic-primitives
/// - EIP-55: https://eips.ethereum.org/EIPS/eip-55
class EvmAddress {
  // ---- Constructor ----

  EvmAddress._(this._bytes);

  // ---- Factory: From PublicKey ----

  /// Derives an [EvmAddress] from a secp256k1 [PublicKey].
  ///
  /// Uses the raw uncompressed public key (64 bytes, no 0x04 prefix)
  /// as input to keccak256, then takes the last 20 bytes of the hash.
  factory EvmAddress.fromPublicKey(PublicKey publicKey) {
    final raw = publicKey.toRawUncompressed(); // 64 bytes, no 0x04
    final hash = _keccak256(raw); // 32 bytes
    final bytes = hash.sublist(12); // last 20 bytes
    return EvmAddress._(Uint8List.fromList(bytes));
  }

  // ---- Factory: From hex ----

  /// Imports an [EvmAddress] from a hex string.
  ///
  /// Accepts with or without `0x` prefix, and any casing.
  factory EvmAddress.fromHex(String hex) {
    final clean =
        hex.startsWith('0x') || hex.startsWith('0X') ? hex.substring(2) : hex;
    if (clean.length != 40) {
      throw ArgumentError(
        'Invalid EVM address length: expected 40 hex chars (20 bytes), '
        'got ${clean.length}.',
      );
    }
    final bytes = Uint8List.fromList(
      List.generate(
        20,
        (i) => int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16),
      ),
    );
    return EvmAddress._(bytes);
  }

  // ---- Fields ----

  final Uint8List _bytes;

  // ---- Public API ----

  /// Returns the raw 20-byte address.
  Uint8List get bytes => Uint8List.fromList(_bytes);

  /// Returns the EIP-55 checksummed address with `0x` prefix.
  ///
  /// Per EIP-55: take keccak256 of the lowercase hex address (without 0x),
  /// then capitalize each hex letter whose corresponding nibble in the
  /// hash is >= 8.
  ///
  /// Source: https://eips.ethereum.org/EIPS/eip-55
  String get checksumAddress {
    final hex = _bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(); // lowercase, no 0x

    final hash = _keccak256(
      Uint8List.fromList(utf8.encode(hex)),
    );
    final hashHex = hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    final buffer = StringBuffer('0x');
    for (var i = 0; i < hex.length; i++) {
      final c = hex[i];
      if (int.tryParse(c) != null) {
        buffer.write(c); // digits stay as-is
      } else {
        // Capitalize if corresponding nibble in hash >= 8
        final nibble = int.parse(hashHex[i], radix: 16);
        buffer.write(nibble >= 8 ? c.toUpperCase() : c);
      }
    }
    return buffer.toString();
  }

  /// Returns the lowercase address with `0x` prefix (no checksum).
  String get lowercaseAddress {
    final hex = _bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '0x$hex';
  }

  // ---- Internal: keccak256 ----

  static Uint8List _keccak256(Uint8List data) {
    final digest = KeccakDigest(256);
    return digest.process(data);
  }

  // ---- Overrides ----

  @override
  bool operator ==(Object other) =>
      other is EvmAddress && lowercaseAddress == other.lowercaseAddress;

  @override
  int get hashCode => lowercaseAddress.hashCode;

  /// Returns the EIP-55 checksummed address.
  @override
  String toString() => checksumAddress;
}
