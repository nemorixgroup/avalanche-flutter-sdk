import 'dart:typed_data';

import 'package:avalanche_flutter_sdk/src/crypto/mnemonic/entropy.dart';
import 'package:avalanche_flutter_sdk/src/crypto/mnemonic/wordlist.dart';
import 'package:avalanche_flutter_sdk/src/crypto/mnemonic/wordlist_en.dart';

/// A BIP-39 mnemonic phrase used to generate deterministic wallets.
///
/// A mnemonic is a human-readable encoding of entropy bytes as a sequence
/// of words from a [Wordlist]. It is the primary backup mechanism for
/// HD wallets - anyone with the mnemonic can reconstruct the wallet.
///
/// Source: https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki
///
/// "A mnemonic code or sentence is superior for human interaction compared
/// to the handling of raw binary or hexadecimal representations of a wallet
/// seed."
///
/// ## Security
///
/// A mnemonic is equivalent in sensitivity to a private key. [toString]
/// returns `[REDACTED]` to prevent accidental exposure in logs. Use
/// [phrase] explicitly when the phrase must be displayed to the user.
class Mnemonic {
  // ---- Constructor ----

  Mnemonic._(this._words, this._wordlist);

  // ---- Internal: Generate from entropy ----

  Mnemonic._fromEntropy(Uint8List entropy, Wordlist wordlist)
      : _wordlist = wordlist,
        _words = _buildWords(entropy, wordlist);

  // ---- Factory: Generate ----

  /// Generates a new [Mnemonic] from cryptographically secure random entropy.
  ///
  /// Defaults to [MnemonicStrength.words12] (128 bits / 12 words) and the
  /// English wordlist. Use [MnemonicStrength.words24] for maximum security
  /// (256 bits / 24 words).
  ///
  /// ```dart
  /// // 12-word English mnemonic
  /// final mnemonic = Mnemonic.generate();
  ///
  /// // 24-word Spanish mnemonic
  /// final mnemonic = Mnemonic.generate(
  ///   strength: MnemonicStrength.words24,
  ///   wordlist: WordlistEs.instance,
  /// );
  /// ```
  factory Mnemonic.generate({
    MnemonicStrength strength = MnemonicStrength.words12,
    Wordlist? wordlist,
  }) {
    final wl = wordlist ?? WordlistEn.instance;
    final entropy = Entropy.generate(strength: strength);
    return Mnemonic._fromEntropy(entropy, wl);
  }

  // ---- Factory: From Entropy ----

  /// Creates a [Mnemonic] from existing [entropy] bytes.
  ///
  /// [entropy] must be 16, 20, 24, 28, or 32 bytes (128-256 bits).
  /// Throws [ArgumentError] if the entropy length is invalid.
  factory Mnemonic.fromEntropy(
    Uint8List entropy, {
    Wordlist? wordlist,
  }) {
    Entropy.validate(entropy);
    final wl = wordlist ?? WordlistEn.instance;
    return Mnemonic._fromEntropy(entropy, wl);
  }

  // ---- Factory: From Phrase ----

  /// Imports a [Mnemonic] from an existing [phrase] string.
  ///
  /// Words must be space-separated and all present in [wordlist].
  /// The checksum is verified - throws [ArgumentError] if invalid.
  ///
  /// Accepts phrases with extra whitespace between words.
  ///
  /// ```dart
  /// final mnemonic = Mnemonic.fromPhrase(
  ///   'abandon abandon abandon abandon abandon abandon '
  ///   'abandon abandon abandon abandon abandon about',
  /// );
  /// ```
  factory Mnemonic.fromPhrase(
    String phrase, {
    Wordlist? wordlist,
  }) {
    final wl = wordlist ?? WordlistEn.instance;
    final words =
        phrase.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    _validateWordCount(words);

    final indices = <int>[];
    for (final word in words) {
      final index = wl.indexOf(word);
      if (index == -1) {
        throw ArgumentError(
          'Invalid mnemonic: word "$word" not found in '
          '"${wl.language}" wordlist.',
        );
      }
      indices.add(index);
    }

    _validateChecksum(indices, words.length);

    return Mnemonic._(List.unmodifiable(words), wl);
  }

