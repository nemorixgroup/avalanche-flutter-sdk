import 'dart:convert';
import 'dart:typed_data';

import 'package:avalanche_flutter_sdk/src/crypto/mnemonic/mnemonic.dart';
import 'package:pointycastle/export.dart' hide PublicKey;

// ---- Seed ----

/// Converts a BIP-39 [Mnemonic] into a 512-bit (64-byte) binary seed
/// using PBKDF2-HMAC-SHA512.
///
/// The seed is the input to BIP-32 HD wallet derivation. It is derived
/// from the mnemonic phrase and an optional passphrase, making it
/// possible to create multiple independent wallets from the same mnemonic
/// by using different passphrases.
///
/// Source: https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki
///
/// "To create a binary seed from the mnemonic, we use the PBKDF2 function
/// with a mnemonic sentence (in UTF-8 NFKD) used as the password and the
/// string "mnemonic" + passphrase (again in UTF-8 NFKD) used as the salt.
/// The iteration count is set to 2048 and HMAC-SHA512 is used as the
/// pseudo-random function. The length of the derived key is 512 bits."
class Seed {
  // ---- Constructor ----

  Seed._(this._bytes);

  // ---- Factory: From Mnemonic ----

  /// Derives a [Seed] from a [mnemonic] and an optional [passphrase].
  ///
  /// If no [passphrase] is provided, an empty string is used - this is
  /// the standard behavior for wallets without an extra passphrase.
  ///
  /// The derivation uses PBKDF2-HMAC-SHA512 with:
  /// - Password: mnemonic phrase in UTF-8 NFKD
  /// - Salt: "mnemonic" + passphrase in UTF-8 NFKD
  /// - Iterations: 2048
  /// - Key length: 64 bytes (512 bits)
  factory Seed.fromMnemonic(
    Mnemonic mnemonic, {
    String passphrase = '',
  }) {
    final bytes = _derive(mnemonic.phrase, passphrase);
    return Seed._(bytes);
  }

  // ---- Factory: From Phrase ----

  /// Derives a [Seed] directly from a mnemonic [phrase] string and an
  /// optional [passphrase].
  ///
  /// Useful when the phrase is already available as a string without
  /// needing to construct a [Mnemonic] instance first.
  factory Seed.fromPhrase(
    String phrase, {
    String passphrase = '',
  }) {
    final bytes = _derive(phrase, passphrase);
    return Seed._(bytes);
  }

  // ---- Fields ----

  final Uint8List _bytes;

  // ---- Constants ----

  /// The output length of the seed in bytes (512 bits).
  static const int seedLength = 64;

  /// The number of PBKDF2 iterations per BIP-39 specification.
  static const int _iterations = 2048;

  /// The salt prefix per BIP-39 specification.
  static const String _saltPrefix = 'mnemonic';

  // ---- Public API ----

  /// Returns the raw 64-byte seed.
  ///
  /// Handle with the same care as a private key - this value can
  /// reconstruct the entire HD wallet.
  Uint8List get bytes => Uint8List.fromList(_bytes);

  /// Returns the seed as a lowercase hex string (128 hex characters).
  String toHex() =>
      _bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  // ---- Internal: PBKDF2 derivation ----

  static Uint8List _derive(String phrase, String passphrase) {
    // Per BIP-39: both password and salt must be in UTF-8 NFKD.
    // The mnemonic phrase from Mnemonic.phrase is already in NFC.
    // We normalize to NFKD before encoding to UTF-8.
    final password = utf8.encode(_toNfkd(phrase));
    final salt = utf8.encode(_toNfkd(_saltPrefix + passphrase));

    final derivator = PBKDF2KeyDerivator(HMac(SHA512Digest(), 128))
      ..init(
        Pbkdf2Parameters(
          Uint8List.fromList(salt),
          _iterations,
          seedLength,
        ),
      );

    return derivator.process(Uint8List.fromList(password));
  }

  // ---- Internal: NFKD normalization ----

  /// Converts a string to NFKD form for PBKDF2 input per BIP-39 spec.
  ///
  /// Uses Dart's built-in Unicode normalization via character replacement
  /// for the characters that appear in BIP-39 wordlists. For standard
  /// ASCII mnemonics (English), this is a no-op.
  static String _toNfkd(String input) {
    // Dart strings are UTF-16. For BIP-39 English wordlists, all words
    // are ASCII - no normalization needed. For Spanish wordlists with
    // NFC-encoded accented chars, we decompose to NFKD by replacing
    // precomposed chars with their decomposed equivalents.
    return input
        .replaceAll('\u00e1', 'a\u0301') // á → a + combining acute
        .replaceAll('\u00e9', 'e\u0301') // é → e + combining acute
        .replaceAll('\u00ed', 'i\u0301') // í → i + combining acute
        .replaceAll('\u00f3', 'o\u0301') // ó → o + combining acute
        .replaceAll('\u00fa', 'u\u0301') // ú → u + combining acute
        .replaceAll('\u00fc', 'u\u0308') // ü → u + combining diaeresis
        .replaceAll('\u00f1', 'n\u0303'); // ñ → n + combining tilde
  }

  // ---- Overrides ----

  /// Returns a redacted string. The seed is equivalent in sensitivity
  /// to a private key and must never appear in logs.
  ///
  /// Use [toHex] or [bytes] explicitly when the seed value is needed.
  @override
  String toString() => 'Seed[REDACTED]';
}
