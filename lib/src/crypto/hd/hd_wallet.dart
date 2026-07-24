import 'dart:typed_data';

import 'package:avalanche_flutter_sdk/src/crypto/hd/seed.dart';
import 'package:avalanche_flutter_sdk/src/crypto/mnemonic/mnemonic.dart';
import 'package:avalanche_flutter_sdk/src/crypto/private_key.dart';
import 'package:avalanche_flutter_sdk/src/crypto/public_key.dart';
import 'package:pointycastle/export.dart' hide PrivateKey, PublicKey;

// ---- HDWallet ----

/// A BIP-32/BIP-44 hierarchical deterministic wallet for the
/// Avalanche network.
///
/// Derives private keys and public keys from a single [Seed] following
/// the BIP-44 path structure:
/// ```dart
/// m / purpose' / coin_type' / account' / change / index
/// ```
///
/// Avalanche derivation paths (verified from Core Wallet):
/// - C-Chain (EVM): m/44'/60'/0'/0/n  (coin_type=60, EVM-compatible)
/// - X-Chain:       m/44'/9000'/0'/0/n (coin_type=9000, Avalanche native)
/// - P-Chain:       m/44'/9000'/0'/0/n (same path as X-Chain)
///
/// Sources:
/// - BIP-32: https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki
/// - BIP-44: https://github.com/bitcoin/bips/blob/master/bip-0044.mediawiki
/// - Avalanche paths: https://support.core.app/en/articles/7004986
class HDWallet {
  // ---- Constructor ----

  HDWallet._(this._masterKey, this._masterChainCode);

  // ---- Factory: From Seed ----

  /// Creates an [HDWallet] from a [Seed].
  ///
  /// Derives the BIP-32 master private key and chain code using
  /// HMAC-SHA512 with key "Bitcoin seed".
  factory HDWallet.fromSeed(Seed seed) {
    final bytes = seed.bytes;
    final masterData = _hmacSha512(
      key: Uint8List.fromList('Bitcoin seed'.codeUnits),
      data: bytes,
    );
    final masterKey = masterData.sublist(0, 32);
    final masterChainCode = masterData.sublist(32, 64);
    return HDWallet._(masterKey, masterChainCode);
  }

  // ---- Factory: From Mnemonic ----

  /// Creates an [HDWallet] directly from a [Mnemonic].
  ///
  /// Convenience constructor that derives [Seed] internally.
  factory HDWallet.fromMnemonic(
    Mnemonic mnemonic, {
    String passphrase = '',
  }) {
    final seed = Seed.fromMnemonic(mnemonic, passphrase: passphrase);
    return HDWallet.fromSeed(seed);
  }

  // ---- Fields ----

  final Uint8List _masterKey;
  final Uint8List _masterChainCode;

  // ---- BIP-44 Constants ----

  /// Hardened key offset (2^31).
  static const int _hardenedOffset = 0x80000000;

  /// BIP-44 purpose (44').
  static const int _purpose = 44 + _hardenedOffset;

  /// Coin type for C-Chain (EVM-compatible, same as Ethereum).
  /// Source: https://support.core.app/en/articles/7004986
  static const int _coinTypeEvm = 60 + _hardenedOffset;

  /// Coin type for X-Chain and P-Chain (Avalanche native).
  /// Source: https://support.core.app/en/articles/7004986
  static const int _coinTypeAvax = 9000 + _hardenedOffset;

  static final ECDomainParameters _domain = ECDomainParameters('secp256k1');

  // ---- Public API: Key derivation ----

  /// Derives a [PrivateKey] at the given BIP-44 path for C-Chain:
  /// `m/44'/60'/0'/0/[index]`
  ///
  /// Compatible with Core Wallet and MetaMask on Avalanche C-Chain.
  PrivateKey derivePrivateKeyForCChain({int index = 0}) {
    final key = _derivePath([
      _purpose,
      _coinTypeEvm,
      0 + _hardenedOffset, // account 0'
      0, // change 0 (external)
      index, // address index
    ]);
    return PrivateKey.fromHex(
      key.sublist(0, 32).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    );
  }

