import 'dart:typed_data';

import 'package:avalanche_flutter_sdk/src/crypto/public_key.dart';
import 'package:pointycastle/export.dart' hide PublicKey;

// ---- AvalancheNetwork ----

/// The Avalanche network for address encoding.
enum AvalancheNetwork {
  /// Avalanche Mainnet - HRP: "avax"
  mainnet('avax'),

  /// Fuji Testnet - HRP: "fuji"
  fuji('fuji');

  const AvalancheNetwork(this.hrp);

  /// The human-readable part (HRP) used in Bech32 address encoding.
  final String hrp;
}

// ---- XPAddress ----

/// A native Avalanche address for X-Chain and P-Chain.
///
/// Derived from a secp256k1 compressed public key using:
/// 1. SHA256(compressed_pubkey 33 bytes) → 32 bytes
/// 2. RIPEMD160(sha256_result)           → 20 bytes
/// 3. Bech32 encode(20 bytes, hrp)       → address string
///
/// Format:
/// - X-Chain mainnet: `X-avax1{bech32}`
/// - P-Chain mainnet: `P-avax1{bech32}`
/// - X-Chain Fuji:    `X-fuji1{bech32}`
/// - P-Chain Fuji:    `P-fuji1{bech32}`
///
/// Sources:
/// - https://docs.avax.network/docs/rpcs/other/standards/cryptographic-primitives
/// - https://github.com/bitcoin/bips/blob/master/bip-0173.mediawiki (Bech32)
class XPAddress {
  // ---- Constructor ----

  XPAddress._(this._bytes);

  // ---- Factory: From PublicKey ----

  /// Derives an [XPAddress] from a secp256k1 [PublicKey].
  ///
  /// Uses the compressed public key (33 bytes) as input.
  /// Per official Avalanche spec:
  /// "The 33-byte compressed representation of the public key is hashed
  /// with sha256 once. The result is then hashed with ripemd160 to yield
  /// a 20-byte address."
  factory XPAddress.fromPublicKey(PublicKey publicKey) {
    final compressed = publicKey.toCompressed(); // 33 bytes
    final sha256Result = _sha256(compressed); // 32 bytes
    final ripemd160Result = _ripemd160(sha256Result); // 20 bytes
    return XPAddress._(ripemd160Result);
  }

  // ---- Fields ----

  final Uint8List _bytes;

  // ---- Constants ----

  /// Bech32 character set per BIP-173.
  static const String _charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';

  /// Bech32 generator polynomials per BIP-173.
  static const List<int> _generator = [
    0x3b6a57b2,
    0x26508e6d,
    0x1ea119fa,
    0x3d4233dd,
    0x2a1462b3,
  ];

  // ---- Public API ----

  /// Returns the raw 20-byte address.
  Uint8List get bytes => Uint8List.fromList(_bytes);

  /// Returns the X-Chain address string for the given [network].
  ///
  /// Format: `X-avax1{bech32}` (mainnet) or `X-fuji1{bech32}` (testnet).
  String xChainAddress({
    AvalancheNetwork network = AvalancheNetwork.mainnet,
  }) =>
      'X-${_bech32Encode(network.hrp, _bytes)}';

  /// Returns the P-Chain address string for the given [network].
  ///
  /// Format: `P-avax1{bech32}` (mainnet) or `P-fuji1{bech32}` (testnet).
  String pChainAddress({
    AvalancheNetwork network = AvalancheNetwork.mainnet,
  }) =>
      'P-${_bech32Encode(network.hrp, _bytes)}';

  // ---- Overrides ----

  @override
  bool operator ==(Object other) =>
      other is XPAddress &&
      _bytes.length == other._bytes.length &&
      List.generate(_bytes.length, (i) => _bytes[i] == other._bytes[i])
          .every((e) => e);

  @override
  int get hashCode => Object.hashAll(_bytes);

  @override
  String toString() =>
      'XPAddress(X-${_bech32Encode(AvalancheNetwork.mainnet.hrp, _bytes)})';

  // ---- Internal: SHA-256 ----

  static Uint8List _sha256(Uint8List data) {
    final digest = SHA256Digest();
    return digest.process(data);
  }

  // ---- Internal: RIPEMD-160 ----

  static Uint8List _ripemd160(Uint8List data) {
    final digest = RIPEMD160Digest();
    return digest.process(data);
  }

  // ---- Internal: Bech32 encoding (BIP-173) ----

  static String _bech32Encode(String hrp, Uint8List data) {
    final converted = _convertBits(data, 8, 5);
    final checksum = _createChecksum(hrp, converted);
    final combined = [...converted, ...checksum];
    final result = StringBuffer(hrp)..write('1');
    for (final value in combined) {
      result.write(_charset[value]);
    }
    return result.toString();
  }

  /// Converts a byte array from [fromBits]-bit groups to [toBits]-bit groups.
  ///
  /// Per BIP-173: converts 8-bit bytes to 5-bit groups (pad=true).
  static List<int> _convertBits(
    Uint8List data,
    int fromBits,
    int toBits, {
    bool pad = true,
  }) {
    var acc = 0;
    var bits = 0;
    final result = <int>[];
    final maxv = (1 << toBits) - 1;

    for (final value in data) {
      acc = ((acc << fromBits) | value) & 0xffffffff;
      bits += fromBits;
      while (bits >= toBits) {
        bits -= toBits;
        result.add((acc >> bits) & maxv);
      }
    }

    if (pad && bits > 0) {
      result.add((acc << (toBits - bits)) & maxv);
    }

    return result;
  }

  /// Computes the Bech32 polymod checksum.
  static int _polymod(List<int> values) {
    var chk = 1;
    for (final v in values) {
      final b = chk >> 25;
      chk = ((chk & 0x1ffffff) << 5) ^ v;
      for (var i = 0; i < 5; i++) {
        if ((b >> i) & 1 == 1) {
          chk ^= _generator[i];
        }
      }
    }
    return chk;
  }

  /// Expands the HRP into the format required for Bech32 checksum.
  static List<int> _hrpExpand(String hrp) {
    final result = <int>[];
    for (final c in hrp.codeUnits) {
      result.add(c >> 5);
    }
    result.add(0);
    for (final c in hrp.codeUnits) {
      result.add(c & 31);
    }
    return result;
  }

  /// Creates the 6-value Bech32 checksum.
  static List<int> _createChecksum(String hrp, List<int> data) {
    final values = [
      ..._hrpExpand(hrp),
      ...data,
      0,
      0,
      0,
      0,
      0,
      0,
    ];
    final polymod = _polymod(values) ^ 1;
    return List.generate(6, (i) => (polymod >> (5 * (5 - i))) & 31);
  }
}