  // ---- Fields ----

  final List<String> _words;
  final Wordlist _wordlist;

  // ---- Public API ----

  /// The mnemonic words as an unmodifiable list.
  List<String> get words => _words;

  /// The mnemonic phrase as a space-separated string.
  ///
  /// This is the value users must back up. Handle with the same care
  /// as a private key.
  String get phrase => _words.join(' ');

  /// The wordlist used to generate this mnemonic.
  Wordlist get wordlist => _wordlist;

  /// The number of words in this mnemonic (12, 15, 18, 21, or 24).
  int get wordCount => _words.length;

  /// Reconstructs and returns the original entropy bytes.
  ///
  /// The entropy is derived from the word indices, not stored directly.
  Uint8List toEntropy() {
    final indices = _words.map(_wordlist.indexOf).toList();
    final bits = _indicesToBits(indices);

    // Determine entropy length from word count:
    // wordCount = (entropyBits + checksumBits) / 11
    // checksumBits = entropyBits / 32
    // Solving: entropyBits = wordCount * 11 * 32 / 33
    final totalBits = _words.length * 11;
    final checksumBits = totalBits ~/ 33;
    final entropyBits = totalBits - checksumBits;
    final entropyBytes = entropyBits ~/ 8;

    final entropy = Uint8List(entropyBytes);
    for (var i = 0; i < entropyBits; i++) {
      if (bits[i] == 1) {
        entropy[i ~/ 8] |= 1 << (7 - (i % 8));
      }
    }
    return entropy;
  }

  // Static helper
  static List<String> _buildWords(Uint8List entropy, Wordlist wordlist) {
    final bits = Entropy.toBits(entropy);
    final wordCount = bits.length ~/ 11;
    final words = <String>[];
    for (var i = 0; i < wordCount; i++) {
      var index = 0;
      for (var j = 0; j < 11; j++) {
        index = (index << 1) | bits[i * 11 + j];
      }
      words.add(wordlist.wordAt(index));
    }
    return List.unmodifiable(words);
  }

  // ---- Internal: Validate word count ----

  static void _validateWordCount(List<String> words) {
    const validCounts = {12, 15, 18, 21, 24};
    if (!validCounts.contains(words.length)) {
      throw ArgumentError(
        'Invalid mnemonic: expected 12, 15, 18, 21, or 24 words, '
        'got ${words.length}.',
      );
    }
  }

  // ---- Internal: Validate checksum ----

  static void _validateChecksum(List<int> indices, int wordCount) {
    final bits = _indicesToBits(indices);
    final totalBits = wordCount * 11;
    final checksumBits = totalBits ~/ 33;
    final entropyBits = totalBits - checksumBits;

    // Reconstruct entropy bytes from bits
    final entropyBytes = entropyBits ~/ 8;
    final entropy = Uint8List(entropyBytes);
    for (var i = 0; i < entropyBits; i++) {
      if (bits[i] == 1) {
        entropy[i ~/ 8] |= 1 << (7 - (i % 8));
      }
    }

    // Recompute expected checksum
    final expectedChecksum = Entropy.computeChecksum(entropy);

    // Extract embedded checksum from bits
    var embeddedChecksum = 0;
    for (var i = 0; i < checksumBits; i++) {
      embeddedChecksum = (embeddedChecksum << 1) | bits[entropyBits + i];
    }

    if (embeddedChecksum != expectedChecksum) {
      throw ArgumentError(
        'Invalid mnemonic: checksum mismatch. '
        'The phrase may have a typo or be in the wrong order.',
      );
    }
  }

  // ---- Internal: Indices to bits ----

  static List<int> _indicesToBits(List<int> indices) {
    final bits = <int>[];
    for (final index in indices) {
      for (var i = 10; i >= 0; i--) {
        bits.add((index >> i) & 1);
      }
    }
    return bits;
  }

  // ---- Overrides ----

  /// Returns a redacted string. The mnemonic phrase is equivalent in
  /// sensitivity to a private key and must never appear in logs.
  ///
  /// Use [phrase] explicitly to access the actual phrase.
  @override
  String toString() => 'Mnemonic[REDACTED]';
}