  /// Derives a [PrivateKey] at the given BIP-44 path for X/P-Chain:
  /// `m/44'/9000'/0'/0/[index]`
  ///
  /// Compatible with Core Wallet on Avalanche X-Chain and P-Chain.
  PrivateKey derivePrivateKeyForXPChain({int index = 0}) {
    final key = _derivePath([
      _purpose,
      _coinTypeAvax,
      0 + _hardenedOffset, // account 0'
      0, // change 0 (external)
      index, // address index
    ]);
    return PrivateKey.fromHex(
      key.sublist(0, 32).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    );
  }

  /// Derives a [PublicKey] at the given BIP-44 path for C-Chain.
  PublicKey derivePublicKeyForCChain({int index = 0}) {
    return derivePrivateKeyForCChain(index: index).publicKey;
  }

  /// Derives a [PublicKey] at the given BIP-44 path for X/P-Chain.
  PublicKey derivePublicKeyForXPChain({int index = 0}) {
    return derivePrivateKeyForXPChain(index: index).publicKey;
  }

  // ---- Internal: Path derivation ----

  Uint8List _derivePath(List<int> indices) {
    var key = _masterKey;
    var chainCode = _masterChainCode;

    for (final index in indices) {
      final result = _deriveChildKey(key, chainCode, index);
      key = result.sublist(0, 32);
      chainCode = result.sublist(32, 64);
    }

    return Uint8List.fromList([...key, ...chainCode]);
  }

  Uint8List _deriveChildKey(
    Uint8List parentKey,
    Uint8List parentChainCode,
    int index,
  ) {
    final data = BytesBuilder();

    if (index >= _hardenedOffset) {
      // Hardened child: 0x00 || ser256(kpar) || ser32(i)
      data
        ..addByte(0x00)
        ..add(parentKey);
    } else {
      // Normal child: serP(point(kpar)) || ser32(i)
      final parentPrivKey = PrivateKey.fromHex(
        parentKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      );
      data.add(parentPrivKey.publicKey.toCompressed());
    }

    // Append ser32(i) - 4 bytes big-endian
    data
      ..addByte((index >> 24) & 0xff)
      ..addByte((index >> 16) & 0xff)
      ..addByte((index >> 8) & 0xff)
      ..addByte(index & 0xff);

    final I = _hmacSha512(key: parentChainCode, data: data.toBytes());
    final il = I.sublist(0, 32);
    final ir = I.sublist(32, 64);

    // child_key = (parse256(IL) + parentKey) mod n
    final ilInt = _bytesToBigInt(il);
    final parentKeyInt = _bytesToBigInt(parentKey);
    final childKeyInt = (ilInt + parentKeyInt) % _domain.n;

    if (ilInt >= _domain.n || childKeyInt == BigInt.zero) {
      // Invalid key - should try next index (probability < 1/2^127)
      throw StateError(
        'Derived key is invalid at this index. Try index + 1.',
      );
    }

    final childKey = _bigIntToBytes(childKeyInt);
    return Uint8List.fromList([...childKey, ...ir]);
  }

  // ---- Internal: HMAC-SHA512 ----

  static Uint8List _hmacSha512({
    required Uint8List key,
    required Uint8List data,
  }) {
    final hmac = HMac(SHA512Digest(), 128)..init(KeyParameter(key));
    return hmac.process(data);
  }

  // ---- Internal: BigInt helpers ----

  static BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }

  static Uint8List _bigIntToBytes(BigInt value) {
    final hex = value.toRadixString(16).padLeft(64, '0');
    return Uint8List.fromList(
      List.generate(
        32,
        (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
      ),
    );
  }

  // ---- Overrides ----

  @override
  String toString() => 'HDWallet[REDACTED]';
}
