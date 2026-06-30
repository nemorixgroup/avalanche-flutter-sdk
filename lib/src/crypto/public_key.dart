import 'dart:typed_data';

import 'package:pointycastle/export.dart' hide PublicKey;

// ---- PublicKey ----

/// A secp256k1 public key used across all Avalanche chains (C/P/X-Chain).
///
/// Source: https://docs.avax.network/specs/cryptographic-primitives
///
/// Value-equality class: two instances are equal if they represent the
/// same elliptic curve point, regardless of encoding (compressed vs
/// uncompressed). Not marked @immutable because the underlying [ECPoint]
/// from pointycastle does not support const construction.
class PublicKey {
  // ---- Constructor ----

  PublicKey._(this._point);

  // ---- Factory: From ECPoint ----

  /// Creates a [PublicKey] from a raw curve point.
  ///
  /// Used internally by `PrivateKey.publicKey`.
  factory PublicKey.fromEcPoint(ECPoint point) => PublicKey._(point);

  // ---- Factory: Import ----

  /// Imports a [PublicKey] from its hex representation.
  ///
  /// Accepts both compressed (33 bytes / 66 hex chars, prefix `02`/`03`)
  /// and uncompressed (65 bytes / 130 hex chars, prefix `04`) encodings,
  /// per SEC1.
  factory PublicKey.fromHex(String hex) {
    final cleanHex = hex.startsWith('0x') ? hex.substring(2) : hex;
    final bytes = Uint8List.fromList(
      List<int>.generate(
        cleanHex.length ~/ 2,
        (i) => int.parse(cleanHex.substring(i * 2, i * 2 + 2), radix: 16),
      ),
    );

    final point = _domainParams.curve.decodePoint(bytes);

    if (point == null) {
      throw ArgumentError('Invalid public key encoding.');
    }

    return PublicKey._(point);
  }

  // ---- Fields ----

  final ECPoint _point;

  // ---- Domain Parameters ----

  static final ECDomainParameters _domainParams =
      ECDomainParameters('secp256k1');

  // ---- Public API ----

  /// Returns the compressed SEC1 encoding (33 bytes): a single prefix
  /// byte (`02` or `03` depending on Y parity) followed by the X
  /// coordinate.
  ///
  /// This is the format required for X-Chain and P-Chain address
  /// derivation per the official spec: the 33-byte compressed
  /// representation of the public key is hashed with sha256 once.
  Uint8List toCompressed() {
    final encoded = _point.getEncoded();
    return Uint8List.fromList(encoded);
  }

  /// Returns the uncompressed SEC1 encoding (65 bytes): prefix `04`
  /// followed by the X and Y coordinates.
  Uint8List toUncompressed() {
    final encoded = _point.getEncoded(false);
    return Uint8List.fromList(encoded);
  }

  /// Returns the raw 64-byte X||Y coordinate pair, without the
  /// uncompressed-format `04` prefix byte.
  ///
  /// This is the input format required for EVM/C-Chain address
  /// derivation (`keccak256(X || Y)`).
  Uint8List toRawUncompressed() {
    final uncompressed = toUncompressed();
    return Uint8List.sublistView(uncompressed, 1);
  }

  /// Exports the compressed public key as a hex string (no `0x` prefix).
  String toHex() {
    return toCompressed()
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  // ---- Overrides ----

  @override
  bool operator ==(Object other) =>
      other is PublicKey && _point == other._point;

  @override
  int get hashCode => _point.hashCode;

  @override
  String toString() => 'PublicKey(0x${toHex()})';
}
