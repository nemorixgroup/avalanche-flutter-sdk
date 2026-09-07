import 'dart:math';
import 'dart:typed_data';

import 'package:avalanche_flutter_sdk/src/crypto/ecdsa_signature.dart';
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

  /// secp256k1 field prime p.
  /// Source: https://en.bitcoin.it/wiki/Secp256k1
  static final BigInt _fieldPrime = BigInt.parse(
    'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F',
    radix: 16,
  );

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

  /// Signs a pre-computed 32-byte [digest] using secp256k1.
  ///
  /// Uses RFC 6979 deterministic nonce generation (HMAC-SHA256) to ensure
  /// that the same key and message always produce the same signature.
  ///
  /// Returns an [EcdsaSignature] with:
  /// -[EcdsaSignature.r] and [EcdsaSignature.s]: secp256k1 signature components
  /// -[EcdsaSignature.s]: always low-S normalized (s <= n/2) to prevent malleability
  /// -[EcdsaSignature.v]: recovery id (0 or 1) for EIP-1559 signatureYParity
  ///
  /// Source: https://eips.ethereum.org/EIPS/eip-1559
  EcdsaSignature signDigest(Uint8List digest) {
    if (digest.length != 32) {
      throw ArgumentError(
        'Digest must be exactly 32 bytes, got ${digest.length}.',
      );
    }

    // Sign with RFC 6979 deterministic nonce (HMAC-SHA256)
    final signer = ECDSASigner(null, HMac(SHA256Digest(), 64))
      ..init(true, PrivateKeyParameter(ECPrivateKey(_d, _domainParams)));
    final sig = signer.generateSignature(digest) as ECSignature;

    final n = _domainParams.n;
    final halfN = n >> 1;
    final r = sig.r;
    var s = sig.s;

    // Compute recovery id before potential low-S normalization
    var v = _computeRecoveryId(digest, r, s);

    // Low-S normalization: prevents signature malleability
    // If s > n/2, replace s with n - s and flip recovery id
    if (s > halfN) {
      s = n - s;
      v = 1 - v;
    }

    return EcdsaSignature(r: r, s: s, v: v);
  }

  /// Computes the secp256k1 recovery id (0 or 1) for the given signature.
  ///
  /// Tries both possible recovery ids and returns the one that recovers
  /// the expected public key from the signature.
  int _computeRecoveryId(Uint8List digestBytes, BigInt r, BigInt s) {
    final z = _bytesToBigInt(digestBytes);
    final n = _domainParams.n;
    final G = _domainParams.G;
    final curve = _domainParams.curve;
    final expectedPubKey = publicKey.toCompressed();

    for (var yBit = 0; yBit < 2; yBit++) {
      // Decompress point R: x = r, y parity = yBit
      final R = _decompressPoint(r, yBit, curve);
      if (R == null) continue;

      // Q = r^-1 * (s*R - z*G) = r^-1 * (s*R + (n-z)*G)
      final rInv = r.modInverse(n);
      final minusZ = n - (z % n);
      final sR = R * s;
      final minusZG = G * minusZ;
      if (sR == null || minusZG == null) continue;
      final sum = sR + minusZG;
      if (sum == null) continue;
      final Q = sum * rInv;
      if (Q == null) continue;

      final recoveredKey = Q.getEncoded(); // compressed
      if (_bytesAreEqual(recoveredKey, expectedPubKey)) return yBit;
    }

    throw StateError('Failed to compute recovery id for signature.');
  }

  /// Decompresses a secp256k1 curve point from x-coordinate and y-parity.
  ///
  /// For secp256k1: y^2 = x^3 + 7 (mod p)
  /// Since p ≡ 3 (mod 4): y = (x^3 + 7)^((p+1)/4) mod p
  ECPoint? _decompressPoint(BigInt x, int yBit, ECCurve curve) {
    final p = _fieldPrime;
    final xCubed = x.modPow(BigInt.from(3), p);
    final ySquared = (xCubed + BigInt.from(7)) % p;

    // Tonelli-Shanks shortcut for p ≡ 3 (mod 4)
    var y = ySquared.modPow((p + BigInt.one) ~/ BigInt.from(4), p);

    // Verify y^2 == ySquared (valid point on curve)
    if (y.modPow(BigInt.two, p) != ySquared) return null;

    // Choose y based on parity: yBit=0 -> even y, yBit=1 -> odd y
    if (y.isOdd != (yBit == 1)) y = p - y;

    return curve.createPoint(x, y);
  }

  static BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }

  static bool _bytesAreEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ---- Overrides ----

  /// Returns a redacted string. Private key material must never be
  /// exposed via logs, error messages, or debug output.
  @override
  String toString() => 'PrivateKey[REDACTED]';
}
