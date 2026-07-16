// ---- Wordlist ----

/// Abstract base class for BIP-39 wordlists.
///
/// A BIP-39 wordlist is a sorted list of exactly 2048 words used to
/// convert entropy bits into a human-readable mnemonic phrase. Each
/// word represents an 11-bit index (0-2047).
///
/// Source: https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki
///
/// "An ideal wordlist has the following characteristics:
/// a) smart selection of words - it's enough to type the first four
///    letters to unambiguously identify the word
/// b) similar words avoided - word pairs like 'build' and 'built'
///    are more error prone
/// c) sorted wordlists - allows binary search and trie compression"
abstract class Wordlist {
  // ---- Constants ----

  /// The required number of words in a BIP-39 wordlist.
  ///
  /// 2048 = 2^11, meaning each word encodes exactly 11 bits of entropy.
  static const int requiredLength = 2048;

  // ---- Abstract API ----

  /// The language identifier for this wordlist (e.g. 'en', 'es').
  String get language;

  /// The full list of 2048 words in this wordlist.
  ///
  /// Must be sorted alphabetically and encoded in UTF-8 NFKD, per BIP-39.
  List<String> get words;

  // ---- Concrete API ----

  /// The number of words in this wordlist. Always [requiredLength] (2048).
  int get length => words.length;

  /// Returns the word at the given [index] (0-2047).
  ///
  /// Throws [RangeError] if [index] is out of bounds.
  String wordAt(int index) {
    RangeError.checkValueInInterval(index, 0, requiredLength - 1, 'index');
    return words[index];
  }

  /// Returns the index of [word] in this wordlist, or -1 if not found.
  ///
  /// Uses binary search since BIP-39 wordlists are sorted alphabetically.
  int indexOf(String word) {
    var low = 0;
    var high = words.length - 1;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final comparison = words[mid].compareTo(word);
      if (comparison == 0) return mid;
      if (comparison < 0) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return -1;
  }

  /// Returns `true` if [word] exists in this wordlist.
  bool contains(String word) => indexOf(word) != -1;

  /// Validates this wordlist against BIP-39 requirements.
  ///
  /// Throws [StateError] if the wordlist is invalid.
  void validate() {
    if (words.length != requiredLength) {
      throw StateError(
        'Invalid wordlist "$language": expected $requiredLength words, '
        'got ${words.length}.',
      );
    }

    for (var i = 1; i < words.length; i++) {
      if (words[i].compareTo(words[i - 1]) <= 0) {
        throw StateError(
          'Invalid wordlist "$language": words are not sorted. '
          '"${words[i]}" at index $i must come after "${words[i - 1]}".',
        );
      }
    }
  }
}
