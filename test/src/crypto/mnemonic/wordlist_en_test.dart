import 'package:avalanche_flutter_sdk/src/crypto/mnemonic/wordlist.dart';
import 'package:avalanche_flutter_sdk/src/crypto/mnemonic/wordlist_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---- Singleton ----

  group('WordlistEn - singleton', () {
    test('instance is always the same object', () {
      expect(identical(WordlistEn.instance, WordlistEn.instance), isTrue);
    });
  });

  // ---- Language ----

  group('WordlistEn - language', () {
    test('language is "en"', () {
      expect(WordlistEn.instance.language, equals('en'));
    });
  });

  // ---- BIP-39 structure ----

  group('WordlistEn - BIP-39 structure', () {
    test('contains exactly 2048 words', () {
      expect(WordlistEn.instance.length, equals(Wordlist.requiredLength));
    });

    test('passes BIP-39 validation (length + sorted)', () {
      expect(WordlistEn.instance.validate, returnsNormally);
    });

    test('first word is "abandon" (index 0)', () {
      expect(WordlistEn.instance.wordAt(0), equals('abandon'));
    });

    test('last word is "zoo" (index 2047)', () {
      expect(WordlistEn.instance.wordAt(2047), equals('zoo'));
    });
  });

  // ---- BIP-39 official test vector words ----

  group('WordlistEn - BIP-39 test vector words', () {
    // Verified against trezor/python-mnemonic vectors.json
    // Entropy: 00000000000000000000000000000000
    // Mnemonic: abandon abandon abandon ... abandon about

    test('"abandon" is at index 0', () {
      expect(WordlistEn.instance.indexOf('abandon'), equals(0));
    });

    test('"about" is at index 3', () {
      expect(WordlistEn.instance.indexOf('about'), equals(3));
    });

    test('"zoo" is at index 2047', () {
      expect(WordlistEn.instance.indexOf('zoo'), equals(2047));
    });

    // Entropy: 7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f
    // Mnemonic: legal winner thank year wave sausage
    //           worth useful legal winner thank yellow

    test('"legal" is in the wordlist', () {
      expect(WordlistEn.instance.contains('legal'), isTrue);
    });

    test('"winner" is in the wordlist', () {
      expect(WordlistEn.instance.contains('winner'), isTrue);
    });

    test('"yellow" is in the wordlist', () {
      expect(WordlistEn.instance.contains('yellow'), isTrue);
    });
  });

  // ---- Known indices ----

  group('WordlistEn - known word indices', () {
    test('wordAt and indexOf are consistent for first word', () {
      final word = WordlistEn.instance.wordAt(0);
      expect(WordlistEn.instance.indexOf(word), equals(0));
    });

    test('wordAt and indexOf are consistent for last word', () {
      final word = WordlistEn.instance.wordAt(2047);
      expect(WordlistEn.instance.indexOf(word), equals(2047));
    });

    test('wordAt and indexOf are consistent for middle word', () {
      final word = WordlistEn.instance.wordAt(1024);
      expect(WordlistEn.instance.indexOf(word), equals(1024));
    });
  });

  // ---- Invalid words ----

  group('WordlistEn - invalid words', () {
    test('returns -1 for word not in list', () {
      expect(WordlistEn.instance.indexOf('notaword'), equals(-1));
    });

    test('returns false for contains with invalid word', () {
      expect(WordlistEn.instance.contains('flutter'), isFalse);
    });

    test('is case-sensitive - uppercase not found', () {
      expect(WordlistEn.instance.contains('Abandon'), isFalse);
      expect(WordlistEn.instance.contains('ABANDON'), isFalse);
    });
  });
}
