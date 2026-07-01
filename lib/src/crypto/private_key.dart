import 'dart:math';
import 'dart:typed_data';

import 'package:avalanche_flutter_sdk/src/crypto/public_key.dart';
import 'package:pointycastle/export.dart' hide PublicKey;

// ---- PrivateKey ----

/// A secp256k1 private key used across all Avalanche chains (C/P/X-Chain).
///
/// Source: https://docs.avax.network/specs/cryptographic-primitives
/// "The Avalanche virtual machine uses elliptic curve cryptography,
/// specifically secp256k1, for its signatures on the blockchain."
class PrivateKey {
  // ---- Constructor ----

  PrivateKey._(this._d);

  // ---- Factory: Random Generation ----

  /// Generates a new random [PrivateKey] using a cryptographically
  /// secure random number generator.
  factory PrivateKey.generate() {
    final secureRandom = _buildSecureRandom();

    final keyGenerator = ECKeyGenerator()
      ..init(
        ParametersWithRandom(
          ECKeyGeneratorParameters(_domainParams),
          secureRandom,
        ),
      );

    final pair = keyGenerator.generateKeyPair();
    final ecPrivateKey = pair.privateKey;

    return PrivateKey._(ecPrivateKey.d!);
  }

  // ---- Factory: Import ----

  /// Imports a [PrivateKey] from its 32-byte hex representation.
  ///
  /// Accepts an optional `0x` prefix.
  factory PrivateKey.fromHex(String hex) {
    final cleanHex = hex.startsWith('0x') ? hex.substring(2) : hex;

    if (cleanHex.length != 64) {
      throw ArgumentError(
        'Invalid private key length: expected 64 hex characters (32 bytes), '
        'got ${cleanHex.length}.',
      );
    }

    final d = BigInt.parse(cleanHex, radix: 16);

    if (d <= BigInt.zero || d >= _domainParams.n) {
      throw ArgumentError(
        'Private key out of valid range for secp256k1.',
      );
    }

    return PrivateKey._(d);
  }

  // ---- Fields ----

  /// The private key scalar `d`, a 32-byte big-endian integer.
  final BigInt _d;

  // ---- Domain Parameters ----

  static final ECDomainParameters _domainParams =
      ECDomainParameters('secp256k1');

  // ---- Public API ----

  /// Derives the corresponding [PublicKey] for this private key.
  ///
  /// Computed as `Q = d * G`, where `G` is the curve's base point.
  PublicKey get publicKey {
    final point = _domainParams.G * _d;
    return PublicKey.fromEcPoint(point!);
  }

  /// Exports this private key as a 32-byte big-endian hex string
  /// (no `0x` prefix, zero-padded).
  String toHex() {
    return _d.toRadixString(16).padLeft(64, '0');
  }

  /// Exports this private key as raw 32 bytes, big-endian.
  Uint8List toBytes() {
    final hex = toHex();
    final bytes = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  // ---- Internal Helpers ----

  static SecureRandom _buildSecureRandom() {
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seed = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    secureRandom.seed(KeyParameter(seed));
    return secureRandom;
  }

  // ---- Overrides ----

  /// Returns a redacted string. Private key material must never be
  /// exposed via logs, error messages, or debug output.
  @override
  String toString() => 'PrivateKey[REDACTED]';
}
